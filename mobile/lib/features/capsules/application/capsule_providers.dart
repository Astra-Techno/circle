import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_settings.dart';
import '../../../core/api/api_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/local_capsule_repository.dart';
import '../data/server_capsule_repository.dart';
import '../domain/capsule_repository.dart';
import '../../../core/api/scoped_api.dart';
import '../domain/capsule.dart';

export '../domain/capsule.dart';

/// One repository per signed-in account. Disposed on sign-out.
final capsuleRepositoryProvider = Provider<CapsuleRepository>((ref) {
  final viewer = ref.watch(circleViewerProvider);
  final storage = ref.watch(localSettingsStoreProvider);
  final server = ref.watch(apiConfigProvider)?.baseUrl.toString() ?? 'test';
  final account = ref.watch(serverAccountProvider)?.id;
  final legacy = LocalCapsuleRepository(
    viewer: viewer,
    storage: storage,
    server: server,
  );
  final api = ref.watch(apiClientProvider);
  if (api == null || account == null) return legacy;
  final groups = ref.watch(circleWorkspaceProvider).value?.groups ?? [];
  return ServerCapsuleRepository(
    scope: ScopedApi(
      api,
      account,
      api.sessionRevision,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account,
    ),
    groups: [for (final group in groups) group.id],
    legacy: legacy,
  );
});

final capsuleDetailProvider = FutureProvider.family<Capsule?, String>((
  ref,
  id,
) async {
  await ref.watch(capsulesProvider.future);
  return ref.watch(capsuleRepositoryProvider).get(id);
}, retry: (_, _) => null);

/// All capsules for the current viewer, newest first.
final capsulesProvider =
    AsyncNotifierProvider<CapsulesController, List<Capsule>>(
      CapsulesController.new,
      retry: (_, _) => null,
    );

class CapsulesController extends AsyncNotifier<List<Capsule>> {
  @override
  Future<List<Capsule>> build() => ref.watch(capsuleRepositoryProvider).list();

  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) async {
    final repository = ref.read(capsuleRepositoryProvider);
    final capsule = await repository.create(
      groupId: groupId,
      title: title,
      message: message,
      unlockAt: unlockAt,
    );
    final updated = await repository.list();
    if (ref.mounted &&
        identical(ref.read(capsuleRepositoryProvider), repository)) {
      state = AsyncData(updated);
    }
    return capsule;
  }

  Future<void> seal(String id) async {
    final repository = ref.read(capsuleRepositoryProvider);
    await repository.seal(id);
    final updated = await repository.list();
    if (ref.mounted &&
        identical(ref.read(capsuleRepositoryProvider), repository)) {
      state = AsyncData(updated);
    }
  }

  Future<void> delete(String id) async {
    final repository = ref.read(capsuleRepositoryProvider);
    await repository.delete(id);
    final updated = await repository.list();
    if (ref.mounted &&
        identical(ref.read(capsuleRepositoryProvider), repository)) {
      state = AsyncData(updated);
    }
  }

  Future<void> addEntry(String capsuleId, String text) async {
    final repository = ref.read(capsuleRepositoryProvider);
    await repository.addEntry(capsuleId, text);
    final updated = await repository.list();
    if (ref.mounted &&
        identical(ref.read(capsuleRepositoryProvider), repository)) {
      state = AsyncData(updated);
    }
  }
}
