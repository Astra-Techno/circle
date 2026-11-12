import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/scoped_api.dart';
import '../data/api/activity_api.dart';
import '../../chat/application/chat_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/mock_notification_repository.dart';
import '../domain/notification_repository.dart';

export '../domain/notification_repository.dart';

final liveActivityApiProvider = Provider<ActivityApi>((ref) {
  final api = ref.watch(apiClientProvider);
  final account = ref.watch(serverAccountProvider)?.id;
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to see activity.');
  }
  return ActivityApi(
    ScopedApi(
      api,
      account,
      api.sessionRevision,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account,
    ),
  );
});
final activityPagesProvider = NotifierProvider<ActivityPages, int>(
  ActivityPages.new,
);

class ActivityPages extends Notifier<int> {
  @override
  int build() {
    ref.watch(serverAccountProvider);
    return 1;
  }

  void more() => state++;
}

/// Legacy settings/test interface. Authenticated Activity reads and mutations
/// use liveActivityApiProvider, without mixing real data into this fixture store.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository(
    groups: ref.watch(circleRepositoryProvider),
    chat: ref.watch(chatRepositoryProvider),
    showcase: false,
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
  if (ref.watch(serverAccountProvider) != null) {
    return ref
        .watch(liveActivityApiProvider)
        .load(ref.watch(activityPagesProvider));
  }
  ref.watch(circleWorkspaceProvider);
  ref.watch(chatControllerProvider);
  return ref
      .watch(notificationRepositoryProvider)
      .activity(ref.watch(circleViewerProvider));
}, retry: (_, _) => null);

/// Server unread count; delivery does not claim a push was sent.
final activityBadgeProvider = Provider<int>(
  (ref) => ref.watch(circleFeaturesProvider).has(CircleFeature.activity)
      ? (ref.watch(activityFeedProvider).isLoading
            ? 0
            : ref.watch(activityFeedProvider).value?.badge ?? 0)
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

  Future<void> markRead(String id) async {
    if (ref.read(serverAccountProvider) == null) {
      return _run((repo, viewer) => repo.markRead(viewer, id));
    }
    await ref.read(liveActivityApiProvider).markRead(id);
    if (ref.mounted) state++;
  }

  Future<void> markAllRead() async {
    if (ref.read(serverAccountProvider) == null) {
      return _run((repo, viewer) => repo.markAllRead(viewer));
    }
    await ref.read(liveActivityApiProvider).markRead(null);
    if (ref.mounted) state++;
  }

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
