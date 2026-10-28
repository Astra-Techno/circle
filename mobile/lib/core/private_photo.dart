import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'circle_signed_image.dart';

/// Inline zoom keeps the viewer tied to live authorization and session state.
class PrivatePhoto extends StatefulWidget {
  const PrivatePhoto({super.key, required this.load, required this.label});
  final AsyncValue<Uint8List> load;
  final String label;
  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: _expanded ? 1 : 16 / 9,
    child: CirclePhotoFrame(
      semanticsLabel:
          '${widget.label}. Tap to ${_expanded ? 'collapse' : 'expand'}',
      onTap: widget.load.hasValue
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: widget.load.when(
        skipLoadingOnRefresh: false,
        loading: () => const CirclePhotoPlaceholder(loading: true),
        error: (_, _) =>
            const CirclePhotoPlaceholder(message: 'Photo unavailable'),
        data: (bytes) => InteractiveViewer(
          key: ValueKey(bytes),
          panEnabled: _expanded,
          scaleEnabled: _expanded,
          child: Image.memory(
            bytes,
            fit: _expanded ? BoxFit.contain : BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const CirclePhotoPlaceholder(message: 'Photo unavailable'),
          ),
        ),
      ),
    ),
  );
}
