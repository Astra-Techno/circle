import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/memory_compose.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../memories/presentation/mention_text.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/chat_providers.dart';
import 'chat_forward.dart';
import 'chat_message.dart';
import 'chat_visuals.dart';

enum _MessageAction { reply, forward, copy, edit, unsend, report, unhide }

/// D2: one conversation. Local mock: nothing is sent or received, and
/// nothing arrives on its own.
class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// People picked from @mention suggestions for the message being typed.
  final _mentions = MentionDraft();
  MessageView? _replyTo;
  String? _selected;
  bool _sending = false;

  /// Reused until a send succeeds, so a retry can't send twice.
  String? _clientMessageId;

  ChatController get _controller => ref.read(chatControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _controller.markRead(widget.id);
      } on CircleFailure {
        // Unavailable conversations explain themselves on screen.
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  void _love(MessageView message) => runCalmly(
    context,
    () => _controller.react(widget.id, message.id, loveReaction),
  );

  void _reply(MessageView message) {
    setState(() {
      _replyTo = message;
      _selected = null;
    });
    _focus.requestFocus();
  }

  void _select(MessageView message) =>
      setState(() => _selected = _selected == message.id ? null : message.id);

  Future<void> _menu(MessageView message, ConversationView view) async {
    setState(() => _selected = null);
    final now = ref.read(circleClockProvider)();
    final choice = await _showMessageSheet(
      context,
      message,
      canWrite: view.canSend,
      canEdit: view.canSend && message.canEditAt(now),
    );
    final groupId = view.groupId;
    if (choice == null || !mounted) return;
    final emoji = choice.emoji;
    if (emoji != null) {
      await runCalmly(
        context,
        () => _controller.react(widget.id, message.id, emoji),
      );
      return;
    }
    switch (choice.action!) {
      case _MessageAction.reply:
        _reply(message);
      case _MessageAction.forward:
        await _forward(message);
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) showCircleMessage(context, 'Copied.');
      case _MessageAction.edit:
        await _edit(message);
      case _MessageAction.unsend:
        await runCalmly(
          context,
          () => _controller.unsend(widget.id, message.id),
          success: 'Message unsent.',
          onUndo: undoDetached(
            context,
            () => _controller.restore(widget.id, message.id),
          ),
        );
      case _MessageAction.unhide:
        if (groupId == null) return;
        await runCalmly(
          context,
          () => ref
              .read(circleWorkspaceProvider.notifier)
              .unhide(
                groupId,
                ReportTarget.contentKey(ReportKind.message, message.id),
              ),
          success: 'Shown to everyone again.',
        );
      case _MessageAction.report:
        await showReportSheet(
          context,
          title: 'Report this message',
          explanation: view.isGroup
              ? 'Admins of this group see the reason, never who reported it.'
              : '${message.authorName} won’t know you reported it.',
          confirmation: view.isGroup
              ? 'Thanks — admins of this group will review it.'
              : 'Thanks — we’ll review it.',
          submit: (reason, note) => _controller.report(
            widget.id,
            messageId: message.id,
            reason: reason,
            note: note,
          ),
        );
    }
  }

  /// Picks up to 5 chats and forwards [message]; chats it can't go to
  /// are skipped with a calm note.
  Future<void> _forward(MessageView message) async {
    setState(() => _selected = null);
    final targets = await showForwardSheet(context, message: message);
    if (targets == null || targets.isEmpty || !mounted) return;
    final result = await runCalmly(
      context,
      () => _controller.forward(
        widget.id,
        message.id,
        to: targets,
        clientMessageId: _controller.newClientMessageId(),
      ),
    );
    if (result != null && mounted) {
      showCircleMessage(context, ForwardRules.summary(result));
    }
  }

  void _openPhoto(MessageView message, int index) => context.push(
    Uri(
      path: '/chats/c/${widget.id}/photos/${message.id}',
      queryParameters: {'index': '$index'},
    ).toString(),
  );

  Future<void> _edit(MessageView message) => showModalBottomSheet<void>(
    context: context,
    // Above the shell's navigation bar, so nothing is hidden.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _EditMessageSheet(conversationId: widget.id, message: message),
  );

  Future<void> _send(SharedContent? draft, ConversationView view) async {
    final check = ChatRules.checkText(_text.text, hasAttachment: draft != null);
    if (!check.allowed) {
      showCircleMessage(context, check.reason!);
      return;
    }
    setState(() => _sending = true);
    final clientId = _clientMessageId ??= _controller.newClientMessageId();
    final sent = await runCalmly(
      context,
      () => _controller.send(
        widget.id,
        clientMessageId: clientId,
        text: _text.text,
        replyToId: _replyTo?.id,
        shared: draft,
        mentions: view.isGroup
            ? _mentions.resolve(_text.text, {
                for (final member in view.members) member.id,
              })
            : const {},
      ),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent != null) {
        _mentions.clear();
        _text.clear();
        _replyTo = null;
        _clientMessageId = null;
      }
    });
    if (sent != null && draft != null) {
      ref.read(chatShareDraftsProvider.notifier).clear(widget.id);
    }
  }

  /// Whether everyone in this chat can already see an item of [groupId].
  bool _everyoneCanSee(
    CircleWorkspace workspace,
    ConversationView view,
    String groupId,
  ) => ChatRules.everyoneCanSee(workspace.group(groupId), view.participants);

  Future<void> _attach(CircleWorkspace workspace, ConversationView view) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (value, icon, label) in [
              ('photos', Icons.add_photo_alternate_outlined, 'Photos'),
              ('memory', Icons.photo_library_outlined, 'Share a Memory'),
              ('event', Icons.event_outlined, 'Share an event'),
              ('poll', Icons.poll_outlined, 'Poll'),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.section,
                ),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final drafts = ref.read(chatShareDraftsProvider.notifier);
    switch (choice) {
      case 'photos':
        final scenes = await pickScenes(
          context,
          max: ChatPhotoRules.maxPhotos,
          action: 'Send',
        );
        if (scenes == null || scenes.isEmpty || !mounted) return;
        await runCalmly(
          context,
          () => _controller.send(
            widget.id,
            clientMessageId: _controller.newClientMessageId(),
            photos: scenes,
          ),
        );
      case 'memory':
        final id = await _pick(context, 'Share a Memory', [
          for (final memory in workspace.memories)
            if (_everyoneCanSee(workspace, view, memory.groupId))
              (
                id: memory.id,
                title: memory.summary,
                subtitle:
                    '${memory.author} · ${workspace.group(memory.groupId)?.name ?? ''}',
              ),
        ]);
        if (id != null) drafts.attach(widget.id, SharedContent.memory(id));
      case 'event':
        final id = await _pick(context, 'Share an event', [
          for (final event in workspace.events)
            if (_everyoneCanSee(workspace, view, event.groupId))
              (
                id: event.id,
                title: event.title,
                subtitle: workspace.group(event.groupId)?.name ?? '',
              ),
        ]);
        if (id != null) drafts.attach(widget.id, SharedContent.event(id));
      case 'poll':
        final draft = await showModalBottomSheet<PollDraft>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _PollSheet(),
        );
        if (draft == null || !mounted) return;
        await runCalmly(
          context,
          () => _controller.send(
            widget.id,
            clientMessageId: _controller.newClientMessageId(),
            poll: draft,
          ),
        );
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) => ChatAsyncView<ConversationLoad>(
    provider: chatConversationProvider(widget.id),
    builder: (load) {
      final view = load.view;
      if (view == null) {
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleEmpty(
                title: 'This conversation is private',
                message: load.unavailable ?? 'Return to your chats.',
                action: TextButton(
                  onPressed: () => context.go('/chats'),
                  child: const Text('Back to Chats'),
                ),
              ),
            ],
          ),
        );
      }
      return ReadingPane(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(view: view),
              const Divider(height: 1),
              // Once per screen, always in view: this chat is a local mock.
              const Padding(
                padding: EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
                child: PreviewLabel(chatPreviewNote),
              ),
              Expanded(child: _messages(view)),
              // Large text never pushes the messages off screen: the
              // footer takes at most half the height and scrolls.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight / 2,
                ),
                child: SingleChildScrollView(child: _footer(view)),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _messages(ConversationView view) {
    final viewer = ref.watch(circleViewerProvider);
    final now = ref.watch(circleClockProvider)();
    final messages = view.messages;
    final callbacks = MessageCallbacks(
      onSelect: _select,
      onLove: _love,
      onReply: _reply,
      onMenu: (message) => _menu(message, view),
      onVote: (message, choices) =>
          _controller.votePoll(widget.id, message.id, choices),
      onRetractVote: (message) =>
          _controller.retractPollVote(widget.id, message.id),
      onClosePoll: (message) => _controller.closePoll(widget.id, message.id),
      onForward: _forward,
      onOpenPhoto: _openPhoto,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = (constraints.maxWidth - Space.hero) * 0.82;
        final items = <Widget>[
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.section),
              child: Text(
                'No messages yet. Say hello to ${view.title}.',
                textAlign: TextAlign.center,
              ),
            ),
        ];
        for (final (index, message) in messages.indexed) {
          final previous = index == 0 ? null : messages[index - 1];
          final next = index + 1 < messages.length ? messages[index + 1] : null;
          if (ChatRules.needsSeparator(
            previous?.createdAt,
            message.createdAt,
          )) {
            items.add(
              Padding(
                padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
                child: Text(
                  ChatRules.separatorLabel(message.createdAt, now),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CircleAccents.of(context).caption,
                  ),
                ),
              ),
            );
          }
          items.add(
            MessageTile(
              key: ValueKey(message.id),
              message: message,
              viewer: viewer,
              group: view.isGroup,
              firstInRun:
                  previous == null ||
                  !ChatRules.continuesRun(previous, message),
              lastInRun: next == null || !ChatRules.continuesRun(message, next),
              selected: _selected == message.id,
              callbacks: callbacks,
              timeLabel: ChatRules.separatorLabel(message.createdAt, now),
              maxWidth: maxWidth,
            ),
          );
          if (message.id == view.statusMessageId && view.status != null) {
            items.add(
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Semantics(
                  label: view.statusSemantics,
                  excludeSemantics: true,
                  child: Text(
                    view.status!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CircleAccents.of(context).caption,
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.md,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => items[items.length - 1 - index],
        );
      },
    );
  }

  Widget _footer(ConversationView view) {
    final padding = const EdgeInsets.fromLTRB(
      Space.lg,
      Space.sm,
      Space.lg,
      Space.md,
    );
    switch (view.mode) {
      case ConversationMode.incomingRequest:
        return Padding(
          padding: padding,
          child: _RequestBar(view: view),
        );
      case ConversationMode.leftGroup:
        return Padding(
          padding: padding,
          child: const ChatNotice(
            icon: Icons.lock_outline,
            message:
                'You left this group, so you can’t send messages here. You can still read what was said before you left.',
          ),
        );
      case ConversationMode.blockedByYou:
        return Padding(
          padding: padding,
          child: ChatNotice(
            icon: Icons.block,
            message: 'You blocked ${view.title}. They can’t message you.',
            actions: [
              OutlinedButton(
                onPressed: () => runCalmly(
                  context,
                  () => _controller.unblock(view.otherId!),
                  success: '${view.title} unblocked.',
                  onUndo: undoDetached(
                    context,
                    () => _controller.block(view.otherId!),
                  ),
                ),
                child: Text('Unblock ${view.title}'),
              ),
            ],
          ),
        );
      case ConversationMode.cannotReply:
        return Padding(
          padding: padding,
          child: const ChatNotice(
            icon: Icons.info_outline,
            message: 'You can’t reply to this conversation right now.',
          ),
        );
      case ConversationMode.active:
        return _composer(view);
    }
  }

  Widget _composer(ConversationView view) {
    final theme = Theme.of(context);
    final draft = ref.watch(chatShareDraftsProvider)[widget.id];
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final canSend =
        !_sending && (_text.text.trim().isNotEmpty || draft != null);
    final viewer = ref.watch(circleViewerProvider);
    final blocked =
        ref.watch(chatPrivacyProvider).value?.settings.blocked ?? const {};
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.sm,
        Space.xs,
        Space.sm,
        Space.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_replyTo != null)
            _ComposerNote(
              icon: Icons.reply,
              title: 'Replying to ${_replyTo!.authorName}',
              text: _replyTo!.summary,
              cancelLabel: 'Cancel reply',
              onCancel: () => setState(() => _replyTo = null),
            ),
          if (draft != null)
            _ComposerNote(
              icon: draft.kind == SharedKind.memory
                  ? Icons.photo_library_outlined
                  : Icons.event_outlined,
              title: draft.kind == SharedKind.memory
                  ? 'Sharing a Memory'
                  : 'Sharing an event',
              text: _draftTitle(draft, workspace),
              cancelLabel: 'Remove shared item',
              onCancel: () =>
                  ref.read(chatShareDraftsProvider.notifier).clear(widget.id),
            ),
          // Group chats: "@" suggests this group's members only.
          if (view.isGroup)
            MentionSuggestions(
              controller: _text,
              draft: _mentions,
              members: [
                for (final member in view.members)
                  MentionCandidate(id: member.id, name: member.name),
              ],
              viewer: viewer,
              blocked: blocked,
              onChanged: () => setState(() {}),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Add photos, a Memory, an event or a poll',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: workspace == null
                    ? null
                    : () => _attach(workspace, view),
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('chat-composer'),
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Message ${view.title}',
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? () => _send(draft, view) : null,
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(
                  disabledBackgroundColor: CircleAccents.of(context).recessed,
                  disabledForegroundColor: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _draftTitle(SharedContent draft, CircleWorkspace? workspace) {
    if (workspace == null) return '';
    return switch (draft.kind) {
      SharedKind.memory =>
        workspace.memories
                .where((memory) => memory.id == draft.id)
                .firstOrNull
                ?.summary ??
            'A Memory',
      SharedKind.event => workspace.event(draft.id)?.title ?? 'An event',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view});
  final ConversationView view;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 1:1: the other person's activity when they share it, otherwise the
    // groups you share. Group chats never show activity.
    final activity = view.isGroup ? null : view.activity;
    final subtitle = view.isGroup
        ? view.mode == ConversationMode.leftGroup
              ? 'You left this group'
              : '${view.members.length} ${view.members.length == 1 ? 'member' : 'members'}'
        : activity ??
              (view.sharedGroups.isEmpty
                  ? 'No shared groups'
                  : 'In ${view.sharedGroups.join(', ')}');
    void open() => context.push('/chats/c/${view.id}/details');
    final spoken = activity == null
        ? '${view.title}, $subtitle'
        : ActivityRules.spoken(view.title, activity);
    return Semantics(
      button: true,
      label: '$spoken. Open chat details',
      excludeSemantics: true,
      onTap: open,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.xs,
            Space.sm,
          ),
          child: Row(
            children: [
              ConversationAvatar(title: view.title, groupType: view.groupType),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CircleAccents.of(context).caption,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chat details',
                onPressed: open,
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D5: a message request. The sender doesn't see "Seen" until accepted.
class _RequestBar extends ConsumerWidget {
  const _RequestBar({required this.view});
  final ConversationView view;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chatControllerProvider.notifier);
    final name = view.title;
    final groups = view.sharedGroups.isEmpty
        ? ''
        : ' You’re both in ${view.sharedGroups.join(', ')}.';
    return ChatNotice(
      icon: Icons.mark_email_unread_outlined,
      message:
          '$name wants to send you a message.$groups They won’t know you’ve '
          'seen it unless you accept.',
      actions: [
        FilledButton(
          // The composer appearing is the feedback; no snackbar over it.
          onPressed: () =>
              runCalmly(context, () => controller.acceptRequest(view.id)),
          child: const Text('Accept'),
        ),
        OutlinedButton(
          onPressed: () async {
            final router = GoRouter.of(context);
            final done = await runCalmly(
              context,
              () async {
                await controller.deleteRequest(view.id);
                return true;
              },
              success: 'Request deleted.',
              onUndo: undoDetached(
                context,
                () => controller.restoreRequest(view.id),
              ),
            );
            if (done == true) router.go('/chats');
          },
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () async {
            final router = GoRouter.of(context);
            if (!await confirmBlock(context, name)) return;
            if (!context.mounted) return;
            final done = await runCalmly(context, () async {
              await controller.block(view.otherId!);
              return true;
            }, success: '$name blocked.');
            if (done == true) router.go('/chats');
          },
          child: const Text('Block'),
        ),
      ],
    );
  }
}

/// Blocking is confirmed: it hides requests and stops messages.
Future<bool> confirmBlock(BuildContext context, String name) =>
    confirmCircleAction(
      context,
      title: 'Block $name?',
      message:
          '$name won’t be able to message you, and their message requests '
          'disappear. You can unblock them in You › Privacy.',
      confirm: 'Block',
    );

class _ComposerNote extends StatelessWidget {
  const _ComposerNote({
    required this.icon,
    required this.title,
    required this.text,
    required this.cancelLabel,
    required this.onCancel,
  });
  final IconData icon;
  final String title, text, cancelLabel;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Container(
        padding: const EdgeInsets.only(left: Space.md),
        decoration: BoxDecoration(
          color: CircleAccents.of(context).recessed,
          borderRadius: BorderRadius.circular(CircleRadius.tile),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelLarge),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: cancelLabel,
              icon: const Icon(Icons.close),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Choice = ({_MessageAction? action, String? emoji});

/// Long-press menu: the 8 reactions, then Reply, Copy, Edit, Unsend and
/// Report as they apply.
Future<_Choice?> _showMessageSheet(
  BuildContext context,
  MessageView message, {
  required bool canWrite,
  required bool canEdit,
}) => showModalBottomSheet<_Choice>(
  context: context,
  // Above the shell's navigation bar, so nothing is hidden.
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    final mine = message.reactions.mine;
    final interactive = message.interactive;
    Widget item(_MessageAction action, IconData icon, String label) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.section),
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop((action: action, emoji: null)),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.section),
            child: Semantics(
              header: true,
              child: Text('Message options', style: theme.textTheme.titleLarge),
            ),
          ),
          if (interactive && canWrite) ...[
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.section),
              child: Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final emoji in memoryReactions)
                    ChoiceChip(
                      selected: mine == emoji,
                      showCheckmark: false,
                      onSelected: (_) => Navigator.of(
                        context,
                      ).pop((action: null, emoji: emoji)),
                      label: Text(
                        emoji,
                        style: theme.textTheme.titleLarge,
                        semanticsLabel: mine == emoji
                            ? '${memoryReactionNames[emoji]}, your reaction. '
                                  'Choose again to remove'
                            : 'React with ${memoryReactionNames[emoji]}',
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.sm),
          if (interactive && canWrite)
            item(_MessageAction.reply, Icons.reply, 'Reply'),
          if (message.canForward)
            item(_MessageAction.forward, Icons.shortcut, 'Forward'),
          if (interactive && message.text.isNotEmpty)
            item(_MessageAction.copy, Icons.copy_outlined, 'Copy'),
          if (canEdit) item(_MessageAction.edit, Icons.edit_outlined, 'Edit'),
          if (message.canUnsend)
            item(_MessageAction.unsend, Icons.undo, 'Unsend'),
          if (message.hiddenByAdmins)
            item(
              _MessageAction.unhide,
              Icons.visibility_outlined,
              'Unhide for everyone',
            )
          else if (!message.mine && !message.unsent)
            item(_MessageAction.report, Icons.flag_outlined, 'Report'),
        ],
      ),
    );
  },
);

/// Author-only edit within 15 minutes; marks the message "Edited".
class _EditMessageSheet extends ConsumerStatefulWidget {
  const _EditMessageSheet({
    required this.conversationId,
    required this.message,
  });
  final String conversationId;
  final MessageView message;
  @override
  ConsumerState<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends ConsumerState<_EditMessageSheet> {
  late final _text = TextEditingController(text: widget.message.text);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final check = ChatRules.checkText(_text.text);
    if (!check.allowed) {
      setState(() => _error = check.reason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final saved = await runCalmly(context, () async {
      await ref
          .read(chatControllerProvider.notifier)
          .edit(widget.conversationId, widget.message.id, _text.text);
      return true;
    });
    if (!mounted) return;
    if (saved == true) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Edit message',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'You can edit for 15 minutes after sending. Everyone sees it '
            'marked as edited.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Message',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving locally…' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}

/// F1 in chat: the Memories poll editor (question + 2–12 options, calm
/// defaults behind "More poll options"). Returns the draft to send.
class _PollSheet extends StatefulWidget {
  const _PollSheet();
  @override
  State<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<_PollSheet> {
  final _form = PollForm();
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = _form.draft();
    final check = PollRules.checkDraft(draft);
    if (!check.allowed) {
      setState(() => _error = check.reason);
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'New poll',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Space.lg),
          PollEditor(
            form: _form,
            error: _error,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          FilledButton(onPressed: _submit, child: const Text('Send poll')),
        ],
      ),
    ),
  );
}

/// A simple chooser for Memories or events to share.
Future<String?> _pick(
  BuildContext context,
  String title,
  List<({String id, String title, String subtitle})> items,
) => showModalBottomSheet<String>(
  context: context,
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
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.section,
            Space.xs,
            Space.section,
            Space.sm,
          ),
          child: Text(
            'Only things everyone in this chat can already see.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.section),
            child: Text(
              'Nothing here can be seen by everyone in this chat yet.',
            ),
          ),
        for (final item in items)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.section,
            ),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(item.subtitle),
            onTap: () => Navigator.of(context).pop(item.id),
          ),
      ],
    ),
  ),
);
