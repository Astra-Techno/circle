import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/viewport_load.dart';
import '../../../core/api/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/circle_signed_image.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../application/media_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'memory_reactions_sheet.dart';

/// The icon drawn for each fictional scene.
IconData memorySceneIcon(MemoryScene? scene) => switch (scene) {
  null => CircleIcons.photo,
  MemoryScene.sundayLunch => CircleIcons.utensils,
  MemoryScene.hillTrip => CircleIcons.mountain,
  MemoryScene.graduationDay => CircleIcons.graduationCap,
  MemoryScene.birthdayCake => CircleIcons.birthday,
  MemoryScene.beachWalk => CircleIcons.umbrella,
  MemoryScene.officeParty => CircleIcons.partyPopper,
  MemoryScene.cricketMatch => CircleIcons.trophy,
  MemoryScene.weddingStage => CircleIcons.flower2,
  MemoryScene.templeFestival => CircleIcons.landmark,
  MemoryScene.oldClassroom => CircleIcons.bookOpen,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final export = ref.watch(photoExportServiceProvider);
    final exportSupported = ref.watch(photoExportBridgeProvider).supported;
    return WorkspaceView(
      builder: (workspace) {
        final memory = workspace.memories
            .where((memory) => memory.id == memoryId)
            .firstOrNull;
        if (memory == null || memory.photos.isEmpty) {
          return const ReadingPane(
            child: Padding(
              padding: CircleInsets.form,
              child: CircleEmpty(
                icon: CircleIcons.lockKeyhole,
                title: 'Photos unavailable',
                message:
                    'These photos are not shared with your current groups.',
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
          onExport: exportSupported
              ? (photo, action) => export.export(
                  photo,
                  action,
                  asset: memoryScenePhoto(photo.scene),
                )
              : null,
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
          onComment: () =>
              context.push('/home/memory/${memory.id}?comment=true'),
        );
      },
    );
  }
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
    this.onExport,
  });
  final List<MemoryPhoto> photos;
  final int initialIndex;
  final Widget? Function(BuildContext context, MemoryPhoto photo)? footer;
  final String? caption, authorName;
  final DateTime? createdAt;
  final VoidCallback? onReact, onComment;
  final Future<bool> Function(MemoryPhoto photo, PhotoExportAction action)?
  onExport;
  @override
  State<PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<PhotoPager> {
  late int _index = widget.initialIndex.clamp(
    0,
    widget.photos.isEmpty ? 0 : widget.photos.length - 1,
  );
  late final PageController _pages = PageController(initialPage: _index);
  final _filmstrip = ScrollController();
  bool _zoomed = false, _chromeVisible = true;
  PhotoExportAction? _exportAction;
  int _zoomGeneration = 0;

  @override
  void dispose() {
    _pages.dispose();
    _filmstrip.dispose();
    super.dispose();
  }

  void _resetZoom() => setState(() {
    _zoomed = false;
    _zoomGeneration++;
  });

  void _pageChanged(int page) {
    setState(() {
      _index = page;
      _zoomed = false;
      _zoomGeneration++;
    });
    if (widget.photos.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_filmstrip.hasClients) return;
      final position = _filmstrip.position;
      final offset =
          (page * (CircleOverlay.filmstripThumbWidth + Space.sm) -
                  position.viewportDimension / 2 +
                  CircleOverlay.filmstripThumbWidth / 2)
              .clamp(0.0, position.maxScrollExtent);
      _filmstrip.animateTo(
        offset,
        duration: CircleMotion.micro,
        curve: CircleMotion.enterCurve,
      );
    });
  }

  void _goTo(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  bool _canExport(MemoryPhoto photo) =>
      widget.onExport != null &&
      (photo.mediaId != null || memoryScenePhoto(photo.scene) != null);

  Future<void> _export(MemoryPhoto photo, PhotoExportAction action) async {
    final export = widget.onExport;
    if (export == null || _exportAction != null) return;
    setState(() => _exportAction = action);
    final completed = await runCalmly(context, () => export(photo, action));
    if (!mounted) return;
    setState(() => _exportAction = null);
    if (completed == true && action == PhotoExportAction.download) {
      showCircleMessage(context, 'Photo saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const ReadingPane(
        child: Padding(
          padding: CircleInsets.form,
          child: CircleEmpty(
            icon: CircleIcons.photo,
            title: 'No photos here',
            message: 'There’s nothing left to show.',
          ),
        ),
      );
    }
    final index = _index.clamp(0, photos.length - 1);
    final photo = photos[index];
    final footer = widget.footer?.call(context, photo);
    final busy = _exportAction != null;
    return ColoredBox(
      color: CircleOverlay.background,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              // A zoomed photo owns horizontal drags until it is reset.
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: photos.length,
              onPageChanged: _pageChanged,
              itemBuilder: (context, page) => _ZoomableMemoryPhoto(
                key: ValueKey('photo-${photos[page].id}-$page'),
                photo: photos[page],
                semanticsLabel:
                    'Photo ${page + 1} of ${photos.length}: '
                    '${photos[page].description}',
                resetGeneration: _zoomGeneration,
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                onZoomChanged: (zoomed) {
                  if (page != _index || _zoomed == zoomed) return;
                  setState(() => _zoomed = zoomed);
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _PhotoChrome(
                visible: _chromeVisible,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: CircleOverlay.topScrim),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
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
                        if (_zoomed)
                          IconButton(
                            tooltip: 'Reset zoom',
                            onPressed: _resetZoom,
                            icon: const Icon(
                              CircleIcons.undo,
                              color: CircleOverlay.foreground,
                            ),
                          )
                        else
                          const SizedBox(width: CircleSizes.minTouchTarget),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _PhotoChrome(
                visible: _chromeVisible,
                child: Center(
                  child: IconButton(
                    tooltip: 'Previous photo',
                    onPressed: index > 0
                        ? () => _pages.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                        : null,
                    icon: const Icon(
                      CircleIcons.chevronLeft,
                      color: CircleOverlay.foreground,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _PhotoChrome(
                visible: _chromeVisible,
                child: Center(
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
              ),
            ),
            if (_zoomed && !_chromeVisible)
              Positioned(
                top: Space.sm,
                right: Space.sm,
                child: TextButton.icon(
                  onPressed: _resetZoom,
                  style: TextButton.styleFrom(
                    foregroundColor: CircleOverlay.foreground,
                    backgroundColor: CircleOverlay.chipBackground,
                  ),
                  icon: const Icon(CircleIcons.undo),
                  label: const Text('Reset zoom'),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PhotoChrome(
                visible: _chromeVisible,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: CircleOverlay.bottomScrim,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.sizeOf(context).height *
                          CircleOverlay.maxChromeFraction,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.md,
                              Space.lg,
                              Space.md,
                              Space.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.caption != null &&
                                    widget.caption!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Space.xs,
                                    ),
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
                                    ].join(' · '),
                                    style: CircleTextStyles.label(
                                      CircleOverlay.muted,
                                    ),
                                  ),
                                if (photo.caption != null &&
                                    photo.caption != widget.caption)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: Space.xs,
                                    ),
                                    child: Text(
                                      photo.caption!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: CircleTextStyles.label(
                                        CircleOverlay.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (photos.length > 1)
                            SizedBox(
                              height: CircleOverlay.filmstripHeight,
                              child: ListView.separated(
                                controller: _filmstrip,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.md,
                                  vertical: Space.xs,
                                ),
                                itemCount: photos.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: Space.sm),
                                itemBuilder: (context, page) => AnimatedContainer(
                                  key: ValueKey(
                                    'filmstrip-photo-${photos[page].id}',
                                  ),
                                  duration: CircleMotion.micro,
                                  width: CircleOverlay.filmstripThumbWidth,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: page == index
                                          ? CircleOverlay.foreground
                                          : Colors.transparent,
                                      width: CircleOverlay.filmstripBorderWidth,
                                    ),
                                  ),
                                  child: MemoryPhotoTile(
                                    photo: photos[page],
                                    semanticsLabel:
                                        'View photo ${page + 1} of ${photos.length}: '
                                        '${photos[page].description}',
                                    onTap: () => _goTo(page),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.onReact != null ||
                              widget.onComment != null ||
                              _canExport(photo)) ...[
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
                                      icon: CircleIcons.faceSlightlySmiling,
                                      label: 'React',
                                      onPressed: busy ? null : widget.onReact,
                                    ),
                                  if (widget.onComment != null)
                                    _PhotoAction(
                                      icon: CircleIcons.comment,
                                      label: 'Comment',
                                      onPressed: busy ? null : widget.onComment,
                                    ),
                                  if (_canExport(photo)) ...[
                                    _PhotoAction(
                                      icon: CircleIcons.share,
                                      label: 'Share',
                                      busy:
                                          _exportAction ==
                                          PhotoExportAction.share,
                                      onPressed: busy
                                          ? null
                                          : () => _export(
                                              photo,
                                              PhotoExportAction.share,
                                            ),
                                    ),
                                    _PhotoAction(
                                      icon: CircleIcons.download,
                                      label: 'Download',
                                      busy:
                                          _exportAction ==
                                          PhotoExportAction.download,
                                      onPressed: busy
                                          ? null
                                          : () => _export(
                                              photo,
                                              PhotoExportAction.download,
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          ?footer,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps hidden controls out of hit testing and the accessibility tree.
class _PhotoChrome extends StatelessWidget {
  const _PhotoChrome({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: CircleMotion.micro,
        curve: CircleMotion.enterCurve,
        child: child,
      ),
    ),
  );
}

/// One consistently zoomable photo, including bundled scenes and placeholders.
class _ZoomableMemoryPhoto extends StatefulWidget {
  const _ZoomableMemoryPhoto({
    super.key,
    required this.photo,
    required this.semanticsLabel,
    required this.resetGeneration,
    required this.onZoomChanged,
    required this.onTap,
  });
  final MemoryPhoto photo;
  final String semanticsLabel;
  final int resetGeneration;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<_ZoomableMemoryPhoto> createState() => _ZoomableMemoryPhotoState();
}

class _ZoomableMemoryPhotoState extends State<_ZoomableMemoryPhoto> {
  late final TransformationController _zoom = TransformationController()
    ..addListener(_notifyZoom);
  bool _zoomed = false;
  Timer? _tapTimer;
  int _pointers = 0;
  Offset? _pointerDown;
  bool _moved = false, _multiTouch = false, _suppressTap = false;

  void _notifyZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.001;
    if (_zoomed == zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _reset() {
    _zoom.value = Matrix4.identity();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _reset();
      return;
    }
    final bounds = context.size;
    if (bounds == null) return;
    final center = bounds.center(Offset.zero);
    _zoom.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(2, 2, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  void _cancelTap() {
    _tapTimer?.cancel();
    _tapTimer = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers == 1) {
      _pointerDown = event.position;
      _moved = false;
      _multiTouch = false;
      if (_tapTimer != null) {
        _cancelTap();
        _suppressTap = true;
      }
    } else {
      _multiTouch = true;
      _cancelTap();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _pointerDown;
    if (_pointers == 1 &&
        down != null &&
        (event.position - down).distance > kTouchSlop) {
      _moved = true;
      _cancelTap();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointers > 0) _pointers--;
    if (_pointers > 0) return;
    if (!_multiTouch && !_moved && !_suppressTap) {
      _tapTimer = Timer(kDoubleTapTimeout, () {
        _tapTimer = null;
        if (mounted) widget.onTap();
      });
    }
    _pointerDown = null;
    _multiTouch = false;
    _suppressTap = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers = 0;
    _pointerDown = null;
    _multiTouch = false;
    _suppressTap = false;
    _cancelTap();
  }

  @override
  void didUpdateWidget(_ZoomableMemoryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetGeneration != widget.resetGeneration) _reset();
  }

  @override
  void dispose() {
    _cancelTap();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerUp,
    onPointerCancel: _onPointerCancel,
    child: GestureDetector(
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _zoom,
        panEnabled: _zoomed,
        minScale: 1,
        maxScale: 4,
        child: MemoryPhotoTile(
          large: true,
          photo: widget.photo,
          semanticsLabel:
              '${widget.semanticsLabel}. Pinch to zoom; double-tap to zoom or reset; '
              'tap to show or hide controls.',
        ),
      ),
    ),
  );
}

/// Action button for the photo viewer (white on dark).
class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: CircleOverlay.foreground),
    icon: busy
        ? const SizedBox.square(
            dimension: CircleSizes.iconPhoto,
            child: CircularProgressIndicator(
              strokeWidth: CircleSizes.progressStroke,
              color: CircleOverlay.foreground,
            ),
          )
        : Icon(icon, size: CircleSizes.iconPhoto),
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
          color: large
              ? CircleOverlay.background
              : Theme.of(context).colorScheme.surfaceContainer,
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
            return image;
          },
          loading: () =>
              frame(CirclePhotoPlaceholder(loading: true, dark: large)),
          error: (_, _) => CirclePhotoFrame(
            semanticsLabel: '$semanticsLabel. Photo unavailable. Tap to retry.',
            onTap: retry,
            more: null,
            large: large,
            child: CirclePhotoPlaceholder(
              message: 'Retry photo',
              compact: !large,
              retryable: true,
              dark: large,
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
