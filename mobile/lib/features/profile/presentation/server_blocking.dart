import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/server_blocks.dart';

class ServerBlockButton extends ConsumerStatefulWidget {
  const ServerBlockButton({
    super.key,
    required this.person,
    required this.name,
  });
  final String person, name;
  @override
  ConsumerState<ServerBlockButton> createState() => _BlockButtonState();
}

class _BlockButtonState extends ConsumerState<ServerBlockButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final load = ref.watch(blockStateProvider(widget.person));
    return load.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(blockStateProvider(widget.person)),
        child: const Text('Refresh blocking options'),
      ),
      data: (blocked) => ListTile(
        leading: const Icon(Icons.block),
        title: Text(
          blocked ? 'Unblock ${widget.name}' : 'Block ${widget.name}',
        ),
        subtitle: const Text(
          'Stops direct contact and personal reply alerts. Shared-group content stays visible. No alert is sent.',
        ),
        enabled: !_busy,
        onTap: () async {
          final actions = ref.read(blockActionsProvider),
              scope = ref.read(blockActionsProvider).capture();
          if (!blocked &&
              !await confirmCircleAction(
                context,
                title: 'Block ${widget.name}?',
                message:
                    'Direct Circle invitations and personal reply alerts will stop. Shared-group profiles, photos, Memories and comments stay visible. Membership and admin controls are unchanged.',
                confirm: 'Block',
              )) {
            return;
          }
          if (!context.mounted) return;
          setState(() => _busy = true);
          await runCalmly(
            context,
            () => actions.change(scope, widget.person, blocked: !blocked),
            success: blocked ? 'Unblocked.' : 'Blocked.',
          );
          if (mounted) {
            setState(() => _busy = false);
          }
        },
      ),
    );
  }
}

class ServerBlockingScreen extends ConsumerStatefulWidget {
  const ServerBlockingScreen({super.key});
  @override
  ConsumerState<ServerBlockingScreen> createState() => _BlockingState();
}

class _BlockingState extends ConsumerState<ServerBlockingScreen> {
  int _offset = 0;
  bool _busy = false;

  /// People from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];
  Future<void> _unblock(BlockPage page, String id) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await runCalmly(
      context,
      () =>
          ref.read(blockActionsProvider).change(page.scope, id, blocked: false),
      success: 'Unblocked.',
    );
    if (mounted) {
      // Start again from the top so the list matches the server.
      setState(() {
        _busy = false;
        _offset = 0;
        _earlier.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(blockPageProvider(_offset));
    return ReadingPane(
      child: load.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const CircleSkeletonPage(
          shape: CircleSkeletonShape.cards,
          count: 2,
          label: 'Loading blocked people',
        ),
        error: (_, _) => CircleEmpty(
          title: 'Blocked people couldn’t load',
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(blockPageProvider(_offset)),
            child: const Text('Try again'),
          ),
        ),
        data: (page) => ListView(
          padding: CircleInsets.form,
          children: [
            const CircleHeading(
              title: 'Privacy and blocking',
              subtitle: 'Control direct contact. Group content stays visible.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => ref.invalidate(blockPageProvider(_offset)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh list'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (page.items.isEmpty)
              const CircleEmpty(
                title: 'No blocked people here',
                message:
                    'Use a member’s profile or an invitation to block someone.',
              ),
            for (final item in [..._earlier, ...page.items])
              CircleRow(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${item['display_name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Name saved when blocked',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _unblock(page, '${item['id']}'),
                          child: const Text('Unblock'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (page.more)
              CircleLoadMore(
                key: ValueKey('more-$_offset'),
                onLoad: () => setState(() {
                  _earlier.addAll(page.items);
                  _offset += 30;
                }),
              ),
            const SizedBox(height: Space.md),
            const ExpansionTile(
              title: Text('What blocking changes'),
              children: [
                Padding(
                  padding: EdgeInsets.all(Space.md),
                  child: Text(
                    'Blocking stops direct Circle invitations and personal reply alerts from that person. Shared-group profiles, photos, Memories, comments and ordinary group updates remain visible. Group membership and admin controls are unchanged. Unblocking won’t restore expired invitations.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
