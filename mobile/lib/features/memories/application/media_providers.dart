import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/signed_media_url.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/api_media_repository.dart';
import '../data/photo_picker.dart';

export '../data/api_media_repository.dart';
export '../data/photo_picker.dart';

/// Private photos on the server; null in the preview (fictional scenes).
/// A new account gets a new repository, so cached links never carry over.
final mediaRepositoryProvider = Provider<ApiMediaRepository?>((ref) {
  final signedIn = ref.watch(serverAccountProvider.select((a) => a?.id));
  final api = ref.watch(apiClientProvider);
  if (signedIn == null || api == null) return null;
  final repository = ApiMediaRepository(
    api: api,
    now: ref.watch(circleClockProvider),
  );
  ref.onDispose(repository.clear);
  return repository;
});

/// The device photo library. Tests replace it.
final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());

/// A signed link for one photo at one size. Each screen that shows the
/// photo asks again, and the repository reuses a link until about 30
/// seconds before it expires.
final signedMediaUrlProvider = FutureProvider.autoDispose
    .family<SignedMediaUrl, ({String mediaId, MediaSize size})>((ref, photo) {
      final media = ref.watch(mediaRepositoryProvider);
      if (media == null) {
        throw const CircleFailure('Photos aren’t available here.');
      }
      return media.link(photo.mediaId, photo.size);
    });
