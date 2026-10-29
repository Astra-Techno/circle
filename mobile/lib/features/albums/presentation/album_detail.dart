import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/album_providers.dart';
import 'albums_tab.dart';

enum _AlbumAction { rename, delete }

/// Album unavailable: deleted, or not shared with the viewer.
class _AlbumUnavailable extends StatelessWidget {
  const _AlbumUnavailable({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: CircleInsets.form,
      children: [
        CircleEmpty(
          title: 'This album is unavailable',
          message:
              message ??
              'It may have been deleted, or it belongs to a group you’re not in.',
        ),
      ],
    ),
  );
}

/// G2: an album's photos, "Add photos", and (for the creator or admins)
/// rename, delete and "Set as cover". Photos you added can be captioned
/// and removed with Undo (admins: any photo).
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({
    super.key,
    required this.groupId,
    required this.albumId,
  });
  final String groupId, albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(albumProvider(albumId));
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final album = load.value?.value;
    if (album == null || workspace == null || album.groupId != groupId) {
      if (load.isLoading && load.value == null) {
        return const CircleSkeletonPage(
          shape: CircleSkeletonShape.grid,
          count: 6,
          label: 'Loading album',
        );
      }
      return _AlbumUnavailable(message: load.value?.unavailable);
    }
    final group = workspace.group(album.groupId)!;
    final viewer = workspace.viewer;
    final admin = workspace.isAdminOf(group.id);
    final canEdit = AlbumRules.canEdit(
      album,
      viewer,
      isMember: true,
      isAdmin: admin,
    ).allowed;
    final room = AlbumRules.room(album);
    final theme = Theme.of(context);
    final controller = ref.read(albumControllerProvider.notifier);

    Future<void> add() async {
      final scenes = await pickScenes(context, max: room, action: 'Add');
      if (scenes == null || scenes.isEmpty || !context.mounted) return;
      await runCalmly(
        context,
        () => controller.addPhotos(album.id, scenes),
        success: scenes.length == 1 ? 'Photo added.' : 'Photos added.',
      );
    }

    Future<void> menu(_AlbumAction action) async {
      switch (action) {
        case _AlbumAction.rename:
          await showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => AlbumFormSheet(group: group, album: album),
          );
        case _AlbumAction.delete:
          final confirmed = await confirmCircleAction(
            context,
            title: 'Delete “${album.title}”?',
            message:
                'The album and its ${album.photos.length} photos disappear '
                'for everyone in ${group.name}. This can’t be undone.',
            confirm: 'Delete album',
            dismiss: 'Keep album',
          );
          if (!confirmed || !context.mounted) return;
          final router = GoRouter.of(context);
          final done = await runCalmly(context, () async {
            await controller.delete(album.id);
            return true;
          }, success: 'Album deleted.');
          if (done == true) {
            router.canPop() ? router.pop() : router.go('/groups/g/$groupId');
          }
      }
    }

    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        album.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        album.details,
                        'Started by ${workspace.nameOf(album.createdBy)}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (canEdit)
                PopupMenuButton<_AlbumAction>(
                  tooltip: 'Album options',
                  onSelected: menu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _AlbumAction.rename,
                      child: Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: _AlbumAction.delete,
                      child: Text('Delete album'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              CirclePill(
                group.name,
                icon: Icons.lock_outline,
                semanticsLabel: 'Shared with ${group.name} only',
              ),
              if (album.isEventAlbum)
                const CirclePill('Event album', icon: Icons.event_outlined),
            ],
          ),
          const SizedBox(height: Space.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: room == 0 ? null : add,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add photos'),
            ),
          ),
          if (room == 0)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'This album is full (${AlbumRules.maxPhotos} photos).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: Space.lg),
          if (album.photos.isEmpty)
            const CircleEmpty(
              title: 'No photos yet',
              message:
                  'Add the first few. Everyone in this group can add more.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 4 : 3;
                final size =
                    (constraints.maxWidth - Space.sm * (columns - 1)) / columns;
                return Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final (index, photo) in album.photos.indexed)
                      SizedBox.square(
                        dimension: size,
                        child: _PhotoTile(
                          album: album,
                          photo: photo,
                          index: index,
                          actions: _PhotoActions.of(
                            album,
                            photo,
                            viewer: viewer,
                            admin: admin,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

enum _PhotoAction { cover, caption, remove }

/// What the viewer may do with one album photo (see [AlbumRules]).
class _PhotoActions {
  const _PhotoActions({
    required this.cover,
    required this.caption,
    required this.remove,
  });

  factory _PhotoActions.of(
    Album album,
    AlbumPhoto photo, {
    required String viewer,
    required bool admin,
  }) => _PhotoActions(
    cover:
        !AlbumRules.isCover(album, photo.id) &&
        AlbumRules.canSetCover(
          album,
          viewer,
          isMember: true,
          isAdmin: admin,
        ).allowed,
    caption: AlbumRules.canEditCaption(
      photo,
      viewer,
      isMember: true,
      isAdmin: admin,
    ).allowed,
    remove: AlbumRules.canRemovePhoto(
      photo,
      viewer,
      isMember: true,
      isAdmin: admin,
    ).allowed,
  );

  /// "Set as cover" (creator/admins, not already the cover).
  final bool cover;

  /// Add or edit the caption (the photo's adder or admins).
  final bool caption;

  /// Remove from the album (the photo's adder or admins).
  final bool remove;

  bool get any => cover || caption || remove;
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.album,
    required this.photo,
    required this.index,
    required this.actions,
  });
  final Album album;
  final AlbumPhoto photo;
  final int index;
  final _PhotoActions actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = album.photos.length;
    final cover = AlbumRules.isCover(album, photo.id);
    void run(_PhotoAction action) =>
        runAlbumPhotoAction(context, ref, album, photo, action.name);
    final tile = CircleSceneTile(
      label: photo.photo.label,
      icon: memorySceneIcon(photo.photo.scene),
      semanticsLabel:
          'Photo ${index + 1} of $count: ${photo.photo.description}'
          '${cover ? '. Album cover' : ''}',
      onTap: () =>
          context.push(albumPhotoLocation(album.groupId, album.id, index)),
      // Long-press offers the same choices as the visible ⋮ button.
      onLongPress: actions.any
          ? () async {
              final action = await _showPhotoSheet(context, actions);
              if (action != null && context.mounted) run(action);
            }
          : null,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        tile,
        if (cover && count > 1)
          const PositionedDirectional(
            start: Space.xs,
            bottom: Space.xs,
            child: ExcludeSemantics(
              child: CirclePill(
                'Cover',
                icon: Icons.star_outline,
                tone: CircleTone.surface,
              ),
            ),
          ),
        if (actions.any)
          PositionedDirectional(
            top: 0,
            end: 0,
            child: PopupMenuButton<_PhotoAction>(
              tooltip: 'Options for photo ${index + 1}',
              icon: const Icon(Icons.more_vert),
              onSelected: run,
              itemBuilder: (_) => [
                for (final (action, label) in _photoMenu(actions, photo))
                  PopupMenuItem(value: action, child: Text(label)),
              ],
            ),
          ),
      ],
    );
  }
}

List<(_PhotoAction, String)> _photoMenu(
  _PhotoActions actions,
  AlbumPhoto photo,
) => [
  if (actions.cover) (_PhotoAction.cover, 'Set as cover'),
  if (actions.caption)
    (
      _PhotoAction.caption,
      photo.photo.caption == null ? 'Add caption' : 'Edit caption',
    ),
  if (actions.remove) (_PhotoAction.remove, 'Remove from album'),
];

Future<_PhotoAction?> _showPhotoSheet(
  BuildContext context,
  _PhotoActions actions,
) => showModalBottomSheet<_PhotoAction>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.cover)
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Set as cover'),
            onTap: () => Navigator.of(context).pop(_PhotoAction.cover),
          ),
        if (actions.caption)
          ListTile(
            leading: const Icon(Icons.short_text),
            title: const Text('Caption'),
            onTap: () => Navigator.of(context).pop(_PhotoAction.caption),
          ),
        if (actions.remove)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from album'),
            onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
          ),
      ],
    ),
  ),
);

/// Runs one photo action ("cover", "caption" or "remove") with the usual
/// calm feedback and Undo.
Future<void> runAlbumPhotoAction(
  BuildContext context,
  WidgetRef ref,
  Album album,
  AlbumPhoto photo,
  String action,
) async {
  final controller = ref.read(albumControllerProvider.notifier);
  switch (action) {
    case 'cover':
      final previous = album.cover?.id;
      await runCalmly(
        context,
        () => controller.setCover(album.id, photo.id),
        success: 'Album cover changed.',
        onUndo: previous == null
            ? null
            : undoDetached(
                context,
                () => controller.setCover(album.id, previous),
              ),
      );
    case 'caption':
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CaptionSheet(album: album, photo: photo),
      );
    case 'remove':
      await removeAlbumPhoto(context, ref, album, photo);
  }
}

/// Edit one photo's caption (up to 140 characters; empty removes it).
class _CaptionSheet extends ConsumerStatefulWidget {
  const _CaptionSheet({required this.album, required this.photo});
  final Album album;
  final AlbumPhoto photo;
  @override
  ConsumerState<_CaptionSheet> createState() => _CaptionSheetState();
}

class _CaptionSheetState extends ConsumerState<_CaptionSheet> {
  late final _text = TextEditingController(text: widget.photo.photo.caption);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final check = AlbumRules.checkCaption(_text.text);
    if (!check.allowed) {
      setState(() => _error = check.reason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final cleared = PhotoCaptionRules.clean(_text.text) == null;
    final done = await runCalmly(context, () async {
      await ref
          .read(albumControllerProvider.notifier)
          .setCaption(widget.album.id, widget.photo.id, _text.text);
      return true;
    }, success: cleared ? 'Caption removed.' : 'Caption saved.');
    if (!mounted) return;
    if (done == true) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.section,
        0,
        Space.section,
        Space.section,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Caption for ${widget.photo.photo.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Everyone in this group sees it. Leave it empty to remove it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: AlbumRules.maxCaption,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Caption (optional)',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving locally…' : 'Save caption'),
          ),
        ],
      ),
    ),
  );
}

/// Removes a photo with Undo (it goes back where it was).
Future<void> removeAlbumPhoto(
  BuildContext context,
  WidgetRef ref,
  Album album,
  AlbumPhoto photo,
) {
  final controller = ref.read(albumControllerProvider.notifier);
  return runCalmly(
    context,
    () => controller.removePhoto(album.id, photo.id),
    success: 'Photo removed.',
    onUndo: undoDetached(
      context,
      () => controller.restorePhoto(album.id, photo.id),
    ),
  );
}

/// G3 for albums: the shared viewer (swipe, "n of N", caption), plus
/// Remove for photos you may remove.
class AlbumPhotoViewer extends ConsumerWidget {
  const AlbumPhotoViewer({
    super.key,
    required this.groupId,
    required this.albumId,
    this.initialIndex = 0,
  });
  final String groupId, albumId;
  final int initialIndex;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(albumProvider(albumId));
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final album = load.value?.value;
    if (album == null || workspace == null || album.groupId != groupId) {
      if (load.isLoading && load.value == null) {
        return const CircleSkeletonPage(
          shape: CircleSkeletonShape.grid,
          count: 6,
          label: 'Loading album',
        );
      }
      return _AlbumUnavailable(message: load.value?.unavailable);
    }
    final admin = workspace.isAdminOf(groupId);
    final theme = Theme.of(context);
    return PhotoPager(
      key: ValueKey('album-${album.id}-${album.photos.length}'),
      photos: [for (final photo in album.photos) photo.photo],
      initialIndex: initialIndex,
      footer: (context, shown) {
        final photo = album.photos
            .where((item) => item.id == shown.id)
            .firstOrNull;
        if (photo == null) return null;
        final actions = _PhotoActions.of(
          album,
          photo,
          viewer: workspace.viewer,
          admin: admin,
        );
        final cover = AlbumRules.isCover(album, photo.id);
        if (!actions.any && !cover) return null;
        void run(_PhotoAction action) =>
            runAlbumPhotoAction(context, ref, album, photo, action.name);
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.xs,
          children: [
            if (cover)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: Text('Album cover', style: theme.textTheme.labelLarge),
              ),
            if (actions.cover)
              TextButton.icon(
                onPressed: () => run(_PhotoAction.cover),
                icon: const Icon(Icons.star_outline),
                label: const Text('Set as cover'),
              ),
            if (actions.caption)
              TextButton.icon(
                onPressed: () => run(_PhotoAction.caption),
                icon: const Icon(Icons.short_text),
                label: Text(
                  photo.photo.caption == null ? 'Add caption' : 'Edit caption',
                ),
              ),
            if (actions.remove)
              TextButton.icon(
                onPressed: () => run(_PhotoAction.remove),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove from album'),
              ),
          ],
        );
      },
    );
  }
}
