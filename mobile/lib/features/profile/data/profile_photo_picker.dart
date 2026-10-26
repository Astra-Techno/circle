import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/circle_failure.dart';

/// Permission is requested only after the person chooses to change a photo.
abstract interface class ProfilePhotoPicker {
  Future<ProfilePickedPhoto?> pick();
}

class DeviceProfilePhotoPicker implements ProfilePhotoPicker {
  DeviceProfilePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<ProfilePickedPhoto?> pick() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      if (await file.length() > ProfilePickedPhoto.maxBytes) {
        throw const CircleFailure('Choose a photo smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > ProfilePickedPhoto.maxBytes) {
        throw const CircleFailure('Choose a photo smaller than 5 MB.');
      }
      String? mime;
      if (bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        mime = 'image/jpeg';
      } else if (bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
        mime = 'image/png';
      } else if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        mime = 'image/webp';
      }
      if (mime == null) {
        throw const CircleFailure('Choose a JPEG, PNG or WebP photo.');
      }
      return ProfilePickedPhoto(bytes: bytes, mimeType: mime);
    } on PlatformException catch (error) {
      throw CircleFailure(
        error.code == 'photo_access_denied'
            ? 'Allow photo access in your device settings, then try again.'
            : 'The photo library couldn’t open. Please try again.',
      );
    } on MissingPluginException {
      throw const CircleFailure(
        'Photo picking is not available on this device.',
      );
    }
  }
}
