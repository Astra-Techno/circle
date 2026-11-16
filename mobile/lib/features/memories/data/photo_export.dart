import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/api/scoped_api.dart';
import '../../../core/circle_failure.dart';
import '../domain/memory_photo.dart';
import 'api_media_repository.dart';

enum PhotoExportAction { share, download }

/// Authorized image bytes, never the private signed URL used to obtain them.
class PhotoExportPayload {
  const PhotoExportPayload({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String name, mimeType;
}

abstract interface class PhotoExportBridge {
  bool get supported;
  Future<bool> export(PhotoExportAction action, PhotoExportPayload photo);
}

/// Android and iOS own the share/save UI through the native method channel.
class DevicePhotoExportBridge implements PhotoExportBridge {
  const DevicePhotoExportBridge();
  static const _channel = MethodChannel('circle/photo_export');

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> export(
    PhotoExportAction action,
    PhotoExportPayload photo,
  ) async {
    return await _channel.invokeMethod<bool>('export', {
          'action': action.name,
          'bytes': photo.bytes,
          'name': photo.name,
          'mime_type': photo.mimeType,
        }) ??
        false;
  }
}

/// Fetches full authorized bytes and hands them to the platform only after an
/// explicit action. A changed account/server/session invalidates the request.
class PhotoExportService {
  PhotoExportService(
    this._bridge,
    this._media,
    this._scope, {
    AssetBundle? assets,
  }) : _assets = assets ?? rootBundle;

  final PhotoExportBridge _bridge;
  final ApiMediaRepository? _media;
  final ScopedApi? _scope;
  final AssetBundle _assets;
  bool _busy = false;

  Future<bool> export(
    MemoryPhoto photo,
    PhotoExportAction action, {
    String? asset,
  }) async {
    if (_busy) {
      throw const CircleFailure('Finish the current photo action first.');
    }
    _busy = true;
    try {
      if (!_bridge.supported) {
        throw const CircleFailure('Photo export isn’t available here.');
      }
      final bytes = await _bytes(photo, asset: asset);
      final format = _format(bytes);
      final payload = PhotoExportPayload(
        bytes: bytes,
        name: 'circle-photo.${format.extension}',
        mimeType: format.mimeType,
      );
      return await _bridge.export(action, payload);
    } on PlatformException catch (error) {
      throw CircleFailure(
        error.code == 'busy'
            ? 'Finish the current photo action first.'
            : error.message ?? 'The photo could not be exported.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<Uint8List> _bytes(MemoryPhoto photo, {String? asset}) async {
    final mediaId = photo.mediaId;
    if (mediaId != null) {
      final media = _media;
      final scope = _scope;
      if (media == null || scope == null) {
        throw const CircleFailure('Photos aren’t available here.');
      }
      scope.check();
      final link = await media.link(mediaId, MediaSize.full);
      scope.check();
      return scope.bytes(link.uri.toString());
    }
    if (asset == null) {
      throw const CircleFailure('Illustrated placeholders can’t be exported.');
    }
    final data = await _assets.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static bool _matches(Uint8List bytes, List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  static ({String extension, String mimeType}) _format(Uint8List bytes) {
    if (_matches(bytes, const [0xff, 0xd8, 0xff])) {
      return (extension: 'jpg', mimeType: 'image/jpeg');
    }
    if (_matches(bytes, const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ])) {
      return (extension: 'png', mimeType: 'image/png');
    }
    if (_matches(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
        _matches(bytes, const [0x57, 0x45, 0x42, 0x50], 8)) {
      return (extension: 'webp', mimeType: 'image/webp');
    }
    throw const CircleFailure('This photo format can’t be exported.');
  }
}
