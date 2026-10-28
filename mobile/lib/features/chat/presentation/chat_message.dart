import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../events/presentation/circle_events.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../memories/presentation/memory_poll_card.dart';
import '../../memories/presentation/mention_text.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../domain/chat_rules.dart';

/// Marks the text inside a message bubble (not quotes or previews).
const bubbleTextKey = ValueKey('chat-bubble-text');

/// Space between bubbles of one run (Instagram-style tight grouping).
const _runSpacing = Space.xs / 2;

/// Callbacks a message offers. Every gesture has a non-gesture route: the
/// long-press menu, the action row a tap reveals, and screen-reader
/// actions (README §4.0).
class MessageCallbacks {
  const MessageCallbacks({
    required this.onSelect,
    required this.onLove,
    required this.onReply,
    required this.onMenu,
    required this.onVote,
    required this.onRetractVote,
    required this.onClosePoll,
    required this.onForward,
    required this.onOpenPhoto,
  });
  final void Function(MessageView message) onSelect, onLove, onReply, onMenu;

  /// Forward (text and shared cards only; see `ForwardRules`).
  final void Function(MessageView message) onForward;

  /// Opens a photo of a photo message full screen.
  final void Function(MessageView message, int index) onOpenPhoto;
  final Future<void> Function(MessageView message, Set<String> choices) onVote;
  final Future<void> Function(MessageView message) onRetractVote, onClosePoll;
}

/// One message: optional author name and avatar (incoming runs), quoted
/// reply, bubble, shared card or poll, reactions and, when selected, an
/// action row with the time.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.message,
    required this.viewer,
    required this.group,
    required this.firstInRun,
    required this.lastInRun,
    required this.selected,
    required this.callbacks,
    required this.timeLabel,
    required this.maxWidth,
  });
  final MessageView message;
  final String viewer;

  /// Group chats show the author's name above incoming runs.
  final bool group;
  final bool firstInRun, lastInRun, selected;
  final MessageCallbacks callbacks;
  final String timeLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: accents.caption,
    );
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatarSpace = CircleAvatarSize.small.diameter + Space.sm;
    final width = mine ? maxWidth : maxWidth - avatarSpace;
    final interactive = message.interactive;

    final content = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (group && !mine && firstInRun)
          Padding(
            padding: const EdgeInsets.only(left: Space.md, bottom: Space.xs),
            child: Text(message.authorName, style: caption),
          ),
        if (message.forwarded && interactive)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shortcut, size: 14, color: accents.caption),
                const SizedBox(width: Space.xs),
                Text('Forwarded', style: caption),
              ],
            ),
          ),
        if (message.replyTo != null) _ReplyQuote(reply: message.replyTo!),
        if (message.photos.isNotEmpty && interactive)
          Padding(
            padding: EdgeInsets.only(
              bottom: message.text.isNotEmpty ? Space.xs : 0,
            ),
            child: _PhotoMessage(message: message, callbacks: callbacks),
          ),
        if (message.text.isNotEmpty || !interactive)
          _Bubble(
            message: message,
            firstInRun: firstInRun,
            lastInRun: lastInRun,
            callbacks: callbacks,
          ),
        if (message.shared != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: GestureDetector(
              onLongPress: () => callbacks.onMenu(message),
              child: SharedContentCard(shared: message.shared!, viewer: viewer),
            ),
          ),
        if (message.poll != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: GestureDetector(
              onLongPress: () => callbacks.onMenu(message),
              child: PollCard(
                poll: message.poll!,
                onVote: (choices) => callbacks.onVote(message, choices),
                onRetract: () => callbacks.onRetractVote(message),
                onClose: () => callbacks.onClosePoll(message),
              ),
            ),
          ),
        if (message.edited && interactive)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text('Edited', style: caption),
          ),
        if (message.hiddenByAdmins)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 14,
                  color: accents.caption,
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    'Hidden by admins · only admins see it',
                    style: caption,
                  ),
                ),
              ],
            ),
          ),
        if (message.reactions.total > 0)
          _Reactions(reactions: message.reactions),
        if (selected && interactive)
          _VisibleActions(
            message: message,
            timeLabel: timeLabel,
            callbacks: callbacks,
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: firstInRun ? Space.sm : _runSpacing),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine)
            SizedBox(
              width: avatarSpace,
              child: lastInRun
                  ? Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: PersonAvatar(
                        person: message.authorId,
                        name: message.authorName,
                        size: CircleAvatarSize.small,
                      ),
                    )
                  : null,
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: interactive
                  ? SwipeToReply(
                      onReply: () => callbacks.onReply(message),
                      child: content,
                    )
                  : content,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.firstInRun,
    required this.lastInRun,
    required this.callbacks,
  });
  final MessageView message;
  final bool firstInRun, lastInRun;
  final MessageCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = CircleAccents.of(context);
    final mine = message.mine;
    const round = Radius.circular(CircleRadius.sheet);
    const joined = Radius.circular(CircleRadius.xsmall);
    final radius = mine
        ? BorderRadius.only(
            topLeft: round,
            bottomLeft: round,
            topRight: firstInRun ? round : joined,
            bottomRight: lastInRun ? round : joined,
          )
        : BorderRadius.only(
            topRight: round,
            bottomRight: round,
            topLeft: firstInRun ? round : joined,
            bottomLeft: lastInRun ? round : joined,
          );
    if (!message.interactive) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: accents.hairline),
        ),
        child: Text(
          message.unsent && message.mine
              ? 'You unsent a message'
              : message.summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: accents.caption,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final ink = mine ? colors.onPrimary : accents.title;
    final about =
        '${message.mine ? 'Your message' : message.authorName}: '
        '${message.text}';
    return Semantics(
      label: about,
      button: true,
      excludeSemantics: true,
      onTap: () => callbacks.onSelect(message),
      onLongPress: () => callbacks.onMenu(message),
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Love'): () =>
            callbacks.onLove(message),
        const CustomSemanticsAction(label: 'Reply'): () =>
            callbacks.onReply(message),
      },
      child: GestureDetector(
        // Double-tap ❤️; a single tap reveals the action row; long-press
        // opens every option.
        onTap: () => callbacks.onSelect(message),
        onDoubleTap: () => callbacks.onLove(message),
        onLongPress: () => callbacks.onMenu(message),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            color: mine ? colors.primary : colors.surfaceContainer,
            borderRadius: radius,
            border: mine ? null : Border.all(color: accents.hairline),
          ),
          child: message.mentions.isEmpty
              ? Text(
                  message.text,
                  key: bubbleTextKey,
                  style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                )
              : MentionText(
                  message.text,
                  key: bubbleTextKey,
                  names: message.mentions.values,
                  onPrimary: mine,
                  style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                ),
        ),
      ),
    );
  }
}

/// Drag a message to the right to reply (README §3.2). The same action is
/// in the long-press menu and the tap action row.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.onReply, required this.child});
  final VoidCallback onReply;
  final Widget child;
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  static const _trigger = Space.hero + Space.lg;
  double _offset = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragUpdate: (details) => setState(
      () => _offset = (_offset + details.delta.dx).clamp(0, _trigger * 1.5),
    ),
    onHorizontalDragEnd: (_) {
      if (_offset >= _trigger) widget.onReply();
      setState(() => _offset = 0);
    },
    onHorizontalDragCancel: () => setState(() => _offset = 0),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (_offset > 0)
          PositionedDirectional(
            start: -Space.section,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: (_offset / _trigger).clamp(0, 1),
              child: Icon(
                Icons.reply,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Transform.translate(offset: Offset(_offset, 0), child: widget.child),
      ],
    ),
  );
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.reply});
  final ReplyPreview reply;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Semantics(
      label: 'Reply to ${reply.authorName}: ${reply.text}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: accents.recessed,
          border: Border.all(color: accents.hairline),
          borderRadius: BorderRadius.circular(CircleRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Replying to ${reply.authorName}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accents.caption,
              ),
            ),
            Text(
              reply.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Reactions extends StatelessWidget {
  const _Reactions({required this.reactions});
  final MemoryReactions reactions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final emoji = reactions.ranked.take(3).map((r) => r.emoji).join();
    // A label, not a button: reacting lives in the bubble's gestures,
    // action row and menu.
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Semantics(
        label: reactions.describe(),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: accents.hairline),
            borderRadius: BorderRadius.circular(CircleRadius.pill),
          ),
          child: Text(
            reactions.total > 1 ? '$emoji ${reactions.total}' : emoji,
            style: theme.textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.message,
    required this.timeLabel,
    required this.callbacks,
  });
  final MessageView message;
  final String timeLabel;
  final MessageCallbacks callbacks;
  @override
  Widget build(BuildContext context) {
    final loved = message.reactions.mine == loveReaction;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: message.mine ? WrapAlignment.end : WrapAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Text(
            timeLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => callbacks.onLove(message),
          icon: Icon(loved ? Icons.favorite : Icons.favorite_border),
          label: Text(loved ? 'Loved' : 'Love'),
        ),
        TextButton.icon(
          onPressed: () => callbacks.onReply(message),
          icon: const Icon(Icons.reply),
          label: const Text('Reply'),
        ),
        if (message.canForward)
          TextButton.icon(
            onPressed: () => callbacks.onForward(message),
            icon: const Icon(Icons.shortcut),
            label: const Text('Forward'),
          ),
        TextButton(
          onPressed: () => callbacks.onMenu(message),
          child: const Text('More'),
        ),
      ],
    );
  }
}

/// A photo message: the Memories photo grid inside a rounded frame. Tap a
/// photo to open it; double-tap anywhere for ❤️; long-press for every
/// option (react, reply, unsend, report). Screen readers get Love and
/// Reply as actions.
class _PhotoMessage extends StatelessWidget {
  const _PhotoMessage({required this.message, required this.callbacks});
  final MessageView message;
  final MessageCallbacks callbacks;
  @override
  Widget build(BuildContext context) {
    final count = message.photos.length;
    final who = message.mine ? 'You' : message.authorName;
    return Semantics(
      container: true,
      label: '$who sent ${count == 1 ? 'a photo' : '$count photos'}',
      onLongPress: () => callbacks.onMenu(message),
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Love'): () =>
            callbacks.onLove(message),
        const CustomSemanticsAction(label: 'Reply'): () =>
            callbacks.onReply(message),
        const CustomSemanticsAction(label: 'Message options'): () =>
            callbacks.onMenu(message),
      },
      child: GestureDetector(
        key: ValueKey('photo-message-${message.id}'),
        // The gaps between photos count too.
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => callbacks.onLove(message),
        onLongPress: () => callbacks.onMenu(message),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          child: PhotoGrid(
            photos: message.photos,
            onOpen: (index) => callbacks.onOpenPhoto(message, index),
          ),
        ),
      ),
    );
  }
}

/// A Memory or event shared into chat. The viewer's access is re-checked
/// when the card is built; sharing never grants access (ADR 0003).
class SharedContentCard extends StatelessWidget {
  const SharedContentCard({
    super.key,
    required this.shared,
    required this.viewer,
  });
  final SharedView shared;
  final String viewer;
  @override
  Widget build(BuildContext context) {
    final access = ChatRules.canSeeShared(
      shared.content,
      visible: shared.visible,
    );
    if (!access.allowed) return _NoAccessCard(message: access.reason!);
    final event = shared.event;
    if (event != null) {
      return CircleEventCard(
        event: event,
        group: shared.group!,
        viewer: viewer,
        audience: shared.audience,
      );
    }
    return _SharedMemoryCard(shared: shared);
  }
}

class _SharedMemoryCard extends StatelessWidget {
  const _SharedMemoryCard({required this.shared});
  final SharedView shared;
  @override
  Widget build(BuildContext context) {
    final memory = shared.memory!;
    final group = shared.group!;
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: CircleAccents.of(context).caption,
    );
    final photos = memory.photos.length;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/memory/${memory.id}'),
        child: Semantics(
          label:
              'Shared Memory from ${memory.author} in ${group.name}: '
              '${memory.summary}. Open Memory',
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PersonAvatar(
                      person: memory.authorId,
                      name: memory.author,
                      tone: circleTypeTone(group.type),
                      size: CircleAvatarSize.small,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        memory.author,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                CirclePill(
                  shared.audience ?? group.name,
                  icon: Icons.lock_outline,
                  tone: circleTypeTone(group.type),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  memory.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (photos > 0) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    photos == 1 ? '1 photo' : '$photos photos',
                    style: caption,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoAccessCard extends StatelessWidget {
  const _NoAccessCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Semantics(
      container: true,
      label: '$message. Sharing never opens a group to new people.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          border: Border.all(color: accents.hairline),
          borderRadius: BorderRadius.circular(CircleRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: accents.caption),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Sharing never opens a group to new people.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accents.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reveal actions within the viewport when a selected bubble grows.
class _VisibleActions extends StatefulWidget {
  const _VisibleActions({
    required this.message,
    required this.timeLabel,
    required this.callbacks,
  });
  final MessageView message;
  final String timeLabel;
  final MessageCallbacks callbacks;
  @override
  State<_VisibleActions> createState() => _VisibleActionsState();
}

class _VisibleActionsState extends State<_VisibleActions> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) => _ActionRow(
    message: widget.message,
    timeLabel: widget.timeLabel,
    callbacks: widget.callbacks,
  );
}
