import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../workspace/application/workspace_providers.dart';

/// A scoped page has its own loading/empty/error and older-page controls.
class ScopedMemoryList extends ConsumerStatefulWidget {
  const ScopedMemoryList({
    super.key,
    required this.query,
    required this.itemBuilder,
    required this.empty,
  });
  final MemoryQuery query;
  final Widget Function(BuildContext, CircleMemory) itemBuilder;
  final Widget empty;
  @override
  ConsumerState<ScopedMemoryList> createState() => _ScopedMemoryListState();
}

class _ScopedMemoryListState extends ConsumerState<ScopedMemoryList> {
  bool _loadingMore = false;
  bool _moreFailed = false;
  Future<void> _more() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      await ref.read(memoryTimelineProvider(widget.query).notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _moreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(memoryTimelineProvider(widget.query))
      .when(
        data: (page) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (page.items.isEmpty) widget.empty,
            for (final memory in page.items)
              widget.itemBuilder(context, memory),
            if (page.hasMore)
              if (_moreFailed)
                TextButton(
                  onPressed: _more,
                  child: const Text('Retry loading older Memories'),
                )
              else
                _AutoLoader(
                  key: ValueKey(page.cursor),
                  loading: _loadingMore,
                  onVisible: _more,
                ),
            if (!page.hasMore && page.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Center(
                  child: Text(
                    "You've seen all Memories",
                    style: CircleTextStyles.caption(
                      Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        loading: () =>
            const CircleSkeleton(count: 2, label: 'Loading Memories'),
        error: (_, _) => CircleEmpty(
          title: "Memories couldn't load",
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () =>
                ref.invalidate(memoryTimelineProvider(widget.query)),
            child: const Text('Try again'),
          ),
        ),
      );
}

/// Requests each cursor only when its loader enters the scroll viewport.
class _AutoLoader extends StatefulWidget {
  const _AutoLoader({
    super.key,
    required this.loading,
    required this.onVisible,
  });
  final bool loading;
  final VoidCallback onVisible;
  @override
  State<_AutoLoader> createState() => _AutoLoaderState();
}

class _AutoLoaderState extends State<_AutoLoader> {
  ScrollPosition? _position;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (_position != next) {
      _position?.removeListener(_checkVisible);
      _position = next;
      _position?.addListener(_checkVisible);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  void _checkVisible() {
    if (!mounted || _requested || widget.loading) return;
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.hasSize ||
        !viewport.hasSize) {
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    if (top < viewportTop + viewport.size.height &&
        top + box.size.height > viewportTop) {
      _requested = true;
      widget.onVisible();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisible);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.md),
    child: Center(
      child: Semantics(
        label: 'Loading older Memories',
        child: const SizedBox.square(
          dimension: Space.section,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
  );
}
