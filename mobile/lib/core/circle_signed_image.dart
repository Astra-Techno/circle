import 'package:flutter/material.dart';
import 'api/signed_media_url.dart';
import 'circle_components.dart';
import 'design.dart';

/// A private photo from the CIRCLE media API, in the same flat tile as
/// [CircleSceneTile]. This is the **only** widget allowed to load images
/// over the network (see `test/design_system_guard_test.dart`), and it only
/// accepts a [SignedMediaUrl]: a short-lived link the media API issued for
/// the configured server. While loading, or when the link fails, it shows
/// a calm placeholder instead of a broken image.
class CircleSignedImage extends StatelessWidget {
  const CircleSignedImage({
    super.key,
    required this.url,
    required this.semanticsLabel,
    this.fit = BoxFit.cover,
    this.onTap,
    this.more,
    this.large = false,
  });
  final SignedMediaUrl url;
  final String semanticsLabel;
  final BoxFit fit;
  final VoidCallback? onTap;

  /// A "+3 more" pill over the photo.
  final String? more;

  /// Rounder corners, for the full-screen viewer.
  final bool large;

  @override
  Widget build(BuildContext context) => CirclePhotoFrame(
    semanticsLabel: semanticsLabel,
    onTap: onTap,
    more: more,
    large: large,
    child: Image.network(
      url.toString(),
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const CirclePhotoPlaceholder(loading: true),
      errorBuilder: (context, _, _) =>
          const CirclePhotoPlaceholder(message: 'Photo unavailable'),
    ),
  );
}

/// The tile around a real photo: tonal fill, rounded corners, tap target
/// and screen-reader label.
class CirclePhotoFrame extends StatelessWidget {
  const CirclePhotoFrame({
    super.key,
    required this.child,
    required this.semanticsLabel,
    this.onTap,
    this.more,
    this.large = false,
  });
  final Widget child;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final String? more;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      large ? CircleRadius.card : CircleRadius.tile,
    );
    return Semantics(
      container: true,
      image: true,
      button: onTap != null,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (more != null)
                Center(child: CirclePill(more!, tone: CircleTone.strong)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while a photo loads, or instead of one that can't be shown.
class CirclePhotoPlaceholder extends StatelessWidget {
  const CirclePhotoPlaceholder({super.key, this.loading = false, this.message});
  final bool loading;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: Space.xl,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.secondary,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 32,
                        color: colors.secondary,
                      ),
                      if (message != null) ...[
                        const SizedBox(height: Space.xs),
                        Text(
                          message!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
