import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/circle_failure.dart';
import '../../workspace/application/server_session.dart';
import '../data/profile_photo_picker.dart';

export '../../../core/api/auth_api.dart'
    show ProfilePhotoKind, ProfilePickedPhoto;
export '../data/profile_photo_picker.dart' show ProfilePhotoPicker;

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => DeviceProfilePhotoPicker(),
);

/// Private bytes are scoped by the active account, API server and opaque photo
/// version. No bearer token or private path is ever put in a public image URL.
final profilePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, ({ProfilePhotoKind kind, String version})>((
      ref,
      photo,
    ) async {
      final account = ref.watch(
        serverAccountProvider.select(
          (a) => (id: a?.id, version: a?.photoVersion(photo.kind)),
        ),
      );
      final api = ref.watch(apiClientProvider);
      if (account.id == null ||
          api == null ||
          photo.version.isEmpty ||
          account.version != photo.version) {
        throw const CircleFailure('Please log in again to view your photo.');
      }
      final bytes = await api.getBytes(
        '/me/photos/${photo.kind.name}',
        query: {
          'size': photo.kind == ProfilePhotoKind.avatar ? 'thumb' : 'medium',
        },
      );
      if (!ref.mounted) throw const CircleFailure('Your session changed.');
      final current = ref.read(serverAccountProvider);
      if (current?.id != account.id ||
          current?.photoVersion(photo.kind) != photo.version ||
          !identical(ref.read(apiClientProvider), api)) {
        throw const CircleFailure('Your session changed.');
      }
      return bytes;
    }, retry: (_, _) => null);
