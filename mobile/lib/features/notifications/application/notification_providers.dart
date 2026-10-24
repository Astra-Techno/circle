import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/application/chat_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/mock_notification_repository.dart';
import '../domain/notification_repository.dart';

export '../domain/notification_repository.dart';

/// The local mock. A new preview session (or ending one) starts afresh, so
/// read state and settings are cleared.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final entered = ref.watch(circlePreviewSessionProvider);
  final showcase =
      entered && ref.read(circlePreviewSessionProvider.notifier).showcase;
  return MockNotificationRepository(
    groups: ref.watch(previewOnlyRepositoryProvider),
    chat: ref.watch(chatRepositoryProvider),
    showcase: showcase,
    now: ref.watch(circleClockProvider),
  );
});

/// Runs changes; its state is a revision that reads watch.
final notificationControllerProvider =
    NotifierProvider<NotificationController, int>(NotificationController.new);

/// The activity inbox. Follows the workspace and chats, so it updates as
/// soon as something changes there.
final activityFeedProvider = FutureProvider<ActivityFeed>((ref) {
  ref.watch(notificationControllerProvider);
  ref.watch(circleWorkspaceProvider);
  ref.watch(chatControllerProvider);
  return ref
      .watch(notificationRepositoryProvider)
      .activity(ref.watch(circleViewerProvider));
});

/// The bell's badge: unread items that need the person. Nothing while
/// the activity inbox isn't on the server yet.
final activityBadgeProvider = Provider<int>(
  (ref) => ref.watch(circleFeaturesProvider).has(CircleFeature.activity)
      ? ref.watch(activityFeedProvider).value?.badge ?? 0
      : 0,
);

final notificationSettingsProvider = FutureProvider<NotificationSettingsView>((
  ref,
) {
  ref.watch(notificationControllerProvider);
  ref.watch(circleWorkspaceProvider);
  ref.watch(chatControllerProvider);
  return ref
      .watch(notificationRepositoryProvider)
      .settings(ref.watch(circleViewerProvider));
});

class NotificationController extends Notifier<int> {
  @override
  int build() {
    ref.watch(notificationRepositoryProvider);
    return 0;
  }

  Future<void> _run(
    Future<void> Function(NotificationRepository, String) change,
  ) async {
    try {
      await change(
        ref.read(notificationRepositoryProvider),
        ref.read(circleViewerProvider),
      );
    } finally {
      if (ref.mounted) state++;
    }
  }

  Future<void> markRead(String id) =>
      _run((repo, viewer) => repo.markRead(viewer, id));
  Future<void> markAllRead() =>
      _run((repo, viewer) => repo.markAllRead(viewer));
  Future<void> setPush(NotificationType type, bool push) =>
      _run((repo, viewer) => repo.setPush(viewer, type, push));
  Future<void> setQuietHours({bool? enabled, int? start, int? end}) => _run(
    (repo, viewer) =>
        repo.setQuietHours(viewer, enabled: enabled, start: start, end: end),
  );
  Future<void> setDigest({bool? enabled, int? at}) =>
      _run((repo, viewer) => repo.setDigest(viewer, enabled: enabled, at: at));
  Future<void> setGroupLevel(String groupId, GroupNotifyLevel? level) =>
      _run((repo, viewer) => repo.setGroupLevel(viewer, groupId, level));
}
