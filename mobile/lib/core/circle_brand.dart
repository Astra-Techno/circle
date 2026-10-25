import 'package:flutter/material.dart';

/// Owner-supplied identity. Keep the full original artwork, including its
/// lettering and tagline, without cropping, recolouring or recreating it.
abstract final class CircleIdentity {
  static const name = 'CIRCLE';
  static const tagline = 'MY CIRCLE. BILLION MEMORIES.';
  static const artwork = 'assets/brand/circle-brand.png';
  static const semantics = '$name. $tagline';
}

class CircleBrand extends StatelessWidget {
  const CircleBrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 240 : 480),
      child: Image.asset(
        CircleIdentity.artwork,
        fit: BoxFit.contain,
        semanticLabel: CircleIdentity.semantics,
      ),
    ),
  );
}
