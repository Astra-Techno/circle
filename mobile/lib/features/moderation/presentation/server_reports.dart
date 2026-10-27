import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/server_moderation.dart';
import '../../workspace/application/workspace_providers.dart';

/// Server-only queue: no fictional cases and no reporter account/note fields.
class ServerReportsScreen extends ConsumerStatefulWidget {
  const ServerReportsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<ServerReportsScreen> createState() => _ServerReportsState();
}

class _ServerReportsState extends ConsumerState<ServerReportsScreen> {
  int _offset = 0;
  bool _busy = false;
  Future<void> _action(SafetyPage page, SafetyCase item, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runCalmly(
      context,
      () => ref.read(safetyActionsProvider).act(page, item, action),
      success: 'Saved.',
      onUndo: action == 'dismiss'
          ? undoWith(context, () async {
              await ref
                  .read(safetyActionsProvider)
                  .act(page, item, 'restore', version: item.version + 1);
              if (mounted) ref.invalidate(safetyPageProvider);
            })
          : null,
    );
    if (!mounted) return;
    ref.invalidate(safetyPageProvider);
    await ref
        .read(circleWorkspaceProvider.notifier)
        .refresh()
        .catchError((Object _) {});
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final group = ref
        .watch(circleWorkspaceProvider)
        .value
        ?.group(widget.groupId);
    final viewer = ref.watch(circleViewerProvider);
    if (group?.roleOf(viewer)?.isAdmin != true) {
      return const ReadingPane(
        child: CircleEmpty(
          title: 'Reports are for admins',
          message:
              'Only current admins of this exact group can review reports.',
        ),
      );
    }
    final query = (group: widget.groupId, offset: _offset);
    final load = ref.watch(safetyPageProvider(query));
    return ReadingPane(
      child: load.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const CircleSkeletonPage(
          shape: CircleSkeletonShape.cards,
          count: 2,
          label: 'Loading reports',
        ),
        error: (error, _) => ListView(
          padding: CircleInsets.form,
          children: [
            CircleEmpty(
              title: 'Reports couldn’t load',
              message: error is CircleFailure
                  ? error.message
                  : 'Try again in a moment.',
              action: OutlinedButton(
                onPressed: () => ref.invalidate(safetyPageProvider(query)),
                child: const Text('Refresh reports'),
              ),
            ),
          ],
        ),
        data: (page) => ListView(
          padding: CircleInsets.form,
          children: [
            CircleHeading(
              title: 'Reports in ${group!.name}',
              subtitle:
                  'Private to this group’s admins. Reporter accounts and notes stay hidden.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => ref.invalidate(safetyPageProvider(query)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh reports'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (page.items.isEmpty)
              const CircleEmpty(
                title: 'Nothing to review',
                message: 'Reports from members of this group appear here.',
              ),
            for (final item in page.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.kind == 'memory'
                            ? 'Memory'
                            : item.kind == 'comment'
                            ? 'Comment'
                            : 'Member',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.hidden)
                        const CirclePill(
                          'Hidden',
                          icon: Icons.visibility_off_outlined,
                        ),
                      Text(item.summary ?? 'This item is no longer available.'),
                      if (item.reasons.isNotEmpty) Text(item.reasons),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          if (item.hideable && item.available)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(
                                      page,
                                      item,
                                      item.hidden ? 'unhide' : 'hide',
                                    ),
                              child: Text(
                                item.hidden
                                    ? 'Restore content'
                                    : 'Hide content',
                              ),
                            ),
                          if (item.reasons.isNotEmpty)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(page, item, 'dismiss'),
                              child: const Text('Dismiss reports'),
                            ),
                          if (item.kind == 'member' && item.available)
                            Text(
                              'Use this group’s Members tab to remove or manage a member.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Wrap(
              spacing: Space.sm,
              children: [
                if (_offset > 0)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _offset -= 30),
                    child: const Text('Previous reports'),
                  ),
                if (page.more)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _offset += 30),
                    child: const Text('Next reports'),
                  ),
              ],
            ),
            const CircleSectionTitle('Recent admin actions'),
            if (page.audit.isEmpty) const Text('No admin actions yet.'),
            for (final event in page.audit)
              CircleRow(
                child: Text(
                  '${event['actor_name']} · ${_actionLabel('${event['action']}')} · ${event['kind']} #${event['target_id']} · ${event['created_at']} UTC',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
    'hide' => 'hid content',
    'unhide' => 'restored content',
    'dismiss' => 'dismissed reports',
    _ => 'reopened reports',
  };
}
