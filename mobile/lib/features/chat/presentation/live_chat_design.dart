import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/presentation/group_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../profile/presentation/person_avatar.dart';

class ChatIdentity extends ConsumerWidget {
  const ChatIdentity({
    super.key,
    required this.name,
    this.person,
    this.groupId,
    this.group = false,
  });
  final String name;
  final String? person, groupId;
  final bool group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceGroup = groupId == null
        ? null
        : ref.watch(circleWorkspaceProvider).value?.group(groupId!);
    if (group && workspaceGroup != null) {
      return GroupAvatar(groupId: groupId!, type: workspaceGroup.type);
    }
    return person != null && !group
        ? PersonAvatar(person: person!, name: name)
        : CircleInitialAvatar(
            name: name,
            icon: group ? Icons.group_outlined : null,
          );
  }
}

class ChatInboxRow extends StatelessWidget {
  const ChatInboxRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.unread,
    required this.onTap,
    this.group = false,
    this.groupId,
    this.muted = false,
    this.pinned = false,
  });
  final String name, subtitle;
  final String? groupId;
  final int unread;
  final bool group, muted, pinned;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
          leading: ChatIdentity(name: name, group: group, groupId: groupId),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: unread > 0
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyLarge,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          trailing: Wrap(
            spacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (pinned)
                const Icon(Icons.push_pin_outlined, semanticLabel: 'Pinned'),
              if (muted)
                const Icon(
                  Icons.notifications_off_outlined,
                  semanticLabel: 'Muted',
                ),
              if (unread > 0)
                Badge(
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  backgroundColor: theme.colorScheme.primary,
                  textColor: theme.colorScheme.onPrimary,
                ),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(height: Space.xs),
      ],
    );
  }
}

class ChatConversationHeader extends StatelessWidget {
  const ChatConversationHeader({
    super.key,
    required this.name,
    required this.group,
    required this.active,
    this.person,
    this.groupId,
  });
  final String name;
  final String? person, groupId;
  final bool group, active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Row(
      children: [
        ChatIdentity(
          name: name,
          person: person,
          group: group,
          groupId: groupId,
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                active
                    ? (group ? 'Group conversation' : 'Direct conversation')
                    : 'Read-only conversation',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.mine,
    required this.child,
    this.actions,
    this.sentAt,
  });
  final bool mine;
  final Widget child;
  final Widget? actions;
  final DateTime? sentAt;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = sentAt?.toLocal();
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth - Space.xl,
          ),
          margin: const EdgeInsets.only(bottom: Space.sm),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : CircleAccents.of(context).recessed,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(CircleRadius.card),
              topRight: const Radius.circular(CircleRadius.card),
              bottomLeft: Radius.circular(
                mine ? CircleRadius.card : CircleRadius.xsmall,
              ),
              bottomRight: Radius.circular(
                mine ? CircleRadius.xsmall : CircleRadius.card,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              child,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (time != null)
                    Flexible(
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(TimeOfDay.fromDateTime(time)),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ?actions,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacks at large text sizes so the composer never squeezes the input away.
class ChatComposerLayout extends StatelessWidget {
  const ChatComposerLayout({
    super.key,
    required this.expanded,
    required this.children,
  });
  final bool expanded;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => expanded
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final child in children)
              if (child is TextField) Expanded(child: child) else child,
          ],
        );
}

/// Reachable by touch, keyboard and screen reader without a permanent toolbar.
class ChatMessageActions extends StatelessWidget {
  const ChatMessageActions({super.key, required this.children});
  final List<Widget> children;
  Widget _dismissBeforeAction(BuildContext context, Widget child) {
    VoidCallback? action(VoidCallback? callback) => callback == null
        ? null
        : () {
            Navigator.of(context, rootNavigator: true).pop();
            callback();
          };
    if (child is TextButton) {
      return TextButton(
        onPressed: action(child.onPressed),
        child: child.child!,
      );
    }
    if (child is IconButton) {
      return IconButton(
        onPressed: action(child.onPressed),
        icon: child.icon,
        tooltip: child.tooltip,
      );
    }
    if (child is Wrap) {
      return Wrap(
        spacing: child.spacing,
        runSpacing: Space.sm,
        children: child.children
            .map((item) => _dismissBeforeAction(context, item))
            .toList(),
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Message options',
    icon: const Icon(Icons.more_horiz),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Message options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...children.map((child) => _dismissBeforeAction(context, child)),
          ],
        ),
      ),
    ),
  );
}
