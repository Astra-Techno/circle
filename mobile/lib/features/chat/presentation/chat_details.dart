import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../application/chat_providers.dart';
import '../../moderation/presentation/report_sheet.dart';
import 'chat_conversation.dart' show confirmBlock;
import 'chat_visuals.dart';

/// D4: shared Memories and events, members and the group space (group),
/// mute and pin, block/unblock and report (1:1).
class ChatDetailsScreen extends ConsumerWidget {
  const ChatDetailsScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ChatAsyncView<ConversationLoad>(
        provider: chatConversationProvider(id),
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
                  ),
                ],
              ),
            );
          }
          return _Details(view: view);
        },
      );
}

class _Details extends ConsumerWidget {
  const _Details({required this.view});
  final ConversationView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(chatControllerProvider.notifier);
    final now = ref.watch(circleClockProvider)().toUtc();
    final left = view.mode == ConversationMode.leftGroup;
    final shared = view.sharedItems;
    final inset = const EdgeInsets.symmetric(horizontal: Space.lg);
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form.copyWith(left: 0, right: 0),
        children: [
          Padding(
            padding: inset,
            child: Column(
              children: [
                ConversationAvatar(
                  title: view.title,
                  groupType: view.groupType,
                  size: CircleAvatarSize.hero,
                ),
                const SizedBox(height: Space.md),
                Semantics(
                  header: true,
                  child: Text(
                    view.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  view.isGroup
                      ? left
                            ? 'You left this group'
                            : 'Group chat · ${view.members.length} members · '
                                  'always matches the group'
                      : view.sharedGroups.isEmpty
                      ? 'No shared groups'
                      : 'You’re both in ${view.sharedGroups.join(', ')}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (view.isGroup && !left) ...[
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/groups/g/${view.groupId}'),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Open group space'),
                  ),
                ],
                const SizedBox(height: Space.md),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!left) ...[
            CircleRow(
              child: ListTile(
                leading: Icon(
                  view.muted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none,
                ),
                title: Text(view.muted ? 'Muted' : 'Mute'),
                subtitle: Text(
                  view.muted
                      ? muteLabel(
                          forever: view.mutedForever,
                          until: view.mutedUntil,
                          now: now,
                        )
                      : 'For 8 hours, 1 week or until you turn it back on',
                ),
                onTap: () async {
                  final choice = await showMuteSheet(
                    context,
                    title: view.title,
                    muted: view.muted,
                  );
                  if (choice == null || !context.mounted) return;
                  await runCalmly(
                    context,
                    () => controller.mute(view.id, choice.mute),
                    success: choice.mute == null ? 'Unmuted.' : 'Muted.',
                  );
                },
              ),
            ),
            CircleRow(
              child: SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin to the top of Chats'),
                value: view.pinned,
                onChanged: (value) => runCalmly(
                  context,
                  () => controller.setPinned(view.id, value),
                ),
              ),
            ),
          ],
          Padding(
            padding: inset,
            child: CircleSectionTitle(
              'Shared Memories and events (${shared.length})',
            ),
          ),
          if (shared.isEmpty)
            Padding(
              padding: inset,
              child: Text(
                'Memories and events shared here appear in this list.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final item in shared) _SharedRow(item: item),
          if (view.isGroup && !left) ...[
            Padding(
              padding: inset,
              child: CircleSectionTitle('Members (${view.members.length})'),
            ),
            for (final member in view.members)
              CircleRow(
                child: ListTile(
                  leading: CircleInitialAvatar(
                    name: member.name,
                    size: CircleAvatarSize.small,
                  ),
                  title: Text(member.name),
                  trailing:
                      member.role == null || member.role == CircleRole.member
                      ? null
                      : CircleBadge(
                          circleRoleLabel(member.role!),
                          strong: member.role == CircleRole.owner,
                        ),
                ),
              ),
          ],
          const SizedBox(height: Space.lg),
          if (!view.isGroup)
            CircleRow(
              child: ListTile(
                leading: const Icon(Icons.block),
                title: Text(
                  view.otherBlocked
                      ? 'Unblock ${view.title}'
                      : 'Block ${view.title}',
                ),
                subtitle: Text(
                  view.otherBlocked
                      ? 'They can message you again.'
                      : 'Stops their messages and hides their requests.',
                ),
                onTap: () async {
                  final other = view.otherId!;
                  if (view.otherBlocked) {
                    await runCalmly(
                      context,
                      () => controller.unblock(other),
                      success: '${view.title} unblocked.',
                      onUndo: undoDetached(
                        context,
                        () => controller.block(other),
                      ),
                    );
                    return;
                  }
                  if (!await confirmBlock(context, view.title)) return;
                  if (!context.mounted) return;
                  await runCalmly(
                    context,
                    () => controller.block(other),
                    success: '${view.title} blocked.',
                  );
                },
              ),
            ),
          if (!view.isGroup)
            CircleRow(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('Report ${view.title}'),
                subtitle: const Text(
                  'To report one message, long-press it in the chat.',
                ),
                onTap: () => showReportSheet(
                  context,
                  title: 'Report ${view.title}',
                  explanation: '${view.title} won’t know you reported them.',
                  confirmation: 'Thanks — we’ll review it.',
                  submit: (reason, note) =>
                      controller.report(view.id, reason: reason, note: note),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SharedRow extends StatelessWidget {
  const _SharedRow({required this.item});
  final SharedView item;
  @override
  Widget build(BuildContext context) {
    final memory = item.content.kind == SharedKind.memory;
    if (!item.visible) {
      return CircleRow(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(
            memory
                ? 'This Memory isn’t shared with you'
                : 'This event isn’t shared with you',
          ),
        ),
      );
    }
    final title = memory ? item.memory!.summary : item.event!.title;
    return CircleRow(
      child: ListTile(
        leading: Icon(
          memory ? Icons.photo_library_outlined : Icons.event_outlined,
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(item.audience ?? item.group?.name ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          memory
              ? '/home/memory/${item.content.id}'
              : '/events/e/${item.content.id}',
        ),
      ),
    );
  }
}
