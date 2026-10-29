import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/presentation/group_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../profile/presentation/person_avatar.dart';

/// WhatsApp-style chat pieces for live (server) conversations: inbox rows,
/// a full-screen conversation bar, day chips, tailed bubbles with the time
/// inside, and a rounded composer with a round send button.

class ChatIdentity extends ConsumerWidget {
  const ChatIdentity({
    super.key,
    required this.name,
    this.person,
    this.groupId,
    this.group = false,
    this.size = CircleAvatarSize.medium,
  });
  final String name;
  final String? person, groupId;
  final bool group;
  final CircleAvatarSize size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceGroup = groupId == null
        ? null
        : ref.watch(circleWorkspaceProvider).value?.group(groupId!);
    if (group && workspaceGroup != null) {
      return GroupAvatar(
        groupId: groupId!,
        type: workspaceGroup.type,
        size: size,
      );
    }
    return person != null && !group
        ? PersonAvatar(person: person!, name: name, size: size)
        : CircleInitialAvatar(
            name: name,
            icon: group ? Icons.group_outlined : null,
            size: size,
          );
  }
}

/// "9:41 AM" today, "Yesterday", a weekday within the week, else a date.
String chatInboxTime(BuildContext context, DateTime at, DateTime now) {
  final local = at.toLocal(), today = DateUtils.dateOnly(now);
  final day = DateUtils.dateOnly(local);
  final days = today.difference(day).inDays;
  final l10n = MaterialLocalizations.of(context);
  if (days <= 0) return l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  if (days == 1) return 'Yesterday';
  if (days < 7) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][local.weekday - 1];
  }
  return l10n.formatShortDate(local);
}

/// "Today", "Yesterday", or the full date, for the chip between days.
String chatDayLabel(BuildContext context, DateTime at, DateTime now) {
  final day = DateUtils.dateOnly(at.toLocal());
  final days = DateUtils.dateOnly(now).difference(day).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return MaterialLocalizations.of(context).formatMediumDate(day);
}

/// One inbox row: photo, name, last message and time, unread count.
class ChatInboxRow extends StatelessWidget {
  const ChatInboxRow({
    super.key,
    required this.name,
    required this.preview,
    required this.unread,
    required this.onTap,
    this.time,
    this.previewIcon,
    this.group = false,
    this.groupId,
    this.person,
    this.muted = false,
    this.pinned = false,
    this.highlight = false,
  });
  final String name, preview;
  final String? time, groupId, person;
  final IconData? previewIcon;
  final int unread;
  final bool group, muted, pinned;

  /// A message request: the preview is shown in the primary colour.
  final bool highlight;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final fresh = unread > 0;
    final meta = theme.textTheme.bodySmall?.copyWith(
      color: fresh ? theme.colorScheme.primary : accents.caption,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.sm,
        ),
        child: Row(
          children: [
            ChatIdentity(
              name: name,
              group: group,
              groupId: groupId,
              person: person,
              size: CircleAvatarSize.large,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: accents.hairline)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (time != null) ...[
                            const SizedBox(width: Space.sm),
                            Text(time!, style: meta),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Row(
                        children: [
                          if (previewIcon != null) ...[
                            Icon(
                              previewIcon,
                              size: Space.lg,
                              color: accents.caption,
                            ),
                            const SizedBox(width: Space.xs),
                          ],
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: highlight
                                    ? theme.colorScheme.primary
                                    : accents.caption,
                              ),
                            ),
                          ),
                          if (muted)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: Space.xs,
                              ),
                              child: Icon(
                                Icons.volume_off_outlined,
                                size: Space.lg + Space.xs,
                                color: accents.caption,
                                semanticLabel: 'Muted',
                              ),
                            ),
                          if (pinned)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: Space.xs,
                              ),
                              child: Icon(
                                Icons.push_pin_outlined,
                                size: Space.lg + Space.xs,
                                color: accents.caption,
                                semanticLabel: 'Pinned',
                              ),
                            ),
                          if (fresh)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: Space.sm,
                              ),
                              child: Badge(
                                label: Text(unread > 99 ? '99+' : '$unread'),
                                backgroundColor: theme.colorScheme.primary,
                                textColor: theme.colorScheme.onPrimary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The conversation's own top bar: back, photo, name and an options button.
class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    required this.name,
    required this.subtitle,
    required this.group,
    required this.onBack,
    required this.onOptions,
    this.person,
    this.groupId,
  });
  final String name, subtitle;
  final String? person, groupId;
  final bool group;
  final VoidCallback onBack, onOptions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CircleAccents.of(context).hairline),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            children: [
              BackButton(onPressed: onBack),
              ChatIdentity(
                name: name,
                person: person,
                group: group,
                groupId: groupId,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
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
              ),
              IconButton(
                tooltip: 'Conversation options',
                onPressed: onOptions,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small centred chip between days ("Today", "Yesterday", a date) and
/// for system notes such as a message request.
class ChatNoticeChip extends StatelessWidget {
  const ChatNoticeChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CircleAccents.of(context).chatIncoming,
            borderRadius: BorderRadius.circular(CircleRadius.small),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: CircleAccents.of(context).caption,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A WhatsApp-style bubble: incoming on the left in white, the viewer's own
/// on the right in the outgoing tint, a tail on the first of a run, the
/// time tucked into the bottom corner, and long-press for message options.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.mine,
    required this.child,
    this.sender,
    this.quote,
    this.photos = const [],
    this.edited = false,
    this.tail = true,
    this.sentAt,
    this.reactions = const [],
    this.onOptions,
  });
  final bool mine, edited, tail;

  /// The message text (or the unsent note).
  final Widget child;

  /// Sender name for incoming group messages (first of a run).
  final String? sender;

  /// A quoted reply shown at the top of the bubble.
  final Widget? quote;
  final List<Widget> photos;
  final DateTime? sentAt;
  final List<String> reactions;
  final VoidCallback? onOptions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final time = sentAt?.toLocal();
    final stamp = [
      if (edited) 'Edited',
      if (time != null)
        MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(time)),
    ].join(' · ');
    final stampStyle = theme.textTheme.bodySmall?.copyWith(
      color: accents.caption,
    );
    final colour = mine ? accents.chatOutgoing : accents.chatIncoming;
    const radius = Radius.circular(CircleRadius.small);
    final bubble = Container(
      margin: EdgeInsets.only(
        top: tail ? Space.sm : Space.xs / 2,
        bottom: reactions.isEmpty ? 0 : Space.md,
      ),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.only(
          topLeft: !mine && tail ? Radius.zero : radius,
          topRight: mine && tail ? Radius.zero : radius,
          bottomLeft: radius,
          bottomRight: radius,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.sm,
        Space.xs + Space.xs / 2,
        Space.sm,
        Space.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sender != null)
            Text(
              sender!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ?quote,
          for (final photo in photos)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CircleRadius.small),
                child: photo,
              ),
            ),
          // The time sits after the text; a hidden copy reserves its space
          // so the two never overlap (WhatsApp's layout).
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(child: child),
                      TextSpan(
                        text: '  $stamp',
                        style: stampStyle?.copyWith(color: Colors.transparent),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: ExcludeSemantics(child: Text(stamp, style: stampStyle)),
              ),
            ],
          ),
        ],
      ),
    );
    final withReactions = reactions.isEmpty
        ? bubble
        : Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              PositionedDirectional(
                start: mine ? null : Space.sm,
                end: mine ? Space.sm : null,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accents.chatIncoming,
                    borderRadius: BorderRadius.circular(CircleRadius.pill),
                    border: Border.all(color: accents.chatWallpaper),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xs + Space.xs / 2,
                    ),
                    child: Text(
                      reactions.join(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
          child: Semantics(
            container: true,
            label: [
              if (mine) 'You' else ?sender,
              if (edited) 'edited',
              if (time != null)
                MaterialLocalizations.of(
                  context,
                ).formatTimeOfDay(TimeOfDay.fromDateTime(time)),
            ].join(', '),
            onLongPressHint: onOptions == null ? null : 'Message options',
            customSemanticsActions: onOptions == null
                ? null
                : {
                    const CustomSemanticsAction(label: 'Message options'):
                        onOptions!,
                  },
            child: GestureDetector(
              onLongPress: onOptions,
              child: withReactions,
            ),
          ),
        ),
      ),
    );
  }
}

/// The quoted message at the top of a reply bubble.
class ChatQuote extends StatelessWidget {
  const ChatQuote({super.key, required this.author, required this.text});
  final String author, text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(CircleRadius.xsmall),
        border: BorderDirectional(
          start: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp-style composer: a rounded input with the photo button inside,
/// and a round send button beside it. Stacks at large text sizes so the
/// input is never squeezed away.
class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    super.key,
    required this.field,
    required this.send,
    this.photo,
    this.expanded = false,
  });
  final TextField field;
  final Widget send;
  final Widget? photo;
  final bool expanded;
  @override
  Widget build(BuildContext context) {
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: CircleAccents.of(context).chatIncoming,
        borderRadius: BorderRadius.circular(CircleRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: Space.md),
          Expanded(child: field),
          ?photo,
        ],
      ),
    );
    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pill,
          const SizedBox(height: Space.sm),
          Align(alignment: AlignmentDirectional.centerEnd, child: send),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: pill),
        const SizedBox(width: Space.sm),
        send,
      ],
    );
  }
}

/// Opens the message options sheet (reply, heart, edit, unsend, report).
/// Each action closes the sheet before it runs.
Future<void> showChatMessageActions(
  BuildContext context,
  List<Widget> children,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (sheet) {
    Widget dismissFirst(Widget child) {
      VoidCallback? action(VoidCallback? callback) => callback == null
          ? null
          : () {
              Navigator.of(sheet).pop();
              callback();
            };
      if (child is ListTile) {
        return ListTile(
          leading: child.leading,
          title: child.title,
          onTap: action(child.onTap),
        );
      }
      return child;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.lg),
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
            child: Text(
              'Message options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...children.map(dismissFirst),
        ],
      ),
    );
  },
);
