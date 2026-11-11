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
  const GroupPhotoHeader({super.key, required this.group, this.titleAccessory});
  final Widget? titleAccessory;
  final CircleGroup group;
  @override
  ConsumerState<GroupPhotoHeader> createState() => _GroupPhotoHeaderState();
}

class _GroupPhotoHeaderState extends ConsumerState<GroupPhotoHeader> {
  bool _busy = false;
  Future<void> _change(
    ProfilePhotoKind kind, {
    GroupPhotoScope? expectedScope,
  }) async {
    if (_busy) return;
    final actions = ref.read(groupPhotoActionsProvider);
    late final GroupPhotoScope scope;
    try {
      scope = expectedScope ?? actions.capture(widget.group.id);
      actions.check(scope);
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
              leading: const Icon(CircleIcons.images),
              title: Text(present ? 'Replace photo' : 'Choose a photo'),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
            if (present)
              ListTile(
                leading: const Icon(CircleIcons.trash),
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

  Future<void> _editPhotos() async {
    if (_busy) return;
    late final GroupPhotoScope scope;
    try {
      scope = ref.read(groupPhotoActionsProvider).capture(widget.group.id);
    } catch (error) {
      if (mounted) showCircleMessage(context, error.toString());
      return;
    }
    final kind = await showModalBottomSheet<ProfilePhotoKind>(
      context: context,
      useSafeArea: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(CircleIcons.user),
            title: const Text('Circle photo'),
            onTap: () => Navigator.pop(context, ProfilePhotoKind.avatar),
          ),
          ListTile(
            leading: const Icon(CircleIcons.photo),
            title: const Text('Cover photo'),
            onTap: () => Navigator.pop(context, ProfilePhotoKind.cover),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || kind == null || widget.group.id != scope.group) return;
    await _change(kind, expectedScope: scope);
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
      final coverFailure = Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: CircleDepth.profilePanel(context)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cover photo couldn’t load',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Tooltip(
                  message: 'Retry group banner',
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(groupPhotoBytesProvider(query)),
                    icon: const Icon(CircleIcons.refreshCw),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      cover = ref
          .watch(groupPhotoBytesProvider(query))
          .when(
            skipLoadingOnRefresh: false,
            data: (bytes) => Image.memory(
              bytes,
              key: ValueKey('group-cover-${group.id}'),
              errorBuilder: (_, _, _) => coverFailure,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: 'Banner for ${group.name}',
            ),
            loading: () => fallback,
            error: (_, _) => coverFailure,
          );
    }
    // The banner steps aside at large text sizes so the tabs stay within
    // reach; the picture and name remain.
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >
        CircleLayout.largeTextThreshold;
    final avatar = SizedBox.square(
      dimension: CircleAvatarSize.hero.diameter + Space.lg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: GroupAvatar(
                groupId: group.id,
                type: group.type,
                size: CircleAvatarSize.hero,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!largeText)
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.hero),
                child: AspectRatio(
                  aspectRatio: CircleProfileLayout.coverAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover,
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(Space.sm),
                          child: admin
                              ? IconButton.filledTonal(
                                  tooltip: 'Edit Circle photos',
                                  onPressed: _busy ? null : _editPhotos,
                                  icon: const Icon(CircleIcons.camera),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                start: Space.contentInset,
                bottom: 0,
                child: avatar,
              ),
            ],
          )
        else
          Padding(
            padding: CircleInsets.content,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: avatar,
            ),
          ),
        const SizedBox(height: Space.sm),
        Semantics(
          header: true,
          child: Padding(
            padding: CircleInsets.content,
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                if (widget.titleAccessory != null) widget.titleAccessory!,
              ],
            ),
          ),
        ),
        if (largeText && admin)
          Padding(
            padding: CircleInsets.content,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton.filledTonal(
                tooltip: 'Edit Circle photos',
                onPressed: _busy ? null : _editPhotos,
                icon: const Icon(CircleIcons.camera),
              ),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
