import 'package:flutter/material.dart';
import '../../../core/viewport_load.dart';
import '../../../core/api/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/circle_signed_image.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import '../application/media_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'memory_reactions_sheet.dart';

/// The icon drawn for each fictional scene.
IconData memorySceneIcon(MemoryScene? scene) => switch (scene) {
  null => LucideIcons.image,
  MemoryScene.sundayLunch => LucideIcons.utensils,
  MemoryScene.hillTrip => LucideIcons.mountain,
  MemoryScene.graduationDay => LucideIcons.graduation_cap,
  MemoryScene.birthdayCake => LucideIcons.cake,
  MemoryScene.beachWalk => LucideIcons.umbrella,
  MemoryScene.officeParty => LucideIcons.party_popper,
  MemoryScene.cricketMatch => LucideIcons.trophy,
  MemoryScene.weddingStage => LucideIcons.flower_2,
  MemoryScene.templeFestival => LucideIcons.landmark,
  MemoryScene.oldClassroom => LucideIcons.book_open,
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
  const MemoryPhotoGrid({super.key, required this.memory, this.mosaicAspect});
  final CircleMemory memory;
  final double? mosaicAspect;
  @override
  Widget build(BuildContext context) => PhotoGrid(
    photos: memory.photos,
    mosaicAspect: mosaicAspect ?? CircleMemoryLayout.collageAspect,
    singleAspect: memory.photos.isEmpty
        ? 1
        : CircleMemoryLayout.photoAspect(
            memory.photos.first.width,
            memory.photos.first.height,
          ),
    onOpen: (index) => context.push(photoViewerLocation(memory.id, index)),
  );
}

/// Photos as one full-width tile, two side by side, or one large and two
/// small with "+N more" on the last. Used by Memory cards and photo
/// messages in chat.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onOpen,
    this.mosaicAspect,
    this.singleAspect = 16 / 10,
  });
  final double singleAspect;
  final List<MemoryPhoto> photos;
  final double? mosaicAspect;
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

    const gap = SizedBox.square(dimension: Space.xs);
    return switch (count) {
      0 => const SizedBox.shrink(),
      1 => AspectRatio(aspectRatio: singleAspect, child: tile(0)),
      2 => AspectRatio(
        aspectRatio: 16 / 10,
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
        aspectRatio: mosaicAspect ?? 4 / 3,
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
                    child: tile(2, more: count > 3 ? '+${count - 3}' : null),
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
class MemoryPhotoViewer extends ConsumerWidget {
  const MemoryPhotoViewer({
    super.key,
    required this.memoryId,
    this.initialIndex = 0,
  });
  final String memoryId;
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final memory = workspace.memories
          .where((memory) => memory.id == memoryId)
          .firstOrNull;
      if (memory == null || memory.photos.isEmpty) {
        return const ReadingPane(
          child: Padding(
            padding: CircleInsets.form,
            child: CircleEmpty(
              icon: LucideIcons.lock_keyhole,
              title: 'Photos unavailable',
              message: 'These photos are not shared with your current groups.',
            ),
          ),
        );
      }
      return PhotoPager(
        photos: memory.photos,
        initialIndex: initialIndex,
        caption: memory.text,
        authorName: memory.author,
        createdAt: memory.createdAt,
        onReact: () async {
          final api = ref.read(apiClientProvider);
          final session = api?.sessionRevision;
          final repository = ref.read(circleRepositoryProvider);
          final emoji = await showReactionPicker(context, memory.reactions);
          if (!context.mounted ||
              !identical(ref.read(apiClientProvider), api) ||
              api?.sessionRevision != session ||
              !identical(ref.read(circleRepositoryProvider), repository)) {
            return;
          }
          if (emoji != null) {
            await runCalmly(
              context,
              () => ref
                  .read(circleWorkspaceProvider.notifier)
                  .react(memory.id, emoji),
            );
          }
        },
        onComment: () => context.push('/home/memory/${memory.id}?comment=true'),
      );
    },
  );
}

/// Full-screen immersive photo viewer with dark background, swipe
/// navigation, "n of N" counter, caption/author and action bar.
/// [footer] adds actions for the photo on screen (e.g. Remove).
class PhotoPager extends StatefulWidget {
  const PhotoPager({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.footer,
    this.caption,
    this.authorName,
    this.createdAt,
    this.onReact,
    this.onComment,
  });
  final List<MemoryPhoto> photos;
  final int initialIndex;
  final Widget? Function(BuildContext context, MemoryPhoto photo)? footer;
  final String? caption, authorName;
  final DateTime? createdAt;
  final VoidCallback? onReact, onComment;
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

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const ReadingPane(
        child: Padding(
          padding: CircleInsets.form,
          child: CircleEmpty(
            icon: LucideIcons.image,
            title: 'No photos here',
            message: 'There\u2019s nothing left to show.',
          ),
        ),
      );
    }
    final index = _index.clamp(0, photos.length - 1);
    final photo = photos[index];
    final footer = widget.footer?.call(context, photo);
    return ColoredBox(
      color: CircleOverlay.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: X close + "n of N" + more options.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: Space.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      CircleIcons.close,
                      color: CircleOverlay.foreground,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${index + 1} of ${photos.length}',
                        textAlign: TextAlign.center,
                        style: CircleTextStyles.cardTitle(
                          CircleOverlay.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: CircleSizes.minTouchTarget),
                ],
              ),
            ),
            // Photo with navigation.
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
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
                  Positioned(
                    left: 0,
                    child: IconButton(
                      tooltip: 'Previous photo',
                      onPressed: index > 0
                          ? () => _pages.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                          : null,
                      icon: const Icon(
                        LucideIcons.chevron_left,
                        color: CircleOverlay.foreground,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      tooltip: 'Next photo',
                      onPressed: index < photos.length - 1
                          ? () => _pages.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                          : null,
                      icon: const Icon(
                        CircleIcons.chevronRight,
                        color: CircleOverlay.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Caption + author.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                Space.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.caption != null && widget.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xs),
                      child: Text(
                        widget.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CircleTextStyles.bodyMedium(
                          CircleOverlay.foreground,
                        ),
                      ),
                    ),
                  if (widget.authorName != null)
                    Text(
                      [
                        widget.authorName!,
                        if (widget.createdAt != null)
                          circleTimeAgo(widget.createdAt!),
                      ].join(' \u00b7 '),
                      style: CircleTextStyles.label(CircleOverlay.muted),
                    ),
                  if (photo.caption != null && photo.caption != widget.caption)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(
                        photo.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CircleTextStyles.label(CircleOverlay.muted),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.onReact != null || widget.onComment != null) ...[
              Divider(height: 1, color: CircleOverlay.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: Space.md,
                  children: [
                    if (widget.onReact != null)
                      _PhotoAction(
                        icon: LucideIcons.face_slightly_smiling,
                        label: 'React',
                        onPressed: widget.onReact!,
                      ),
                    if (widget.onComment != null)
                      _PhotoAction(
                        icon: LucideIcons.message_square,
                        label: 'Comment',
                        onPressed: widget.onComment!,
                      ),
                  ],
                ),
              ),
            ],
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Action button for the photo viewer (white on dark).
class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: CircleOverlay.foreground),
    icon: Icon(icon, size: CircleSizes.iconPhoto),
    label: Text(label),
  );
}

/// One photo: a fictional scene tile, or an uploaded photo loaded through
/// a short-lived signed link selected for the physical display area.
/// Zoom viewers request the full rendition.
class MemoryPhotoTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Widget load(BuildContext _) => _LoadedMemoryPhotoTile(
      photo: photo,
      semanticsLabel: semanticsLabel,
      onTap: onTap,
      more: more,
      large: large,
    );
    if (photo.mediaId == null) return load(context);
    return CircleViewportLoad(
      key: ValueKey(photo.mediaId),
      builder: load,
      placeholder: CirclePhotoFrame(
        semanticsLabel: semanticsLabel,
        onTap: onTap,
        more: more,
        large: large,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}

class _LoadedMemoryPhotoTile extends ConsumerWidget {
  const _LoadedMemoryPhotoTile({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixels =
            constraints.biggest.longestSide *
            MediaQuery.devicePixelRatioOf(context);
        final size = large
            ? MediaSize.full
            : pixels > CirclePhotoMetrics.thumbnailPixels
            ? MediaSize.medium
            : MediaSize.thumb;
        final request = (mediaId: mediaId, size: size);
        void retry() {
          ref.read(mediaRepositoryProvider)?.forget(mediaId, request.size);
          ref.invalidate(signedMediaUrlProvider(request));
        }

        final link = ref.watch(
          signedMediaUrlProvider((mediaId: mediaId, size: size)),
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
              cacheWidth: large || !pixels.isFinite
                  ? null
                  : CirclePhotoMetrics.previewDecodeWidth(pixels),
              onRetry: retry,
              semanticsLabel: semanticsLabel,
              onTap: onTap,
              more: more,
              large: large,
              fit: large ? BoxFit.contain : BoxFit.cover,
            );
            return large ? InteractiveViewer(maxScale: 4, child: image) : image;
          },
          loading: () => frame(const CirclePhotoPlaceholder(loading: true)),
          error: (_, _) => CirclePhotoFrame(
            semanticsLabel: '$semanticsLabel. Photo unavailable. Tap to retry.',
            onTap: retry,
            more: null,
            large: large,
            child: CirclePhotoPlaceholder(
              message: 'Retry photo',
              compact: !large,
              retryable: true,
            ),
          ),
        );
      },
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
