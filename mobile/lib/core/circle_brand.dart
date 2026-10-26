import 'package:flutter/material.dart';

/// Owner-supplied identity. Keep the full original artwork, including its
/// lettering and tagline, without cropping, recolouring or recreating it.
abstract final class CircleIdentity {
  static const name = 'CIRCLE';
  static const tagline = 'My Circle. Billion Memories.';
  static const artwork = 'assets/brand/circle-brand.png';
  static const semantics = '$name. $tagline';
}

class CircleBrand extends StatelessWidget {
  const CircleBrand({super.key, bool compact = false})
    : _maxWidth = compact ? 240 : 480;
  const CircleBrand.access({super.key}) : _maxWidth = 128;
  const CircleBrand.home({super.key}) : _maxWidth = 160;
  final double _maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _maxWidth),
      child: Image.asset(
        CircleIdentity.artwork,
        fit: BoxFit.contain,
        semanticLabel: CircleIdentity.semantics,
      ),
    ),
  );
}
