import '../../workspace/application/workspace_providers.dart'
    show circleWorkspaceProvider;
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

/// Another member's photos are fetched through the existing private endpoint.
/// Exact shared membership is required both here and again by the server.
final sharedProfilePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String person, ProfilePhotoKind kind})>((
      ref,
      photo,
    ) async {
      final account = ref.watch(serverAccountProvider);
      final api = ref.watch(apiClientProvider);
      final shared = ref.watch(
        circleWorkspaceProvider.select((state) {
          final workspace = state.value;
          return workspace != null &&
              workspace.viewer == account?.id &&
              workspace.groups.any(
                (group) =>
                    group.isMember(workspace.viewer) &&
                    group.isMember(photo.person),
              );
        }),
      );
      if (account == null ||
          api == null ||
          !shared ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(photo.person)) {
        throw const CircleFailure('This profile isn’t available.');
      }
      final revision = api.sessionRevision;
      try {
        final bytes = await api.getBytes(
          '/profiles/${photo.person}/photos/${photo.kind.name}',
          query: {
            'size': photo.kind == ProfilePhotoKind.avatar ? 'thumb' : 'medium',
          },
          expectedAccount: account.id,
          expectedSession: revision,
        );
        if (!ref.mounted ||
            !identical(ref.read(apiClientProvider), api) ||
            api.sessionRevision != revision ||
            ref.read(serverAccountProvider)?.id != account.id) {
          throw const CircleFailure('Your session changed.');
        }
        return bytes;
      } on ApiError catch (error) {
        // No photo and inaccessible photos deliberately have the same response.
        if (error.status == 404) return null;
        rethrow;
      }
    }, retry: (_, _) => null);
