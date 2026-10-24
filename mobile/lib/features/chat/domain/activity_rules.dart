import 'chat_models.dart';

/// Activity status ("Active now", "Active 2h ago"), Instagram-style
/// (README §3.2). Pure Dart: the repository decides with these rules and
/// the screens only show what it returns. Shown in 1:1 contexts only.
abstract final class ActivityRules {
  /// Activity this recent reads "Active now".
  static const nowWindow = Duration(minutes: 5);

  /// Activity this old or older is never shown.
  static const maxAge = Duration(hours: 48);

  static const activeNow = 'Active now';

  /// Whether [viewer] may see when [person] was last active. It is
  /// reciprocal: both must have "Show activity status" on. They must share
  /// at least one group ([shared], exact active membership), neither may
  /// have blocked the other, and nobody is shown their own status. While
  /// their 1:1 is an unaccepted message request ([pendingRequest]), neither
  /// sees the other's activity, as with "Seen".
  static bool canSee({
    required String viewer,
    required String person,
    required ChatPrivacy viewerPrivacy,
    required ChatPrivacy personPrivacy,
    required List<CircleGroup> shared,
    bool pendingRequest = false,
  }) =>
      viewer != person &&
      !pendingRequest &&
      viewerPrivacy.showActivity &&
      personPrivacy.showActivity &&
      shared.isNotEmpty &&
      !viewerPrivacy.blocked.contains(person) &&
      !personPrivacy.blocked.contains(viewer);

  /// "Active now" (≤ 5 min), "Active 12m ago" (< 1 h), "Active 3h ago"
  /// (< 24 h), "Active yesterday" (< 48 h). Older or unknown: null, and
  /// nothing is shown.
  static String? label(DateTime? lastActiveAt, DateTime now) {
    if (lastActiveAt == null) return null;
    final age = now.difference(lastActiveAt);
    if (age <= nowWindow) return activeNow;
    if (age < const Duration(hours: 1)) return 'Active ${age.inMinutes}m ago';
    if (age < const Duration(hours: 24)) return 'Active ${age.inHours}h ago';
    if (age < maxAge) return 'Active yesterday';
    return null;
  }

  /// [label] when [canSee] allows it, otherwise null.
  static String? visibleLabel({
    required String viewer,
    required String person,
    required ChatPrivacy viewerPrivacy,
    required ChatPrivacy personPrivacy,
    required List<CircleGroup> shared,
    required DateTime? lastActiveAt,
    required DateTime now,
    bool pendingRequest = false,
  }) =>
      canSee(
        viewer: viewer,
        person: person,
        viewerPrivacy: viewerPrivacy,
        personPrivacy: personPrivacy,
        shared: shared,
        pendingRequest: pendingRequest,
      )
      ? label(lastActiveAt, now)
      : null;

  /// For screen readers: "Mira, active now", "Dev, active 2h ago".
  static String spoken(String name, String? activity) {
    if (activity == null || activity.isEmpty) return name;
    return '$name, ${activity[0].toLowerCase()}${activity.substring(1)}';
  }
}
