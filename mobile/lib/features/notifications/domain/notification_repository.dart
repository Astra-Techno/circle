import 'notifications.dart';

export '../../../core/circle_failure.dart';
export 'notifications.dart';

/// The activity inbox (I1) and notification settings (H4). Local preview:
/// nothing is ever pushed; the settings show what would happen.
abstract interface class NotificationRepository {
  /// The viewer's activity, newest first, with read state and delivery.
  Future<ActivityFeed> activity(String viewer);
  Future<void> markRead(String viewer, String itemId);
  Future<void> markAllRead(String viewer);

  Future<NotificationSettingsView> settings(String viewer);
  Future<void> setPush(String viewer, NotificationType type, bool push);
  Future<void> setQuietHours(
    String viewer, {
    bool? enabled,
    int? start,
    int? end,
  });
  Future<void> setDigest(String viewer, {bool? enabled, int? at});

  /// Null returns the group to its size-based default.
  Future<void> setGroupLevel(
    String viewer,
    String groupId,
    GroupNotifyLevel? level,
  );

  /// Local preview only: discards every change.
  Future<void> reset({required bool showcase});
}
