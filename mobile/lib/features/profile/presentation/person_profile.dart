import '../../groups/presentation/group_photos.dart';
import '../application/profile_providers.dart';
import 'profile_photo.dart';
import 'server_blocking.dart';
import '../../chat/application/live_chat.dart';
import 'package:flutter/material.dart';
import '../../memories/presentation/memory_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
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
      final reportGroup =
          shared.where((group) => group.id == groupId).firstOrNull ??
          shared.first;

      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            ...[
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
            ],
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
              'Details stay private by default',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.lg),
            if (features.has(CircleFeature.liveChat))
              FilledButton.icon(
                onPressed: () async {
                  final api = ref.read(liveChatApiProvider);
                  final id = await runCalmly(context, () => api.direct(person));
                  if (context.mounted && id != null) context.go('/chats/c/$id');
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('Message $name'),
              ),
            const CircleSectionTitle('Recent Memories'),
            MemoryGrid(
              memories: [
                for (final memory in workspace.memories)
                  if (memory.authorId == person) memory,
              ],
              empty: '$name hasn’t shared recently in your circles.',
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
            if (features.has(CircleFeature.blocking))
              ServerBlockButton(person: person, name: name),
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
