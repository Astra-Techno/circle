import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
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
            if (page.hasMore) ...[
              const SizedBox(height: Space.md),
              OutlinedButton(
                onPressed: _loadingMore ? null : _more,
                child: Text(_loadingMore ? 'Loading…' : 'Load older Memories'),
              ),
            ],
          ],
        ),
        loading: () =>
            const CircleSkeleton(count: 2, label: 'Loading Memories'),
        error: (_, _) => CircleEmpty(
          title: 'Memories couldn’t load',
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () =>
                ref.invalidate(memoryTimelineProvider(widget.query)),
            child: const Text('Try again'),
          ),
        ),
      );
}
