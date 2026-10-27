import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/chat_providers.dart';
import 'chat_visuals.dart';

/// H3 (chat subset): who can message me, close groups and blocked people.
/// Enforced by `ChatRules` and the chat repository.
class ChatPrivacyScreen extends ConsumerWidget {
  const ChatPrivacyScreen({super.key});
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => ChatAsyncView<ChatPrivacyView>(
    provider: chatPrivacyProvider,
    builder: (privacy) {
      final controller = ref.read(chatControllerProvider.notifier);
      final theme = Theme.of(context);
      final settings = privacy.settings;
      const inset = EdgeInsets.symmetric(horizontal: Space.lg);
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form.copyWith(left: 0, right: 0),
          children: [
            const Padding(
              padding: inset,
              child: CircleHeading(
                title: 'Privacy',
                subtitle: 'Choose who can reach you in 1:1 chats.',
              ),
            ),
            const Padding(
              padding: inset,
              child: PreviewLabel(
                'Preview: these settings stay on this device.',
              ),
            ),
            const Padding(
              padding: inset,
              child: CircleSectionTitle('Who can message me'),
            ),
            RadioGroup<WhoCanMessage>(
              groupValue: settings.whoCanMessage,
              onChanged: (value) {
                if (value == null) return;
                runCalmly(
                  context,
                  () => controller.setWhoCanMessage(value),
                  success: 'Saved: ${value.label}.',
                );
              },
              child: Column(
                children: [
                  for (final option in WhoCanMessage.values)
                    RadioListTile<WhoCanMessage>(
                      value: option,
                      title: Text(option.label),
                      subtitle: Text(option.description),
                    ),
                ],
              ),
            ),
            Padding(
              padding: inset,
              child: Text(
                'Group chats always include everyone in the group.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Padding(
              padding: inset,
              child: CircleSectionTitle('Activity status'),
            ),
            CircleRow(
              child: SwitchListTile(
                title: const Text('Show activity status'),
                subtitle: const Text(
                  'When this is off, people can’t see when you were last '
                  'active, and you can’t see theirs.',
                ),
                value: settings.showActivity,
                onChanged: (value) => runCalmly(
                  context,
                  () => controller.setShowActivity(value),
                  success: value
                      ? 'Activity status is on.'
                      : 'Activity status is off.',
                ),
              ),
            ),
            Padding(
              padding: inset,
              child: Text(
                'Only shown in 1:1 chats, to people who share a group with '
                'you, and never older than 2 days. People whose message '
                'request you haven’t accepted don’t see it.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Padding(
              padding: inset,
              child: CircleSectionTitle('Close groups'),
            ),
            Padding(
              padding: inset,
              child: Text(
                'First messages from people in your close groups skip '
                'Requests. Groups with up to '
                '${ChatRules.closeGroupMaxMembers} members are close '
                'unless you change them.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (privacy.groups.isEmpty)
              const Padding(
                padding: inset,
                child: Text('Join a group to choose close groups.'),
              ),
            for (final group in privacy.groups)
              CircleRow(
                child: SwitchListTile(
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.roles.length} members · '
                    '${settings.closeGroups.containsKey(group.id) ? 'your choice' : 'default'}',
                  ),
                  value: ChatRules.isCloseGroup(group, settings),
                  onChanged: (value) => runCalmly(
                    context,
                    () => controller.setCloseGroup(group.id, value),
                  ),
                ),
              ),
            const Padding(
              padding: inset,
              child: CircleSectionTitle('Blocked people'),
            ),
            if (privacy.blocked.isEmpty)
              Padding(
                padding: inset,
                child: Text(
                  'Nobody. People you block can’t message you, and their '
                  'requests disappear.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final person in privacy.blocked)
              CircleRow(
                child: ListTile(
                  leading: PersonAvatar(
                    person: person.id,
                    name: person.name,
                    tone: CircleTone.neutral,
                    size: CircleAvatarSize.small,
                  ),
                  title: Text(person.name),
                  trailing: TextButton(
                    onPressed: () => runCalmly(
                      context,
                      () => controller.unblock(person.id),
                      success: '${person.name} unblocked.',
                      onUndo: undoDetached(
                        context,
                        () => controller.block(person.id),
                      ),
                    ),
                    child: Text(
                      'Unblock',
                      semanticsLabel: 'Unblock ${person.name}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
