import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:uuid/uuid.dart';
import '../../../core/circle_failure.dart';

/// The sizes the server keeps of every photo (ADR 0007).
enum MediaSize { thumb, medium, full }

/// A photo the person picked, already downsized by the picker.
class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// A picked photo checked and ready to upload: its real type (from the
/// bytes, not the file name), SHA-256 and an idempotency key that stays the
/// same across retries of the same upload.
class PreparedPhoto {
  PreparedPhoto._(this.bytes, this.mimeType, this.sha256, this.clientUploadId);

  /// The server refuses more than 15 MiB before processing.
  static const maxBytes = 15 * 1024 * 1024;

  /// Checks [bytes] and computes what the upload ticket needs. Throws a
  /// calm [CircleFailure] for HEIC, unknown types and oversized photos.
  factory PreparedPhoto.prepare(Uint8List bytes, {String? clientUploadId}) {
    final type = sniffImageType(bytes);
    if (type == 'image/heic') {
      throw const CircleFailure(
        'This photo is in HEIC format, which this server can’t read yet. '
        'Choose a JPEG or PNG photo instead.',
      );
    }
    if (type == null) {
      throw const CircleFailure(
        'This kind of photo isn’t supported. Use a JPEG, PNG or WebP photo.',
      );
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const CircleFailure(
        'This photo is too large. Photos can be up to 15 MB.',
      );
    }
    return PreparedPhoto._(
      bytes,
      type,
      crypto.sha256.convert(bytes).toString(),
      clientUploadId ?? newUploadId(),
    );
  }

  final Uint8List bytes;
  final String mimeType, sha256, clientUploadId;

  int get size => bytes.length;

  /// The same photo under a new idempotency key (for another group, or
  /// after the server let the old ticket expire).
  PreparedPhoto withNewUploadId() =>
      PreparedPhoto._(bytes, mimeType, sha256, newUploadId());

  static String newUploadId() => const Uuid().v4();
}

/// The image type from the file's first bytes: `image/jpeg`, `image/png`,
/// `image/webp`, `image/heic` (HEIC/HEIF), or null.
String? sniffImageType(Uint8List bytes) {
  bool at(int offset, List<int> signature) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  if (at(4, 'ftyp'.codeUnits)) {
    const brands = {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
      'mif1',
      'msf1',
    };
    final brand = bytes.length >= 12
        ? String.fromCharCodes(bytes.sublist(8, 12))
        : '';
    if (brands.contains(brand)) return 'image/heic';
  }
  return null;
}
