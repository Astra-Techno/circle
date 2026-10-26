import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/profile_providers.dart';

/// Authenticated bytes are provided by the application layer, never a public URL.
class ProfilePhotoSurface extends ConsumerWidget {
  const ProfilePhotoSurface({
    super.key,
    required this.kind,
    required this.version,
    this.name = 'You',
    this.size = CircleAvatarSize.medium,
  });
  final ProfilePhotoKind kind;
  final String? version;
  final String name;
  final CircleAvatarSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = kind == ProfilePhotoKind.avatar;
    final fallback = avatar
        ? Center(
            child: CircleInitialAvatar(name: name, size: size),
          )
        : DecoratedBox(
            decoration: CircleDepth.profilePanel(context),
            child: Center(
              child: Icon(
                Icons.landscape_outlined,
                size: Space.large,
                color: CircleAccents.of(context).calmText,
              ),
            ),
          );
    final revision = version;
    Widget content = fallback;
    if (revision != null) {
      final query = (kind: kind, version: revision);
      content = ref
          .watch(profilePhotoBytesProvider(query))
          .when(
            data: (bytes) => Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => fallback,
              excludeFromSemantics: true,
            ),
            loading: () => Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                const Center(
                  child: SizedBox(
                    width: Space.section,
                    height: Space.section,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
            error: (_, _) => Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                Center(
                  child: IconButton.filledTonal(
                    tooltip:
                        'Retry loading ${avatar ? 'profile' : 'cover'} photo',
                    onPressed: () =>
                        ref.invalidate(profilePhotoBytesProvider(query)),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          );
    }
    final image = Semantics(
      image: true,
      label: '${avatar ? 'Profile' : 'Cover'} photo for $name',
      child: content,
    );
    return avatar
        ? SizedBox.square(
            dimension: size.diameter,
            child: ClipOval(child: image),
          )
        : image;
  }
}

class ProfileHeader extends ConsumerStatefulWidget {
  const ProfileHeader({super.key, required this.account});
  final ApiAccount account;
  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> {
  bool _busy = false;

  Future<void> _photo(ProfilePhotoKind kind) async {
    if (_busy) return;
    final accountId = widget.account.id;
    final api = ref.read(apiClientProvider);
    final existing = widget.account.photoVersion(kind) != null;
    final label = kind == ProfilePhotoKind.avatar ? 'profile' : 'cover';
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${kind == ProfilePhotoKind.avatar ? 'Profile' : 'Cover'} photo',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.sm),
            const Text(
              'Visible to people who share a group with you. Your original photo metadata is removed.',
            ),
            const SizedBox(height: Space.sm),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(existing ? 'Replace photo' : 'Choose a photo'),
              onTap: () => Navigator.pop(sheet, 'choose'),
            ),
            if (existing)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (action == null ||
        !mounted ||
        ref.read(serverAccountProvider)?.id != accountId ||
        !identical(ref.read(apiClientProvider), api)) {
      return;
    }
    setState(() => _busy = true);
    try {
      String? error;
      final session = ref.read(serverSessionProvider.notifier);
      if (action == 'remove') {
        error = await session.deleteProfilePhoto(kind);
      } else {
        final picked = await ref.read(profilePhotoPickerProvider).pick();
        if (picked == null ||
            !mounted ||
            ref.read(serverAccountProvider)?.id != accountId ||
            !identical(ref.read(apiClientProvider), api)) {
          return;
        }
        error = await session.uploadProfilePhoto(kind, picked);
      }
      if (!mounted ||
          ref.read(serverAccountProvider)?.id != accountId ||
          !identical(ref.read(apiClientProvider), api)) {
        return;
      }
      showCircleMessage(
        context,
        error ??
            '${kind == ProfilePhotoKind.avatar ? 'Profile' : 'Cover'} photo ${action == 'remove' ? 'removed' : 'updated'}.',
      );
    } on CircleFailure catch (error) {
      if (mounted) showCircleMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showCircleMessage(
          context,
          'The $label photo couldn’t be updated. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final name = account.displayName.isEmpty ? 'You' : account.displayName;
    final theme = Theme.of(context);
    return Container(
      decoration: CircleDepth.profilePanel(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final coverHeight =
                  (constraints.maxWidth / CircleProfileLayout.coverAspectRatio)
                      .clamp(
                        CircleProfileLayout.minCoverHeight,
                        CircleProfileLayout.maxCoverHeight,
                      );
              final avatar = CircleAvatarSize.profile.diameter;
              return SizedBox(
                height: coverHeight + avatar / 2,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: coverHeight,
                      child: ProfilePhotoSurface(
                        kind: ProfilePhotoKind.cover,
                        version: account.coverVersion,
                        name: name,
                      ),
                    ),
                    PositionedDirectional(
                      top: Space.sm,
                      end: Space.sm,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () => _photo(ProfilePhotoKind.cover),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          account.coverVersion == null
                              ? 'Add cover'
                              : 'Change cover',
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: Space.lg,
                      bottom: 0,
                      child: SizedBox.square(
                        dimension: avatar + Space.sm,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(Space.xs),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surface,
                              ),
                              child: ProfilePhotoSurface(
                                kind: ProfilePhotoKind.avatar,
                                version: account.avatarVersion,
                                name: name,
                                size: CircleAvatarSize.profile,
                              ),
                            ),
                            PositionedDirectional(
                              end: 0,
                              bottom: 0,
                              child: IconButton.filledTonal(
                                tooltip: account.avatarVersion == null
                                    ? 'Add profile photo'
                                    : 'Change profile photo',
                                onPressed: _busy
                                    ? null
                                    : () => _photo(ProfilePhotoKind.avatar),
                                icon: const Icon(Icons.photo_camera_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.headlineMedium),
                if (account.about.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  Text(account.about),
                ],
                if (_busy) ...[
                  const SizedBox(height: Space.md),
                  const LinearProgressIndicator(
                    semanticsLabel: 'Updating profile photo',
                  ),
                ],
                const SizedBox(height: Space.lg),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => context.push('/you/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/groups'),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Your groups'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
