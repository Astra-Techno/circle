import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../application/group_photos.dart';

class GroupAvatar extends ConsumerWidget {
  const GroupAvatar({
    super.key,
    required this.groupId,
    required this.type,
    this.size = CircleAvatarSize.medium,
  });
  final String groupId;
  final CircleType type;
  final CircleAvatarSize size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(circleWorkspaceProvider).value?.group(groupId);
    final version = group?.avatarVersion;
    ImageProvider<Object>? image;
    if (version != null) {
      final bytes = ref
          .watch(
            groupPhotoBytesProvider((
              group: groupId,
              kind: ProfilePhotoKind.avatar,
              version: version,
            )),
          )
          .value;
      if (bytes != null) image = MemoryImage(bytes);
    }
    return CircleInitialAvatar(
      icon: circleTypeIcon(type),
      tone: circleTypeTone(type),
      size: size,
      image: image,
    );
  }
}

class GroupPhotoHeader extends ConsumerStatefulWidget {
  const GroupPhotoHeader({super.key, required this.group});
  final CircleGroup group;
  @override
  ConsumerState<GroupPhotoHeader> createState() => _GroupPhotoHeaderState();
}

class _GroupPhotoHeaderState extends ConsumerState<GroupPhotoHeader> {
  bool _busy = false;
  Future<void> _change(ProfilePhotoKind kind) async {
    if (_busy) return;
    final actions = ref.read(groupPhotoActionsProvider);
    late final GroupPhotoScope scope;
    try {
      scope = actions.capture(widget.group.id);
    } catch (error) {
      if (mounted) showCircleMessage(context, error.toString());
      return;
    }
    final present =
        (kind == ProfilePhotoKind.avatar
            ? widget.group.avatarVersion
            : widget.group.coverVersion) !=
        null;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(present ? 'Replace photo' : 'Choose a photo'),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
            if (present)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null || widget.group.id != scope.group) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(groupPhotoActionsProvider)
          .change(scope, kind, remove: action == 'remove');
    } catch (error) {
      if (mounted) showCircleMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(circleWorkspaceProvider.notifier).refresh();
      if (!mounted) return;
      final group = ref
          .read(circleWorkspaceProvider)
          .value
          ?.group(widget.group.id);
      for (final kind in ProfilePhotoKind.values) {
        final version = kind == ProfilePhotoKind.avatar
            ? group?.avatarVersion
            : group?.coverVersion;
        if (version != null) {
          ref.invalidate(
            groupPhotoBytesProvider((
              group: widget.group.id,
              kind: kind,
              version: version,
            )),
          );
        }
      }
    } catch (error) {
      if (mounted) showCircleMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final viewer = ref.watch(circleViewerProvider);
    final admin = group.roleOf(viewer)?.isAdmin == true;
    final version = group.coverVersion;
    final fallback = DecoratedBox(
      decoration: CircleDepth.profilePanel(context),
      child: Center(
        child: Icon(
          circleTypeIcon(group.type),
          size: Space.large,
          color: CircleAccents.of(context).caption,
        ),
      ),
    );
    Widget cover = fallback;
    if (version != null) {
      final query = (
        group: group.id,
        kind: ProfilePhotoKind.cover,
        version: version,
      );
      cover = ref
          .watch(groupPhotoBytesProvider(query))
          .when(
            data: (bytes) => ClipRRect(
              borderRadius: BorderRadius.circular(CircleRadius.card),
              child: Image.memory(
                bytes,
                key: ValueKey('group-cover-${group.id}'),
                errorBuilder: (_, _, _) => fallback,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                semanticLabel: 'Banner for ${group.name}',
              ),
            ),
            loading: () => fallback,
            error: (_, _) => Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                Center(
                  child: IconButton.filledTonal(
                    tooltip: 'Retry group banner',
                    onPressed: () =>
                        ref.invalidate(groupPhotoBytesProvider(query)),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          );
    }
    // The banner steps aside at large text sizes so the tabs stay within
    // reach; the picture and name remain.
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >
        CircleLayout.largeTextThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!largeText)
          AspectRatio(
            aspectRatio: CircleProfileLayout.coverAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Refresh group photos',
                          onPressed: _busy ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        // Admins change the banner from a camera on it.
                        if (admin) ...[
                          const SizedBox(width: Space.sm),
                          IconButton.filledTonal(
                            tooltip: group.coverVersion == null
                                ? 'Add banner'
                                : 'Change banner',
                            onPressed: _busy
                                ? null
                                : () => _change(ProfilePhotoKind.cover),
                            icon: const Icon(Icons.photo_camera_outlined),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.md),
        Center(
          child: SizedBox.square(
            dimension: CircleAvatarSize.hero.diameter + Space.lg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GroupAvatar(
                  groupId: group.id,
                  type: group.type,
                  size: CircleAvatarSize.hero,
                ),
                // Like the profile photo: a small camera for admins.
                if (admin)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: IconButton.filledTonal(
                      tooltip: group.avatarVersion == null
                          ? 'Add group picture'
                          : 'Change group picture',
                      onPressed: _busy
                          ? null
                          : () => _change(ProfilePhotoKind.avatar),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Semantics(
          header: true,
          child: Text(
            group.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        // With the banner hidden at large text, its controls move here.
        if (largeText)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.sm,
            children: [
              IconButton.filledTonal(
                tooltip: 'Refresh group photos',
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
              if (admin)
                IconButton.filledTonal(
                  tooltip: group.coverVersion == null
                      ? 'Add banner'
                      : 'Change banner',
                  onPressed: _busy
                      ? null
                      : () => _change(ProfilePhotoKind.cover),
                  icon: const Icon(Icons.panorama_outlined),
                ),
            ],
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
