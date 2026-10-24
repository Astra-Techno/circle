import 'package:flutter/foundation.dart';
import '../../../core/api/api_error.dart';
import '../../../core/circle_failure.dart';
import '../data/api_media_repository.dart';

enum UploadStatus { waiting, uploading, ready, failed }

/// One photo in the composer and where its upload stands.
class UploadItem {
  UploadItem._(this.key, this.preview, this._photo, {String? error})
    : status = error == null ? UploadStatus.waiting : UploadStatus.failed,
      error = error,
      retryable = error == null;

  final int key;

  /// The downsized bytes, shown as the thumbnail from memory.
  final Uint8List preview;
  PreparedPhoto? _photo;
  UploadStatus status;
  double progress = 0;
  String? mediaId, error;

  /// False when the photo itself can't be used (HEIC, wrong type, size).
  bool retryable;
  String? _groupId;
  String? _errorCode;
}

/// Uploads the composer's photos to the chosen group, one at a time, with
/// progress, Retry and Remove. Uploads start once the audience is known
/// (tickets belong to one exact group) and start over if it changes.
class PhotoUploads extends ChangeNotifier {
  PhotoUploads(this._media);
  final ApiMediaRepository _media;

  final List<UploadItem> _items = [];
  String? _groupId;
  int _sequence = 0;
  bool _running = false, _disposed = false;

  List<UploadItem> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;

  /// Still waiting or uploading.
  bool get busy => _items.any(
    (item) =>
        item.status == UploadStatus.uploading ||
        (item.status == UploadStatus.waiting && _groupId != null),
  );
  bool get hasFailed =>
      _items.any((item) => item.status == UploadStatus.failed);

  /// The first failure's message, for one calm line under the photos.
  String? get firstError => _items
      .where((item) => item.status == UploadStatus.failed)
      .map((item) => item.error)
      .nonNulls
      .firstOrNull;

  /// Ready media ids in the order the photos were added.
  List<String> get readyIds => [
    for (final item in _items)
      if (item.status == UploadStatus.ready) ?item.mediaId,
  ];

  void add(List<PickedPhoto> picked) {
    for (final photo in picked) {
      PreparedPhoto? prepared;
      String? error;
      try {
        prepared = PreparedPhoto.prepare(photo.bytes);
      } on CircleFailure catch (failure) {
        error = failure.message;
      }
      _items.add(
        UploadItem._(++_sequence, photo.bytes, prepared, error: error),
      );
    }
    _notify();
    _pump();
  }

  /// Sets the audience. Photos already sent to another group are discarded
  /// there and uploaded again here.
  void target(String? groupId) {
    if (groupId == _groupId) return;
    _groupId = groupId;
    for (final item in _items) {
      if (item._photo == null) continue;
      if (item.mediaId != null) _media.discard(item.mediaId!);
      // A ticket belongs to one group, and a discarded upload can't come
      // back: start over with a new idempotency key.
      if (item._groupId != null) {
        item
          .._photo = item._photo!.withNewUploadId()
          .._groupId = null;
      }
      item
        ..mediaId = null
        ..status = UploadStatus.waiting
        ..progress = 0
        ..error = null;
    }
    _notify();
    _pump();
  }

  void retry(UploadItem item) {
    if (!item.retryable || item._photo == null) return;
    // An expired ticket can't be reused; anything else keeps its key so the
    // server recognises the same upload.
    if (item._errorCode == 'upload_expired' || item._errorCode == 'conflict') {
      item._photo = item._photo!.withNewUploadId();
    }
    item
      ..status = UploadStatus.waiting
      ..progress = 0
      ..error = null;
    _notify();
    _pump();
  }

  void remove(UploadItem item) {
    _items.remove(item);
    if (item.mediaId != null) _media.discard(item.mediaId!);
    _notify();
  }

  /// After sharing: the photos now belong to the Memory.
  void clearShared() {
    _items.clear();
    _notify();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (!_disposed) {
        final groupId = _groupId;
        final next = _items
            .where((item) => item.status == UploadStatus.waiting)
            .firstOrNull;
        if (groupId == null || next == null) break;
        await _upload(next, groupId);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _upload(UploadItem item, String groupId) async {
    item
      ..status = UploadStatus.uploading
      ..progress = 0
      .._groupId = groupId;
    _notify();
    try {
      final id = await _media.upload(
        groupId,
        item._photo!,
        onProgress: (progress) {
          item.progress = progress;
          _notify();
        },
      );
      if (!_items.contains(item) || _groupId != groupId) {
        // Removed, or the audience changed while uploading.
        await _media.discard(id);
        return;
      }
      item
        ..mediaId = id
        ..status = UploadStatus.ready
        ..progress = 1;
    } on CircleFailure catch (failure) {
      if (_groupId != groupId) return;
      item
        ..status = UploadStatus.failed
        ..error = failure.message
        .._errorCode = failure is ApiError ? failure.code : null;
      // A photo the server can never accept isn't worth retrying.
      if (failure is ApiError &&
          (failure.code == 'media_type_not_allowed' ||
              failure.code == 'media_too_large')) {
        item.retryable = false;
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
