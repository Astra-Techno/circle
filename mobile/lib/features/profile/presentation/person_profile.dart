import '../../groups/presentation/group_photos.dart';
import '../application/profile_providers.dart';
import 'profile_photo.dart';
import 'server_blocking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/presentation/chat_conversation.dart' show confirmBlock;
import '../../groups/presentation/group_members.dart' show personLocation;
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';

export '../../groups/presentation/group_members.dart' show personLocation;

/// H2: a member's profile as you may see it: name, groups you share, and
/// Message (only when they can be messaged), Block and Report. Only people
/// who share a group with you have a profile here; there is no global
/// directory.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({super.key, required this.person, this.groupId});
  final String person;

  /// The group the profile was opened from (where a report goes).
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final shared = [
        for (final group in workspace.groups)
          if (group.isMember(person)) group,
      ];
      if (person == workspace.viewer) {
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleEmpty(
                title: 'This is you',
                message: 'Your own settings live in You.',
                action: FilledButton(
                  onPressed: () => context.go('/you'),
                  child: const Text('Open You'),
                ),
              ),
            ],
          ),
        );
      }
      if (shared.isEmpty) {
        return const ReadingPane(
          child: Padding(
            padding: CircleInsets.form,
            child: CircleEmpty(
              title: 'This profile isn’t available',
              message: 'You can only see people who share a group with you.',
            ),
          ),
        );
      }
      final name = workspace.nameOf(person);
      final theme = Theme.of(context);
      final features = ref.watch(circleFeaturesProvider);
      final chat = features.has(CircleFeature.chat);
      // Chat isn't on every server yet; don't ask the chat service then.
      final contacts = chat ? ref.watch(chatContactsProvider).value : null;
      final privacy = chat ? ref.watch(chatPrivacyProvider).value : null;
      final contact = contacts
          ?.expand((group) => group.contacts)
          .where((contact) => contact.personId == person)
          .firstOrNull;
      final eligibility = contact?.eligibility;
      final blocked = privacy?.settings.blocked.contains(person) ?? false;
      final reportGroup =
          shared.where((group) => group.id == groupId).firstOrNull ??
          shared.first;
      final controller = ref.read(chatControllerProvider.notifier);

      Future<void> message() async {
        final router = GoRouter.of(context);
        final id = await runCalmly(
          context,
          () => controller.openDirect(person),
        );
        if (id != null) router.go('/chats/c/$id');
      }

      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            if (features.server) ...[
              AspectRatio(
                aspectRatio: CircleProfileLayout.coverAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CircleRadius.card),
                  child: SharedProfilePhotoSurface(
                    person: person,
                    kind: ProfilePhotoKind.cover,
                    name: name,
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Center(
                child: SharedProfilePhotoSurface(
                  person: person,
                  kind: ProfilePhotoKind.avatar,
                  name: name,
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(personPhotoCacheProvider).clear();
                    ref.invalidate(
                      sharedProfilePhotoBytesProvider((
                        person: person,
                        kind: ProfilePhotoKind.avatar,
                      )),
                    );
                    ref.invalidate(
                      sharedProfilePhotoBytesProvider((
                        person: person,
                        kind: ProfilePhotoKind.cover,
                      )),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh photos'),
                ),
              ),
            ] else
              Center(
                child: CircleInitialAvatar(
                  name: name,
                  size: CircleAvatarSize.hero,
                ),
              ),
            const SizedBox(height: Space.md),
            Semantics(
              header: true,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              features.server
                  ? 'Details stay private by default'
                  : 'Fictional member · details stay private by default',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.lg),
            if (chat)
              FilledButton.icon(
                key: const ValueKey('profile-message'),
                onPressed: eligibility == DirectEligibility.allowed
                    ? message
                    : null,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('Message $name'),
              ),
            if (chat &&
                eligibility != null &&
                eligibility != DirectEligibility.allowed)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  ChatRules.eligibilityMessage(eligibility, name),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            CircleSectionTitle('Groups in common (${shared.length})'),
            for (final group in shared)
              CircleRow(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GroupAvatar(
                    groupId: group.id,
                    type: group.type,
                    size: CircleAvatarSize.small,
                  ),
                  title: Text(group.name),
                  subtitle: switch (group.roles[person]) {
                    CircleRole.owner => const Text('Owner'),
                    CircleRole.admin => const Text('Admin'),
                    _ => null,
                  },
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/g/${group.id}'),
                ),
              ),
            const SizedBox(height: Space.lg),
            if (features.server && features.has(CircleFeature.blocking))
              ServerBlockButton(person: person, name: name),
            if (chat)
              CircleRow(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block),
                  title: Text(blocked ? 'Unblock $name' : 'Block $name'),
                  subtitle: Text(
                    blocked
                        ? 'They can message you again.'
                        : 'Stops their messages and hides their requests.',
                  ),
                  onTap: () async {
                    if (blocked) {
                      await runCalmly(
                        context,
                        () => controller.unblock(person),
                        success: '$name unblocked.',
                      );
                      return;
                    }
                    if (!await confirmBlock(context, name) ||
                        !context.mounted) {
                      return;
                    }
                    await runCalmly(
                      context,
                      () => controller.block(person),
                      success: '$name blocked.',
                    );
                  },
                ),
              ),
            if (features.has(CircleFeature.moderation) &&
                !workspace.reported(ReportKind.member, person))
              CircleRow(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text('Report $name'),
                  subtitle: Text('To the admins of ${reportGroup.name}'),
                  onTap: () => reportToAdmins(
                    context,
                    ref,
                    target: ReportTarget.member(
                      person,
                      groupId: reportGroup.id,
                    ),
                    what: name,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Opens a member's profile.
void openPerson(BuildContext context, String person, {String? groupId}) =>
    context.push(personLocation(person, groupId: groupId));
