import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/groups/domain/circle_repository.dart';
import '../features/groups/data/mock_circle_repository.dart';

const previewViewer = 'you';
final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => MockCircleRepository(),
);
final circleWorkspaceProvider =
    AsyncNotifierProvider<CircleWorkspaceController, CircleWorkspace>(
      CircleWorkspaceController.new,
    );
final circlePreviewSessionProvider =
    NotifierProvider<CirclePreviewSession, bool>(CirclePreviewSession.new);

class CirclePreviewSession extends Notifier<bool> {
  @override
  bool build() => false;
  void enter({required bool showcase}) {
    ref.read(circleRepositoryProvider).reset(showcase: showcase);
    ref.invalidate(circleWorkspaceProvider);
    state = true;
  }

  void leave() {
    ref.read(circleRepositoryProvider).reset(showcase: false);
    ref.invalidate(circleWorkspaceProvider);
    state = false;
  }
}

class CircleWorkspaceController extends AsyncNotifier<CircleWorkspace> {
  CircleRepository get _repository => ref.read(circleRepositoryProvider);
  @override
  Future<CircleWorkspace> build() => _repository.load(previewViewer);
  Future<void> _refresh() async {
    state = AsyncData(await _repository.load(previewViewer));
  }

  Future<CircleGroup> createGroup(
    String name,
    CircleType type, {
    String? parentId,
  }) async {
    final group = _repository.createGroup(
      previewViewer,
      name,
      type,
      parentId: parentId,
    );
    await _refresh();
    return group;
  }

  Future<void> createMemory(String groupId, String text) async {
    _repository.createMemory(previewViewer, groupId, text);
    await _refresh();
  }

  Future<void> love(String id) async {
    _repository.loveMemory(previewViewer, id);
    await _refresh();
  }

  Future<void> save(String id) async {
    _repository.saveMemory(previewViewer, id);
    await _refresh();
  }

  Future<void> comment(String id, String text) async {
    _repository.comment(previewViewer, id, text);
    await _refresh();
  }

  Future<void> rsvp(String id, Attendance choice) async {
    _repository.rsvp(previewViewer, id, choice);
    await _refresh();
  }
}
