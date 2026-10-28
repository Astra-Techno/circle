import 'package:flutter/material.dart';
import 'circle_failure.dart';
import 'design.dart';

/// An editorial page opening: a headline and one quiet line, with an
/// optional artwork (an avatar or photo) beside it. No panel, no motif
/// bubble, so the page's real content starts higher. No fixed height:
/// names and larger text can always wrap.
class CircleIntroPanel extends StatelessWidget {
  const CircleIntroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.artwork,
    this.icon = Icons.auto_awesome_outlined,
  });
  final String title, subtitle;
  final Widget? artwork;

  /// Kept for callers; the editorial opening no longer draws a motif.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >
        CircleLayout.largeTextThreshold;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: largeText
                ? theme.textTheme.titleLarge
                : theme.textTheme.headlineMedium,
          ),
        ),
        if (!largeText) ...[
          const SizedBox(height: Space.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: artwork == null
          ? text
          : Row(
              children: [
                artwork!,
                const SizedBox(width: Space.md),
                Expanded(child: text),
              ],
            ),
    );
  }
}

class CircleCover extends StatelessWidget {
  const CircleCover({
    super.key,
    required this.title,
    required this.icon,
    this.compact = false,
  });
  final String title;
  final IconData icon;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      image: true,
      label: 'Original fictional illustration: $title',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? Space.xl : Space.hero),
          decoration: CircleDepth.panel(
            context,
            radius: compact ? CircleRadius.inner : CircleRadius.sheet,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: compact ? Space.large : Space.large * 4 / 3,
                color: CircleAccents.of(context).caption,
              ),
              const SizedBox(height: Space.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fictional illustrated "photo": a flat recessed tile with an icon and
/// a short label, in the same style as [CircleCover]. It fills whatever
/// size its parent gives it; [more] shows a "+3 more" pill on top.
class CircleSceneTile extends StatelessWidget {
  const CircleSceneTile({
    super.key,
    required this.label,
    required this.icon,
    required this.semanticsLabel,
    this.onTap,
    this.onLongPress,
    this.more,
    this.large = false,
    this.asset,
  });
  final String label, semanticsLabel;
  final IconData icon;
  final VoidCallback? onTap;

  /// A bundled fictional photo shown instead of the icon and label.
  final String? asset;

  /// More choices for this photo (every long-press also has a visible
  /// button elsewhere, README §4.0).
  final VoidCallback? onLongPress;
  final String? more;

  /// Bigger icon and text, for the full-screen viewer.
  final bool large;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(
      large ? CircleRadius.card : CircleRadius.tile,
    );
    return Semantics(
      container: true,
      image: true,
      button: onTap != null,
      label: semanticsLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: CircleDepth.panel(
          context,
          radius: large ? CircleRadius.card : CircleRadius.tile,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (asset != null) ...[
                  Image.asset(asset!, fit: BoxFit.cover),
                  if (more != null)
                    Align(
                      alignment: AlignmentDirectional.bottomEnd,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.sm),
                        child: CirclePill(more!, tone: CircleTone.strong),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    // Decorative: scales down instead of overflowing small tiles.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: large ? Space.large * 2 : Space.large,
                            color: CircleAccents.of(context).caption,
                          ),
                          const SizedBox(height: Space.sm),
                          // On the last tile, "+N more" takes the label's place
                          // so the two never overlap.
                          if (more != null)
                            CirclePill(more!, tone: CircleTone.strong)
                          else
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: (large ? text.titleLarge : text.titleSmall)
                                  ?.copyWith(color: colors.onSurface),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The short intro at the top of a page. The app bar already names the
/// page, so this stays calm: one warm line and an optional explanation.
class CircleHeading extends StatelessWidget {
  const CircleHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });
  final String title, subtitle;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: CircleAccents.of(context).caption,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Space.xs),
          ],
          Text(
            // Intros are one calm line; manual breaks were for big headlines.
            title.replaceAll('\n', ' '),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section within a page ("Invitations for you", "Admins").
class CircleSectionTitle extends StatelessWidget {
  const CircleSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.section, bottom: Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// One list row in the design's style: content on white, separated from
/// the next row by a 1px hairline divider (no card per row).
class CircleRow extends StatelessWidget {
  const CircleRow({super.key, required this.child, this.divider = true});
  final Widget child;
  final bool divider;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [child, if (divider) const Divider(height: 1)],
  );
}

/// Colour families from the design. Every pill, avatar and accent picks one
/// of these instead of choosing colours itself.
enum CircleTone {
  neutral,
  strong,
  calm,
  heart,
  sage,

  /// White (dark: raised) circle on a tinted panel.
  surface,
}

({Color fill, Color text, Color dot}) circleToneColors(
  BuildContext context,
  CircleTone tone,
) {
  final colors = Theme.of(context).colorScheme;
  final accents = CircleAccents.of(context);
  return switch (tone) {
    CircleTone.neutral => (
      fill: accents.recessed,
      text: colors.onSurfaceVariant,
      dot: colors.outline,
    ),
    CircleTone.strong => (
      fill: colors.primary,
      text: colors.onPrimary,
      dot: colors.primary,
    ),
    CircleTone.calm => (
      fill: accents.calmContainer,
      text: accents.calmText,
      dot: accents.calm,
    ),
    CircleTone.heart => (
      fill: accents.heartContainer,
      text: accents.heartText,
      dot: accents.heart,
    ),
    CircleTone.sage => (
      fill: accents.sageContainer,
      text: accents.sageText,
      dot: accents.sage,
    ),
    CircleTone.surface => (
      fill: colors.surfaceContainerLowest,
      text: colors.onSurface,
      dot: colors.outline,
    ),
  };
}

/// A small rounded label: audiences, roles, statuses.
class CirclePill extends StatelessWidget {
  const CirclePill(
    this.label, {
    super.key,
    this.tone = CircleTone.neutral,
    this.icon,
    this.semanticsLabel,
  });
  final String label;
  final CircleTone tone;
  final IconData? icon;

  /// Spoken instead of [label], e.g. "Shared with Family only".
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) {
    final palette = circleToneColors(context, tone);
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(CircleRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Space.lg, color: palette.text),
            const SizedBox(width: Space.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: palette.text),
            ),
          ),
        ],
      ),
    );
    return semanticsLabel == null
        ? pill
        : Semantics(label: semanticsLabel, excludeSemantics: true, child: pill);
  }
}

/// Avatar sizes used across the app.
enum CircleAvatarSize {
  small(32),
  medium(40),
  large(56),
  hero(72),
  profile(96);

  const CircleAvatarSize(this.diameter);
  final double diameter;
}

/// A person or group avatar: an initial or icon on a tone fill. Decorative
/// to screen readers; the name next to it is what gets read (include
/// "active now" there when [active] is set).
class CircleInitialAvatar extends StatelessWidget {
  const CircleInitialAvatar({
    super.key,
    this.name,
    this.icon,
    this.tone = CircleTone.calm,
    this.size = CircleAvatarSize.medium,
    this.active = false,
    this.image,
  }) : assert(name != null || icon != null);
  final ImageProvider<Object>? image;
  final String? name;
  final IconData? icon;
  final CircleTone tone;
  final CircleAvatarSize size;

  /// Shows the "Active now" dot (1:1 contexts only).
  final bool active;
  @override
  Widget build(BuildContext context) {
    final palette = circleToneColors(context, tone);
    final diameter = size.diameter;
    final avatar = DecoratedBox(
      decoration: BoxDecoration(color: palette.fill, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: diameter / 2,
        backgroundColor: Colors.transparent,
        foregroundImage: image,
        onForegroundImageError: image == null ? null : (_, _) {},
        foregroundColor: palette.text,
        child: icon != null
            ? Icon(icon, size: diameter * 0.5, color: palette.text)
            : Text(
                name!.trim().isEmpty ? '?' : name!.trim().characters.first,
                style:
                    (diameter >= 56
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(color: palette.text),
              ),
      ),
    );
    if (!active) return ExcludeSemantics(child: avatar);
    final dot = diameter * 0.3;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                key: const ValueKey('circle-active-dot'),
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: CircleAccents.of(context).activeDot,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: diameter * 0.05,
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

class CircleEmpty extends StatelessWidget {
  const CircleEmpty({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.blur_circular,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: Space.lg),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.sm),
          Text(message),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.lg),
              child: action,
            ),
        ],
      ),
    ),
  );
}

/// A quiet one-line notice with an info icon (session ended, what the
/// server can't do yet, how requests work).
class CircleNote extends StatelessWidget {
  const CircleNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: Space.lg,
          color: CircleAccents.of(context).caption,
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Formerly one small label per screen for mock behaviour. The owner removed
/// on-screen preview labels (28 Oct 2026); callers keep their text so the
/// behaviour stays documented in code, but nothing is drawn. Real notices
/// use [CircleNote].
class PreviewLabel extends StatelessWidget {
  const PreviewLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A small text badge, e.g. a role. [strong] marks the most important one.
class CircleBadge extends StatelessWidget {
  const CircleBadge(this.label, {super.key, this.strong = false});
  final String label;
  final bool strong;
  @override
  Widget build(BuildContext context) =>
      CirclePill(label, tone: strong ? CircleTone.strong : CircleTone.calm);
}

void _show(ScaffoldMessengerState? messenger, String text, VoidCallback? undo) {
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
}

/// Shows a short snackbar; [onUndo] adds an Undo action.
void showCircleMessage(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
}) => _show(ScaffoldMessenger.maybeOf(context), message, onUndo);

/// Awaits [action]; on failure shows a calm message instead of throwing.
/// Returns null when the action failed.
Future<T?> runCalmly<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
  VoidCallback? onUndo,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final result = await action();
    if (success != null) _show(messenger, success, onUndo);
    return result;
  } on CircleFailure catch (failure) {
    _show(messenger, failure.message, null);
  } catch (_) {
    _show(messenger, 'That didn’t work. Please try again.', null);
  }
  return null;
}

/// Confirmation for destructive or cascading actions only.
Future<bool> confirmCircleAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  List<String> details = const [],

  /// The button that backs out, when "Cancel" would be ambiguous (for
  /// example "Keep event" next to "Cancel event").
  String dismiss = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text('• $detail'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(dismiss),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// An Undo callback that runs [action] calmly if [context] is still mounted.
VoidCallback undoWith(BuildContext context, Future<void> Function() action) =>
    () {
      if (context.mounted) runCalmly(context, action);
    };

/// Undo for an action that removes the widget offering it (a deleted card
/// or comment). The messenger is captured now, so a failed undo still gets
/// a calm message after that widget is gone.
VoidCallback undoDetached(
  BuildContext context,
  Future<void> Function() action,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return () async {
    try {
      await action();
    } on CircleFailure catch (failure) {
      _show(messenger, failure.message, null);
    } catch (_) {
      _show(messenger, 'That didn’t work. Please try again.', null);
    }
  };
}

/// The honest state for something the connected server doesn't offer yet.
/// One calm card, no buttons that lead nowhere.
class CircleNotOnServer extends StatelessWidget {
  const CircleNotOnServer({super.key, required this.message});

  /// e.g. "Events aren’t on the server yet."
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: Space.lg),
            Text(
              'Not on the server yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.sm),
            Text('$message It’s coming in a later milestone.'),
          ],
        ),
      ),
    ),
  );
}

/// What a [CircleSkeleton] stands in for.
enum CircleSkeletonShape {
  /// Rows with an avatar and two lines (people, chats, activity, results).
  rows,

  /// Tall cards (Memories, events, settings sections).
  cards,

  /// A grid of square tiles (albums, photos).
  grid,
}

/// One quiet placeholder block: a flat recessed shape with no text.
class CircleSkeletonBlock extends StatelessWidget {
  const CircleSkeletonBlock({
    super.key,
    this.width,
    this.height = Space.md,
    this.radius = CircleRadius.small,
  });
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: CircleAccents.of(context).recessed,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// README §4.4: lists load with skeletons, not spinners. The shapes are
/// static on purpose (calm, nothing pulses, so reduced-motion settings and
/// screen readers are respected); screen readers hear [label] once.
class CircleSkeleton extends StatelessWidget {
  const CircleSkeleton({
    super.key,
    this.shape = CircleSkeletonShape.rows,
    this.count = 4,
    this.label = 'Loading',
  });
  final CircleSkeletonShape shape;
  final int count;

  /// Spoken once, e.g. "Loading activity".
  final String label;

  @override
  Widget build(BuildContext context) {
    final children = switch (shape) {
      CircleSkeletonShape.rows => [
        for (var i = 0; i < count; i++) _row(context, i),
      ],
      CircleSkeletonShape.cards => [
        for (var i = 0; i < count; i++) _card(context, i),
      ],
      CircleSkeletonShape.grid => [_grid(context)],
    };
    return Semantics(
      key: const ValueKey('circle-skeleton'),
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// Line widths vary a little so the shapes read as text, not bars.
  static double _fraction(int index) =>
      const [0.62, 0.48, 0.7, 0.54][index % 4];

  Widget _lines(int index) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleSkeletonBlock(width: constraints.maxWidth * _fraction(index)),
        const SizedBox(height: Space.sm),
        CircleSkeletonBlock(
          width: constraints.maxWidth * _fraction(index + 1) * 0.8,
          height: Space.sm + Space.xs,
        ),
      ],
    ),
  );

  Widget _row(BuildContext context, int index) => CircleRow(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          CircleSkeletonBlock(
            width: CircleAvatarSize.medium.diameter,
            height: CircleAvatarSize.medium.diameter,
            radius: CircleRadius.pill,
          ),
          const SizedBox(width: Space.md),
          Expanded(child: _lines(index)),
        ],
      ),
    ),
  );

  Widget _card(BuildContext context, int index) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleSkeletonBlock(
                width: CircleAvatarSize.medium.diameter,
                height: CircleAvatarSize.medium.diameter,
                radius: CircleRadius.pill,
              ),
              const SizedBox(width: Space.md),
              Expanded(child: _lines(index)),
            ],
          ),
          const SizedBox(height: Space.lg),
          const CircleSkeletonBlock(
            height: Space.large * 2,
            radius: CircleRadius.tile,
          ),
        ],
      ),
    ),
  );

  Widget _grid(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520 ? 4 : 3;
      final size = (constraints.maxWidth - Space.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (var i = 0; i < count; i++)
            CircleSkeletonBlock(
              width: size,
              height: size,
              radius: CircleRadius.tile,
            ),
        ],
      );
    },
  );
}

/// A whole page that is still loading: [CircleSkeleton] in the reading
/// column with the standard page padding.
class CircleSkeletonPage extends StatelessWidget {
  const CircleSkeletonPage({
    super.key,
    this.shape = CircleSkeletonShape.rows,
    this.count = 4,
    this.label = 'Loading',
  });
  final CircleSkeletonShape shape;
  final int count;
  final String label;
  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: CircleInsets.form,
      children: [CircleSkeleton(shape: shape, count: count, label: label)],
    ),
  );
}
