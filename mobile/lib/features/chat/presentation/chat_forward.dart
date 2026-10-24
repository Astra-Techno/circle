import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/chat_providers.dart';
import 'chat_visuals.dart';

/// "Forward": choose up to 5 chats you can post in. Returns the chosen
/// conversation ids, or null when dismissed. Chats where not everyone can
/// see a shared card are skipped when sending, with a calm note.
Future<List<String>?> showForwardSheet(
  BuildContext context, {
  required MessageView message,
}) => showModalBottomSheet<List<String>>(
  context: context,
  // Above the shell's navigation bar, so nothing is hidden.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ForwardSheet(message: message),
);

class _ForwardSheet extends ConsumerStatefulWidget {
  const _ForwardSheet({required this.message});
  final MessageView message;
  @override
  ConsumerState<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<_ForwardSheet> {
  final _search = TextEditingController();
  final List<String> _chosen = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(
    () => _chosen.contains(id) ? _chosen.remove(id) : _chosen.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inbox = ref.watch(chatInboxProvider).value;
    final query = _search.text.trim().toLowerCase();
    // Only chats the viewer can post in: never a group they left, a
    // request waiting for them, or a 1:1 blocked either way.
    final chats = [
      for (final chat in [...?inbox?.chats, ...?inbox?.archived])
        if (chat.canPost &&
            (query.isEmpty || chat.title.toLowerCase().contains(query)))
          chat,
    ];
    final full = _chosen.length >= ForwardRules.maxTargets;
    final count = _chosen.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.section,
              0,
              Space.section,
              Space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Forward to', style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  widget.message.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search chats',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: Space.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    full
                        ? 'You can forward to ${ForwardRules.maxTargets} chats at once.'
                        : '$count of ${ForwardRules.maxTargets} chosen',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: inbox == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.section),
                    child: CircleSkeleton(count: 3, label: 'Loading chats'),
                  )
                : chats.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.section,
                    ),
                    child: Text(
                      query.isEmpty
                          ? 'There’s no chat you can forward to right now.'
                          : 'No chats match “${_search.text.trim()}”.',
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    children: [
                      for (final chat in chats)
                        CheckboxListTile(
                          key: ValueKey('forward-${chat.id}'),
                          value: _chosen.contains(chat.id),
                          secondary: ConversationAvatar(
                            title: chat.title,
                            groupType: chat.groupType,
                            size: CircleAvatarSize.small,
                          ),
                          title: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: chat.isGroup
                              ? Text(
                                  '${chat.memberCount} members',
                                  style: theme.textTheme.bodySmall,
                                )
                              : null,
                          onChanged: !_chosen.contains(chat.id) && full
                              ? null
                              : (_) => _toggle(chat.id),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: FilledButton.icon(
              onPressed: count == 0
                  ? null
                  : () => Navigator.of(context).pop([..._chosen]),
              icon: const Icon(Icons.shortcut),
              label: Text(count <= 1 ? 'Forward' : 'Forward to $count chats'),
            ),
          ),
        ],
      ),
    );
  }
}
