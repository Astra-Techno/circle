/// Persistent server delivery policy; separate from fictional Activity previews.
enum PushCategory {
  memories,
  repliesReactions,
  groups,
  chats,
  events,
  polls,
  albums,
  security,
}

enum PushDevicePlatform { android, ios }

class PushPreferences {
  PushPreferences({
    required this.enabled,
    required Map<PushCategory, bool> categories,
    required this.quietHours,
    required this.quietStart,
    required this.quietEnd,
    required this.timezone,
  }) : categories = Map.unmodifiable(categories);
  final bool enabled;
  final Map<PushCategory, bool> categories;
  final bool quietHours;
  final int quietStart, quietEnd;
  final String timezone;
}
