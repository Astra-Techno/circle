import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/album_providers.dart';

/// Where an album lives: inside its group's space.
String albumLocation(String groupId, String albumId) =>
    '/groups/g/$groupId/albums/$albumId';

String albumPhotoLocation(String groupId, String albumId, int index) => Uri(
  path: '${albumLocation(groupId, albumId)}/photos',
  queryParameters: {'index': '$index'},
).toString();

/// G1: a group's albums as a grid of covers, plus "New album".
class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key, required this.group});
  final CircleGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(groupAlbumsProvider(group.id));
    final albums = load.value?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreviewLabel(
          'Preview: albums use fictional illustrations. Nothing is uploaded.',
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => showNewAlbumSheet(context, group),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('New album'),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (load.isLoading && albums == null)
          const CircleSkeleton(
            shape: CircleSkeletonShape.grid,
            count: 3,
            label: 'Loading albums',
          )
        else if (albums == null)
          CircleEmpty(
            title: 'Albums unavailable',
            message:
                load.value?.unavailable ?? 'Albums couldn’t load. Try again.',
          )
        else if (albums.isEmpty)
          CircleEmpty(
            title: 'A home for your shared photos',
            message:
                'Start an album for ${group.name}. Only members of this exact group will see it.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              final width =
                  (constraints.maxWidth - Space.md * (columns - 1)) / columns;
              return Wrap(
                spacing: Space.md,
                runSpacing: Space.lg,
                children: [
                  for (final album in albums)
                    SizedBox(
                      width: width,
                      child: AlbumTile(album: album),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// One album in the grid: cover scene, title, count and era.
class AlbumTile extends StatelessWidget {
  const AlbumTile({super.key, required this.album});
  final Album album;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = album.cover;
    void open() => context.push(albumLocation(album.groupId, album.id));
    return Semantics(
      button: true,
      label:
          'Album ${album.title}, ${album.details}'
          '${album.isEventAlbum ? ', event album' : ''}',
      excludeSemantics: true,
      onTap: open,
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.tile),
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CircleSceneTile(
                label: cover?.photo.label ?? 'No photos yet',
                icon: cover == null
                    ? Icons.photo_library_outlined
                    : memorySceneIcon(cover.photo.scene),
                semanticsLabel: album.title,
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              album.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              album.details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (album.isEventAlbum)
              const Padding(
                padding: EdgeInsets.only(top: Space.xs),
                child: CirclePill('Event', icon: Icons.event_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

/// "New album": a name, an optional year or era, and photos (optional).
Future<void> showNewAlbumSheet(BuildContext context, CircleGroup group) =>
    showModalBottomSheet<void>(
      context: context,
      // Above the shell's navigation bar, so nothing is hidden.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AlbumFormSheet(group: group),
    );

/// Creates an album, or renames one when [album] is set.
class AlbumFormSheet extends ConsumerStatefulWidget {
  const AlbumFormSheet({super.key, required this.group, this.album});
  final CircleGroup group;
  final Album? album;
  @override
  ConsumerState<AlbumFormSheet> createState() => _AlbumFormSheetState();
}

class _AlbumFormSheetState extends ConsumerState<AlbumFormSheet> {
  late final _title = TextEditingController(text: widget.album?.title);
  late final _era = TextEditingController(text: widget.album?.era);
  final List<MemoryScene> _scenes = [];
  String? _titleError, _eraError;
  bool _busy = false;

  bool get _editing => widget.album != null;

  @override
  void dispose() {
    _title.dispose();
    _era.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickScenes(
      context,
      initial: _scenes,
      max: AlbumRules.maxPerAdd,
      action: 'Add',
    );
    if (picked != null && mounted) {
      setState(
        () => _scenes
          ..clear()
          ..addAll(picked),
      );
    }
  }

  Future<void> _save() async {
    final title = AlbumRules.checkTitle(_title.text);
    final era = AlbumRules.checkEra(_era.text);
    setState(() {
      _titleError = title.reason;
      _eraError = era.reason;
    });
    if (!title.allowed || !era.allowed) return;
    setState(() => _busy = true);
    final controller = ref.read(albumControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final album = widget.album;
    final id = await runCalmly(context, () async {
      if (album != null) {
        await controller.rename(album.id, _title.text, era: _era.text);
        return album.id;
      }
      return controller.create(
        widget.group.id,
        _title.text,
        era: _era.text,
        scenes: _scenes,
      );
    }, success: _editing ? 'Album updated.' : 'Album created.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) return;
    navigator.pop();
    if (!_editing) router.push(albumLocation(widget.group.id, id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
                _editing ? 'Rename album' : 'New album in ${widget.group.name}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: AlbumRules.maxTitle,
              decoration: InputDecoration(
                labelText: 'Album name',
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _era,
              maxLength: AlbumRules.maxEra,
              decoration: InputDecoration(
                labelText: 'Year or era (optional)',
                hintText: 'e.g. 2005–2009',
                errorText: _eraError,
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: Space.sm),
              if (_scenes.isNotEmpty)
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final scene in _scenes)
                      InputChip(
                        avatar: Icon(memorySceneIcon(scene)),
                        label: Text(scene.label),
                        deleteButtonTooltipMessage:
                            'Remove ${scene.label} photo',
                        onDeleted: () => setState(() => _scenes.remove(scene)),
                      ),
                  ],
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _scenes.isEmpty
                        ? 'Choose photos (optional)'
                        : 'Change photos',
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Saving locally…'
                    : _editing
                    ? 'Save'
                    : 'Create album',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
