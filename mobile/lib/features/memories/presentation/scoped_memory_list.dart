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
  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      await runCalmly(
        context,
        () =>
            ref.read(memoryTimelineProvider(widget.query).notifier).loadMore(),
      );
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
              _AutoLoader(loading: _loadingMore, onVisible: _more),
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

/// Triggers [onVisible] once via a post-frame callback when first built
/// (i.e. when the user scrolls to this position), then shows a spinner.
/// Replaced by list content on the next page load, or removed when no
/// more pages remain.
class _AutoLoader extends StatefulWidget {
  const _AutoLoader({required this.loading, required this.onVisible});
  final bool loading;
  final VoidCallback onVisible;
  @override
  State<_AutoLoader> createState() => _AutoLoaderState();
}

class _AutoLoaderState extends State<_AutoLoader> {
  @override
  void initState() {
    super.initState();
    if (!widget.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVisible();
      });
    }
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
