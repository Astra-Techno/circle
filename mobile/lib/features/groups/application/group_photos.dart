import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../profile/application/profile_providers.dart';
export '../../profile/application/profile_providers.dart' show ProfilePhotoKind;

typedef GroupPhotoRequest = ({
  String group,
  ProfilePhotoKind kind,
  String version,
});

final groupPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, GroupPhotoRequest>(
      (ref, photo) => _loadGroupPhoto(ref, photo),
      retry: (_, _) => null,
    );

/// Small Circle list covers use the server thumbnail, not a banner rendition.
final groupPhotoPreviewBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, GroupPhotoRequest>(
      (ref, photo) => _loadGroupPhoto(ref, photo, thumbnail: true),
      retry: (_, _) => null,
    );

Future<Uint8List> _loadGroupPhoto(
  Ref ref,
  GroupPhotoRequest photo, {
  bool thumbnail = false,
}) async {
  final api = ref.watch(apiClientProvider),
      account = ref.watch(serverAccountProvider);
  final access = ref.watch(
    circleWorkspaceProvider.select((state) {
      final group = state.value?.group(photo.group);
      return (
        member: account != null && group?.isMember(account.id) == true,
        version: photo.kind == ProfilePhotoKind.avatar
            ? group?.avatarVersion
            : group?.coverVersion,
      );
    }),
  );
  final version = access.version;
  if (api == null ||
      account == null ||
      !access.member ||
      version != photo.version) {
    throw const CircleFailure('This group photo isn’t available.');
  }
  final revision = api.sessionRevision;
  final size = photo.kind == ProfilePhotoKind.avatar || thumbnail
      ? 'thumb'
      : 'medium';
  final cacheSmall = photo.kind == ProfilePhotoKind.avatar || thumbnail;
  // Reuse small avatars across list remounts, after the same membership
  // and photo-version checks as a network request. Large covers stay uncached.
  final cache = ref.watch(personPhotoCacheProvider);
  final cacheKey = 'group:${photo.group}:$version:${photo.kind.name}:$size';
  if (cacheSmall) {
    final cached = cache.read(cacheKey, revision)?.bytes;
    if (cached != null) return cached;
  }
  final bytes = await api.getBytes(
    '/groups/${Uri.encodeComponent(photo.group)}/photos/${photo.kind.name}',
    query: {'size': size},
    expectedAccount: account.id,
    expectedSession: revision,
  );
  if (!ref.mounted ||
      api.sessionRevision != revision ||
      !identical(ref.read(apiClientProvider), api)) {
    throw const CircleFailure('Your session changed.');
  }
  final current = ref.read(circleWorkspaceProvider).value?.group(photo.group);
  if (current?.isMember(account.id) != true ||
      (photo.kind == ProfilePhotoKind.avatar
              ? current?.avatarVersion
              : current?.coverVersion) !=
          version) {
    throw const CircleFailure('This group photo changed.');
  }
  if (cacheSmall) {
    cache.put(cacheKey, bytes, revision);
  }
  return bytes;
}

final groupPhotoActionsProvider = Provider<GroupPhotoActions>(
  (ref) => GroupPhotoActions(ref),
);

class GroupPhotoScope {
  const GroupPhotoScope(this.api, this.account, this.revision, this.group);
  final ApiClient api;
  final String account, group;
  final int revision;
}

class GroupPhotoActions {
  GroupPhotoActions(this.ref);
  final Ref ref;
  GroupPhotoScope capture(String id) {
    final api = ref.read(apiClientProvider),
        account = ref.read(serverAccountProvider);
    if (api == null || account == null) {
      throw const CircleFailure('Sign in again to edit group photos.');
    }
    final scope = GroupPhotoScope(api, account.id, api.sessionRevision, id);
    check(scope);
    return scope;
  }

  void check(GroupPhotoScope scope) {
    if (!ref.mounted) throw const CircleFailure('Open the group again.');
    final workspace = ref.read(circleWorkspaceProvider).value;
    if (scope.api.sessionRevision != scope.revision ||
        !identical(ref.read(apiClientProvider), scope.api) ||
        ref.read(serverAccountProvider)?.id != scope.account ||
        workspace?.viewer != scope.account ||
        workspace?.group(scope.group)?.roleOf(scope.account)?.isAdmin != true) {
      throw const CircleFailure(
        'Only current group admins can change these photos.',
      );
    }
  }

  Future<void> change(
    GroupPhotoScope scope,
    ProfilePhotoKind kind, {
    required bool remove,
  }) async {
    check(scope);
    final photo = remove
        ? null
        : await ref.read(profilePhotoPickerProvider).pick();
    if (!remove && photo == null) return;
    check(scope);
    final path =
        '/groups/${Uri.encodeComponent(scope.group)}/photos/${kind.name}';
    if (remove) {
      await scope.api.delete(
        path,
        expectedAccount: scope.account,
        expectedSession: scope.revision,
      );
    } else {
      await scope.api.putBytes(
        path,
        photo!.bytes,
        contentType: photo.mimeType,
        expectedAccount: scope.account,
        expectedSession: scope.revision,
      );
    }
    check(scope);
    await ref.read(circleWorkspaceProvider.notifier).refresh();
  }
}
