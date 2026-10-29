import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/profile_providers.dart';

/// One identity-based avatar for every person row. Never resolves by name.
/// Unknown/missing photos and preview-only people remain initials without HTTP.
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({
    super.key,
    required this.person,
    required this.name,
    this.size = CircleAvatarSize.medium,
    this.tone = CircleTone.calm,
    this.active = false,
  });
  final String person, name;
  final CircleAvatarSize size;
  final CircleTone tone;
  final bool active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(serverAccountProvider);
    final workspace = account == null
        ? null
        : ref.watch(circleWorkspaceProvider).value;
    ImageProvider<Object>? image;
    if (account != null && workspace?.viewer == account.id) {
      if (person == account.id && account.avatarVersion != null) {
        final bytes = ref
            .watch(
              profilePhotoBytesProvider((
                kind: ProfilePhotoKind.avatar,
                version: account.avatarVersion!,
              )),
            )
            .value;
        if (bytes != null) image = MemoryImage(bytes);
      } else if (workspace!.avatarVersions[person] != null &&
          workspace.groups.any(
            (g) => g.isMember(workspace.viewer) && g.isMember(person),
          )) {
        final bytes = ref
            .watch(
              sharedProfilePhotoBytesProvider((
                person: person,
                kind: ProfilePhotoKind.avatar,
              )),
            )
            .value;
        if (bytes != null) image = MemoryImage(bytes);
      }
    }
    return CircleInitialAvatar(
      name: name,
      image: image,
      size: size,
      tone: tone,
      active: active,
    );
  }
}
