import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/two_pane.dart';
import '../application/chat_providers.dart';
import 'chat_visuals.dart';

enum _RowAction { pin, mute, archive, unarchive }

/// D1: Chats and Requests, search, pin, mute and archive with Undo.
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});
  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// Swiped-away rows, hidden at once while the archive saves.
  final Set<String> _dismissed = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ConversationSummary> _filter(List<ConversationSummary> list) {
    final query = _query.trim().toLowerCase();
    return [
      for (final item in list)
        if (!_dismissed.contains(item.id) &&
            (query.isEmpty || item.title.toLowerCase().contains(query)))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) => ChatAsyncView<ChatInbox>(
    provider: chatInboxProvider,
    builder: (inbox) {
      final requests = inbox.requests.length;
      return ReadingPane(
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  Space.xs,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search chats',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabs: [
                  const Tab(text: 'Chats'),
                  Tab(
                    text: requests == 0 ? 'Requests' : 'Requests ($requests)',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ChatsTab(
                      chats: _filter(inbox.chats),
                      archived: inbox.archived.length,
                      searching: _query.trim().isNotEmpty,
                      onArchive: _archive,
                    ),
                    _RequestsTab(requests: _filter(inbox.requests)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Archives with Undo. The row hides at once (it was swiped away) and
  /// stays hidden until the refreshed inbox no longer lists it.
  Future<void> _archive(ConversationSummary chat) async {
    setState(() => _dismissed.add(chat.id));
    final controller = ref.read(chatControllerProvider.notifier);
    final unarchive = undoDetached(
      context,
      () => controller.setArchived(chat.id, false),
    );
    final done = await runCalmly(
      context,
      () async {
        await controller.setArchived(chat.id, true);
        return true;
      },
      success: '${chat.title} archived.',
      onUndo: () {
        if (mounted) setState(() => _dismissed.remove(chat.id));
        unarchive();
      },
    );
    if (done != true && mounted) setState(() => _dismissed.remove(chat.id));
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.chats,
    required this.archived,
    required this.searching,
    required this.onArchive,
  });
  final List<ConversationSummary> chats;
  final int archived;
  final bool searching;
  final Future<void> Function(ConversationSummary) onArchive;
  @override
  Widget build(BuildContext context) => ListView(
    padding: CircleInsets.page.copyWith(left: 0, right: 0),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.lg),
        child: PreviewLabel(chatPreviewNote),
      ),
      if (chats.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: searching
              ? const Text('No chats match your search.')
              : const CircleEmpty(
                  title: 'Your conversations start with your people',
                  message:
                      'Every group has a chat, and you can message anyone who shares a group with you. There is no stranger search or contact upload.',
                ),
        ),
      for (final chat in chats)
        Dismissible(
          key: ValueKey('chat-row-${chat.id}'),
          direction: DismissDirection.endToStart,
          background: const _ArchiveBackground(),
          onDismissed: (_) => onArchive(chat),
          child: ConversationRow(chat: chat, onArchive: () => onArchive(chat)),
        ),
      if (archived > 0)
        ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text('Archived ($archived)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/chats/archived'),
        ),
    ],
  );
}

class _ArchiveBackground extends StatelessWidget {
  const _ArchiveBackground();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.section),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.archive_outlined, color: colors.onPrimary),
            const SizedBox(width: Space.sm),
            Text(
              'Archive',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.requests});
  final List<ConversationSummary> requests;
  @override
  Widget build(BuildContext context) => ListView(
    padding: CircleInsets.page.copyWith(left: 0, right: 0),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.lg),
        child: PreviewLabel(
          'First messages from people outside your close groups wait here. '
          'They won’t know you’ve seen them unless you accept.',
        ),
      ),
      if (requests.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.lg),
          child: CircleEmpty(
            title: 'No message requests',
            message: 'You can choose who can message you in You › Privacy.',
          ),
        ),
      for (final request in requests) ConversationRow(chat: request),
    ],
  );
}

/// One inbox row: avatar, name, last line, unread dot, pin and mute icons,
/// and a ⋮ menu (also on long-press) for pin, mute and archive.
class ConversationRow extends ConsumerWidget {
  const ConversationRow({super.key, required this.chat, this.onArchive});
  final ConversationSummary chat;

  /// Archives from the inbox (with Undo); null in Requests and Archived.
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = CircleAccents.of(context);
    final strong = chat.unread
        ? const TextStyle(fontWeight: FontWeight.w700)
        : null;
    final status = [
      if (chat.unread) 'unread',
      if (chat.pinned) 'pinned',
      if (chat.muted) 'muted',
      if (chat.request) 'message request',
    ];
    final menu = !chat.request;

    Future<void> act(_RowAction action) => _onAction(context, ref, action);

    return CircleRow(
      child: Semantics(
        value: status.join(', '),
        child: ListTile(
          selected: CirclePaneScope.isSelected(context, 'chats', chat.id),
          onTap: () {
            if (!CirclePaneScope.select(context, 'chats', chat.id)) {
              context.push('/chats/c/${chat.id}');
            }
          },
          onLongPress: menu ? () => _showRowSheet(context, act) : null,
          leading: ConversationAvatar(
            title: chat.title,
            groupType: chat.groupType,
            person: chat.otherId,
            active: !chat.isGroup && chat.activeNow,
          ),
          title: Text(
            chat.title,
            semanticsLabel: !chat.isGroup && chat.activeNow
                ? ActivityRules.spoken(chat.title, chat.activity)
                : null,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: strong,
          ),
          subtitle: Text(
            chat.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: chat.unread
                ? theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accents.title,
                  )
                : null,
          ),
          trailing: ExcludeSemantics(
            excluding: !menu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chat.pinned)
                  Icon(
                    Icons.push_pin_outlined,
                    size: 18,
                    color: accents.caption,
                  ),
                if (chat.muted)
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 18,
                    color: accents.caption,
                  ),
                if (chat.unread)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.sm),
                    child: Container(
                      width: Space.sm + Space.xs / 2,
                      height: Space.sm + Space.xs / 2,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (menu)
                  PopupMenuButton<_RowAction>(
                    tooltip: 'More options for ${chat.title}',
                    icon: const Icon(Icons.more_vert),
                    onSelected: act,
                    itemBuilder: (_) => [
                      for (final action in _actionsFor(chat))
                        PopupMenuItem(
                          value: action,
                          child: Text(_label(action, chat)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_RowAction> _actionsFor(ConversationSummary chat) => [
    _RowAction.pin,
    _RowAction.mute,
    if (chat.archived) _RowAction.unarchive else _RowAction.archive,
  ];

  String _label(_RowAction action, ConversationSummary chat) =>
      switch (action) {
        _RowAction.pin => chat.pinned ? 'Unpin' : 'Pin',
        _RowAction.mute => chat.muted ? 'Unmute or change mute' : 'Mute',
        _RowAction.archive => 'Archive',
        _RowAction.unarchive => 'Unarchive',
      };

  Future<void> _showRowSheet(
    BuildContext context,
    Future<void> Function(_RowAction) act,
  ) async {
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      // Above the shell's navigation bar, so nothing is hidden.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.section),
              child: Semantics(
                header: true,
                child: Text(
                  chat.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            for (final action in _actionsFor(chat))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.section,
                ),
                title: Text(_label(action, chat)),
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    );
    if (action != null) await act(action);
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _RowAction action,
  ) async {
    final controller = ref.read(chatControllerProvider.notifier);
    switch (action) {
      case _RowAction.pin:
        await runCalmly(
          context,
          () => controller.setPinned(chat.id, !chat.pinned),
          success: chat.pinned ? 'Unpinned.' : 'Pinned to the top.',
        );
      case _RowAction.mute:
        final choice = await showMuteSheet(
          context,
          title: chat.title,
          muted: chat.muted,
        );
        if (choice == null || !context.mounted) return;
        await runCalmly(
          context,
          () => controller.mute(chat.id, choice.mute),
          success: choice.mute == null
              ? '${chat.title} unmuted.'
              : '${chat.title} muted.',
        );
      case _RowAction.archive:
        if (onArchive != null) {
          onArchive!();
        } else {
          await runCalmly(
            context,
            () => controller.setArchived(chat.id, true),
            success: '${chat.title} archived.',
            onUndo: undoDetached(
              context,
              () => controller.setArchived(chat.id, false),
            ),
          );
        }
      case _RowAction.unarchive:
        await runCalmly(
          context,
          () => controller.setArchived(chat.id, false),
          success: '${chat.title} moved back to Chats.',
          onUndo: undoDetached(
            context,
            () => controller.setArchived(chat.id, true),
          ),
        );
    }
  }
}

/// Archived conversations, with Unarchive in each row's menu.
class ChatArchivedScreen extends StatelessWidget {
  const ChatArchivedScreen({super.key});
  @override
  Widget build(BuildContext context) => ChatAsyncView<ChatInbox>(
    provider: chatInboxProvider,
    builder: (inbox) => ReadingPane(
      child: ListView(
        padding: CircleInsets.form.copyWith(left: 0, right: 0),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.lg),
            child: CircleHeading(
              title: 'Archived chats',
              subtitle: 'Out of the way, never deleted.',
            ),
          ),
          if (inbox.archived.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text('Nothing archived.'),
            ),
          for (final chat in inbox.archived) ConversationRow(chat: chat),
        ],
      ),
    ),
  );
}
