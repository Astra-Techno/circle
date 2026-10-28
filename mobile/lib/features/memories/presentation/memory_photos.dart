import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/circle_signed_image.dart';
import '../../../core/design.dart';
import '../application/media_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';

/// The icon drawn for each fictional scene.
IconData memorySceneIcon(MemoryScene? scene) => switch (scene) {
  null => Icons.photo_outlined,
  MemoryScene.sundayLunch => Icons.restaurant_outlined,
  MemoryScene.hillTrip => Icons.landscape_outlined,
  MemoryScene.graduationDay => Icons.school_outlined,
  MemoryScene.birthdayCake => Icons.cake_outlined,
  MemoryScene.beachWalk => Icons.beach_access_outlined,
  MemoryScene.officeParty => Icons.celebration_outlined,
  MemoryScene.cricketMatch => Icons.sports_cricket_outlined,
  MemoryScene.weddingStage => Icons.local_florist_outlined,
  MemoryScene.templeFestival => Icons.temple_hindu_outlined,
  MemoryScene.oldClassroom => Icons.history_edu_outlined,
};

/// Fictional preview scenes that have a bundled photo (the owner's
/// supplied welcome images); the rest stay illustrated.
String? memoryScenePhoto(MemoryScene? scene) => switch (scene) {
  MemoryScene.sundayLunch => 'assets/welcome/sunday-supper.jpg',
  MemoryScene.hillTrip => 'assets/welcome/friends.jpg',
  _ => null,
};

/// Full-screen viewer for a Memory's photos, starting at [index].
String photoViewerLocation(String memoryId, int index) => Uri(
  path: '/home/memory/$memoryId/photos',
  queryParameters: {'index': '$index'},
).toString();

/// The Memory card's photo layout (see [PhotoGrid]); each photo opens the
/// full-screen viewer.
class MemoryPhotoGrid extends StatelessWidget {
  const MemoryPhotoGrid({super.key, required this.memory});
  final CircleMemory memory;
  @override
  Widget build(BuildContext context) => PhotoGrid(
    photos: memory.photos,
    onOpen: (index) => context.push(photoViewerLocation(memory.id, index)),
  );
}

/// Photos as one full-width tile, two side by side, or one large and two
/// small with "+N more" on the last. Used by Memory cards and photo
/// messages in chat.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, required this.onOpen});
  final List<MemoryPhoto> photos;
  final void Function(int index) onOpen;
  @override
  Widget build(BuildContext context) {
    final count = photos.length;
    Widget tile(int index, {String? more}) {
      final photo = photos[index];
      return MemoryPhotoTile(
        photo: photo,
        semanticsLabel: [
          'Photo ${index + 1} of $count: ${photo.description}',
          ?more,
        ].join('. '),
        more: more,
        onTap: () => onOpen(index),
      );
    }

    const gap = SizedBox.square(dimension: Space.sm);
    return switch (count) {
      0 => const SizedBox.shrink(),
      1 => AspectRatio(aspectRatio: 16 / 10, child: tile(0)),
      2 => AspectRatio(
        aspectRatio: 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tile(0)),
            gap,
            Expanded(child: tile(1)),
          ],
        ),
      ),
      _ => AspectRatio(
        aspectRatio: 3 / 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: tile(0)),
            gap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(1)),
                  gap,
                  Expanded(
                    child: tile(
                      2,
                      more: count > 3 ? '+${count - 3} more' : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    };
  }
}

/// G3-style viewer for a Memory's photos (see [PhotoPager]).
class MemoryPhotoViewer extends StatelessWidget {
  const MemoryPhotoViewer({
    super.key,
    required this.memoryId,
    this.initialIndex = 0,
  });
  final String memoryId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final memory = workspace.memories
          .where((memory) => memory.id == memoryId)
          .firstOrNull;
      if (memory == null || memory.photos.isEmpty) {
        return const ReadingPane(
          child: Padding(
            padding: CircleInsets.form,
            child: CircleEmpty(
              title: 'Photos unavailable',
              message: 'These photos are not shared with your current groups.',
            ),
          ),
        );
      }
      return PhotoPager(photos: memory.photos, initialIndex: initialIndex);
    },
  );
}

/// Full-screen photos: swipe between them, or use the previous/next
/// buttons (no gesture-only navigation). Shows "n of N" and the caption.
/// [footer] adds actions for the photo on screen (e.g. Remove).
class PhotoPager extends StatefulWidget {
  const PhotoPager({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.footer,
  });
  final List<MemoryPhoto> photos;
  final int initialIndex;
  final Widget? Function(BuildContext context, MemoryPhoto photo)? footer;
  @override
  State<PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<PhotoPager> {
  late int _index = widget.initialIndex.clamp(
    0,
    widget.photos.isEmpty ? 0 : widget.photos.length - 1,
  );
  late final PageController _pages = PageController(initialPage: _index);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const ReadingPane(
        child: Padding(
          padding: CircleInsets.form,
          child: CircleEmpty(
            title: 'No photos here',
            message: 'There’s nothing left to show.',
          ),
        ),
      );
    }
    final index = _index.clamp(0, photos.length - 1);
    final photo = photos[index];
    final theme = Theme.of(context);
    final footer = widget.footer?.call(context, photo);
    return ReadingPane(
      child: Padding(
        padding: CircleInsets.form.copyWith(bottom: Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photos.any((photo) => !photo.uploaded))
              const PreviewLabel(
                'Fictional illustrations. Real photos come later.',
              ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: (page) => setState(() => _index = page),
                itemBuilder: (context, page) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: MemoryPhotoTile(
                    large: true,
                    photo: photos[page],
                    semanticsLabel:
                        'Photo ${page + 1} of ${photos.length}: '
                        '${photos[page].description}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous photo',
                  onPressed: index == 0 ? null : () => _goTo(index - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${index + 1} of ${photos.length}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next photo',
                  onPressed: index == photos.length - 1
                      ? null
                      : () => _goTo(index + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (photo.caption != null)
              Text(
                photo.caption!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// One photo: a fictional scene tile, or an uploaded photo loaded through
/// a short-lived signed link (thumb in cards, medium in the viewer, where
/// it can be zoomed).
class MemoryPhotoTile extends ConsumerWidget {
  const MemoryPhotoTile({
    super.key,
    required this.photo,
    required this.semanticsLabel,
    this.onTap,
    this.more,
    this.large = false,
  });
  final MemoryPhoto photo;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final String? more;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaId = photo.mediaId;
    if (mediaId == null) {
      return CircleSceneTile(
        label: photo.label,
        icon: memorySceneIcon(photo.scene),
        asset: memoryScenePhoto(photo.scene),
        semanticsLabel: semanticsLabel,
        more: more,
        onTap: onTap,
        large: large,
      );
    }
    final link = ref.watch(
      signedMediaUrlProvider((
        mediaId: mediaId,
        size: large ? MediaSize.medium : MediaSize.thumb,
      )),
    );
    Widget frame(Widget child) => CirclePhotoFrame(
      semanticsLabel: semanticsLabel,
      onTap: onTap,
      more: more,
      large: large,
      child: child,
    );
    return link.when(
      data: (url) {
        final image = CircleSignedImage(
          url: url,
          semanticsLabel: semanticsLabel,
          onTap: onTap,
          more: more,
          large: large,
          fit: large ? BoxFit.contain : BoxFit.cover,
        );
        return large ? InteractiveViewer(maxScale: 4, child: image) : image;
      },
      loading: () => frame(const CirclePhotoPlaceholder(loading: true)),
      error: (_, _) =>
          frame(const CirclePhotoPlaceholder(message: 'Photo unavailable')),
    );
  }
}

/// Opens the fictional scene picker and returns the chosen scenes, or null
/// when dismissed. At most [max] scenes (never more than 10 at once).
Future<List<MemoryScene>?> pickScenes(
  BuildContext context, {
  List<MemoryScene> initial = const [],
  int max = MemoryRules.maxPhotos,
  String action = 'Use',
}) => showModalBottomSheet<List<MemoryScene>>(
  context: context,
  // Above the shell's navigation bar, so nothing is hidden.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ScenePicker(
    initial: initial,
    max: max.clamp(0, MemoryRules.maxPhotos),
    action: action,
  ),
);

/// Multi-select of up to [max] fictional scenes. Labelled once as a preview.
class _ScenePicker extends StatefulWidget {
  const _ScenePicker({
    required this.initial,
    required this.max,
    required this.action,
  });
  final List<MemoryScene> initial;
  final int max;
  final String action;
  @override
  State<_ScenePicker> createState() => _ScenePickerState();
}

class _ScenePickerState extends State<_ScenePicker> {
  late final List<MemoryScene> _selected = [...widget.initial];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = _selected.length >= widget.max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.section,
            Space.section,
            Space.section,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Add photos', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: Space.sm),
              const PreviewLabel(
                'Preview: fictional illustrations — real uploads come later.',
              ),
              Text(
                '${_selected.length} of ${widget.max} chosen',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            children: [
              for (final scene in MemoryScene.values)
                CheckboxListTile(
                  value: _selected.contains(scene),
                  secondary: CircleInitialAvatar(
                    icon: memorySceneIcon(scene),
                    tone: CircleTone.neutral,
                  ),
                  title: Text(scene.label),
                  onChanged: !_selected.contains(scene) && full
                      ? null
                      : (checked) => setState(
                          () => checked == true
                              ? _selected.add(scene)
                              : _selected.remove(scene),
                        ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop([..._selected]),
            child: Text(
              _selected.isEmpty
                  ? 'Done'
                  : '${widget.action} ${_selected.length} '
                        '${_selected.length == 1 ? 'photo' : 'photos'}',
            ),
          ),
        ),
      ],
    );
  }
}
