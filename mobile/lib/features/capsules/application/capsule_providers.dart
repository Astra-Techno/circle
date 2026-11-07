import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_settings.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/local_capsule_repository.dart';
import '../domain/capsule.dart';

export '../domain/capsule.dart';

/// One repository per signed-in account. Disposed on sign-out.
final capsuleRepositoryProvider = Provider<LocalCapsuleRepository>((ref) {
  final viewer = ref.watch(circleViewerProvider);
  final storage = ref.watch(localSettingsStoreProvider);
  return LocalCapsuleRepository(viewer: viewer, storage: storage);
});

/// All capsules for the current viewer, newest first.
final capsulesProvider =
    AsyncNotifierProvider<CapsulesController, List<Capsule>>(
      CapsulesController.new,
    );

class CapsulesController extends AsyncNotifier<List<Capsule>> {
  @override
  Future<List<Capsule>> build() => ref.read(capsuleRepositoryProvider).list();

  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) async {
    final capsule = await ref
        .read(capsuleRepositoryProvider)
        .create(
          groupId: groupId,
          title: title,
          message: message,
          unlockAt: unlockAt,
        );
    state = AsyncData(await ref.read(capsuleRepositoryProvider).list());
    return capsule;
  }

  Future<void> seal(String id) async {
    await ref.read(capsuleRepositoryProvider).seal(id);
    state = AsyncData(await ref.read(capsuleRepositoryProvider).list());
  }

  Future<void> delete(String id) async {
    await ref.read(capsuleRepositoryProvider).delete(id);
    state = AsyncData(await ref.read(capsuleRepositoryProvider).list());
  }

  Future<void> addEntry(String capsuleId, String text) async {
    await ref.read(capsuleRepositoryProvider).addEntry(capsuleId, text);
    state = AsyncData(await ref.read(capsuleRepositoryProvider).list());
  }
}
