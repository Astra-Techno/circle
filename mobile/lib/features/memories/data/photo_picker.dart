import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/circle_failure.dart';
import '../domain/photo_upload.dart';

/// Opens the device's photo library. Only called when someone taps
/// "Add photos" (README §4.0: permissions in context, never on launch).
abstract interface class PhotoPicker {
  /// Up to [max] photos, or an empty list when the person cancels.
  Future<List<PickedPhoto>> pick({required int max});
}

/// The system photo picker. Photos are downsized on the device to at most
/// 2048 px on the long edge at about 80 % JPEG quality before upload
/// (ADR 0007), which also converts HEIC to JPEG where the platform can.
/// Only the photo library is used, never the camera.
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  static const maxEdge = 2048.0, quality = 80;

  @override
  Future<List<PickedPhoto>> pick({required int max}) async {
    if (max <= 0) return const [];
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: maxEdge,
        maxHeight: maxEdge,
        imageQuality: quality,
        limit: max,
        // No location or other metadata is requested.
        requestFullMetadata: false,
      );
      return [
        for (final file in files.take(max))
          PickedPhoto(name: file.name, bytes: await file.readAsBytes()),
      ];
    } on PlatformException catch (error) {
      if (error.code.contains('access_denied')) {
        throw const CircleFailure(
          'CIRCLE needs access to your photos to add them. You can allow it in your phone’s Settings.',
        );
      }
      throw const CircleFailure(
        'Your photos couldn’t be opened. Please try again.',
      );
    }
  }
}
