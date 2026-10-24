import 'dart:async';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_json.dart';
import '../../../core/api/signed_media_url.dart';
import '../../../core/circle_failure.dart';
import '../domain/photo_upload.dart';

export '../domain/photo_upload.dart';

/// Private photos (ADR 0007): upload ticket → bytes → ready asset, and
/// short-lived signed links for viewing. Links are cached in memory until
/// about 30 seconds before they expire; nothing is written to disk.
class ApiMediaRepository {
  ApiMediaRepository({required this.api, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final ApiClient api;
  final DateTime Function() _now;

  final Map<String, SignedMediaUrl> _links = {};
  final Map<String, Future<SignedMediaUrl>> _pending = {};

  /// Shown when the server has no image library (`503`).
  static const unavailableMessage =
      'Photos can’t be processed on this server yet.';

  /// Uploads [photo] to [groupId] and returns the ready media id. Retrying
  /// with the same [PreparedPhoto] reuses its `client_upload_id`, so the
  /// server hands back the same ticket instead of a duplicate.
  Future<String> upload(
    String groupId,
    PreparedPhoto photo, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ticket = ApiJson.map(
        await api.post(
          '/groups/$groupId/media/uploads',
          body: {
            'client_upload_id': photo.clientUploadId,
            'mime_type': photo.mimeType,
            'byte_size': photo.size,
            'sha256': photo.sha256,
          },
        ),
      );
      final uploadId = ApiJson.id(ticket['upload_id']);
      final path = ApiJson.string(
        ticket['upload_path'],
        '/media/uploads/$uploadId/content',
      );
      if (!RegExp(r'^/media/uploads/[A-Za-z0-9-]+/content$').hasMatch(path)) {
        ApiJson.unexpected();
      }
      onProgress?.call(0);
      final asset = ApiJson.map(
        await api.putBytes(
          path,
          photo.bytes,
          contentType: photo.mimeType,
          onProgress: (sent, total) {
            if (total > 0) onProgress?.call(sent / total);
          },
        ),
      );
      if (asset['status'] != 'ready') {
        throw const CircleFailure(
          'This photo couldn’t be processed. Try another one.',
        );
      }
      onProgress?.call(1);
      return ApiJson.id(asset['id']);
    } on ApiError catch (error) {
      throw failureFor(error);
    }
  }

  /// Calm words for upload failures; `503` means no image processing.
  static ApiError failureFor(ApiError error) => error.status == 503
      ? ApiError(
          unavailableMessage,
          code: error.code,
          status: error.status,
          retryAfter: error.retryAfter,
        )
      : error;

  /// Discards an upload that was never attached. Best effort: unattached
  /// uploads are also deleted by the server after 24 hours.
  Future<void> discard(String mediaId) async {
    try {
      await api.delete('/media/$mediaId');
    } on ApiError {
      // Left for the server's cleanup.
    }
  }

  /// A signed link for [mediaId] at [size], reused while it has more than
  /// 30 seconds left.
  Future<SignedMediaUrl> link(String mediaId, MediaSize size) {
    final key = '$mediaId/${size.name}';
    final cached = _links[key];
    if (cached != null && cached.usableAt(_now())) return Future.value(cached);
    // The callback must not return the removed future (it would wait for
    // itself).
    return _pending[key] ??= _fetchLink(mediaId, size, key).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<SignedMediaUrl> _fetchLink(
    String mediaId,
    MediaSize size,
    String key,
  ) async {
    final data = ApiJson.map(
      await api.get('/media/$mediaId', query: {'size': size.name}),
    );
    final url = SignedMediaUrl.fromApi(
      api.config,
      ApiJson.string(data['url']),
      expiresAt:
          ApiJson.time(data['expires_at']) ??
          _now().toUtc().add(const Duration(minutes: 5)),
    );
    if (url == null) ApiJson.unexpected();
    _links[key] = url;
    return url;
  }

  /// Forgets every cached link (logout).
  void clear() {
    _links.clear();
    _pending.clear();
  }
}
