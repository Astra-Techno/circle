import 'capsule.dart';

abstract interface class CapsuleRepository {
  Future<List<Capsule>> list();
  Future<Capsule?> get(String id);
  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  });
  Future<void> seal(String id);
  Future<void> delete(String id);
  Future<void> addEntry(String capsuleId, String text);
}
