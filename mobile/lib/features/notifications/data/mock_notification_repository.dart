import '../../chat/domain/chat_repository.dart';
import '../../workspace/domain/circle_repository.dart';
import '../domain/notification_repository.dart';

/// Session-local activity and settings. Items come from what the viewer can
/// already see (groups, Memories, events, chats, @mentions) plus a few
/// fixed fictional items; nothing arrives on a timer and nothing is pushed.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({
    required WorkspaceReader groups,
    required ChatRepository chat,
    bool showcase = false,
    DateTime Function()? now,
  }) : _workspace = groups,
       _chats = chat,
       _now = now ?? DateTime.now {
    _seed(showcase: showcase);
  }

  final WorkspaceReader _workspace;
  final ChatRepository _chats;
  final DateTime Function() _now;
  final Map<String, NotificationSettings> _settings = {};
  final Map<String, Set<String>> _read = {};
  List<ActivityItem> _seeded = [];

  @override
  Future<void> reset({required bool showcase}) async =>
      _seed(showcase: showcase);

  NotificationSettings _of(String viewer) =>
      _settings[viewer] ?? NotificationSettings();

  int get _minuteOfDay {
    final local = _now().toLocal();
    return local.hour * 60 + local.minute;
  }

  Future<CircleWorkspace> _member(String viewer, String groupId) async {
    final workspace = await _workspace.load(viewer);
    if (workspace.group(groupId) == null) {
      throw const CircleFailure('This group is not shared with you.');
    }
    return workspace;
  }

  Future<List<ActivityEntry>> _entries(String viewer) async {
    final workspace = await _workspace.load(viewer);
    final inbox = await _chats.inbox(viewer);
    final messages = await _chats.readableMessages(viewer);
    final settings = _of(viewer);
    final read = _read[viewer] ?? const {};
    final chats = {
      for (final chat in [...inbox.chats, ...inbox.requests, ...inbox.archived])
        chat.id: chat,
    };
    final minute = _minuteOfDay;
    return [
      for (final item in ActivityInboxRules.generate(
        workspace: workspace,
        inbox: inbox,
        messages: messages,
        now: _now().toUtc(),
        seeded: viewer == 'you' ? _seeded : const [],
      ))
        ActivityEntry(
          item: item,
          read: read.contains(item.id),
          delivery: NotificationRules.deliver(
            item,
            settings,
            minuteOfDay: minute,
            groupMembers: item.groupId == null
                ? null
                : workspace.group(item.groupId!)?.roles.length,
            chatMuted: switch (chats[item.conversationId ?? '']) {
              final chat? => chat.muted && !chat.mutedByDefault,
              null => false,
            },
          ),
        ),
    ];
  }

  @override
  Future<ActivityFeed> activity(String viewer) async =>
      ActivityFeed(entries: await _entries(viewer));

  @override
  Future<void> markRead(String viewer, String itemId) async {
    (_read[viewer] ??= {}).add(itemId);
  }

  @override
  Future<void> markAllRead(String viewer) async {
    final entries = await _entries(viewer);
    (_read[viewer] ??= {}).addAll(entries.map((entry) => entry.item.id));
  }

  @override
  Future<NotificationSettingsView> settings(String viewer) async {
    final workspace = await _workspace.load(viewer);
    final inbox = await _chats.inbox(viewer);
    final settings = _of(viewer);
    return NotificationSettingsView(
      settings: settings,
      groups: [
        for (final group in workspace.groups)
          GroupNotifyChoice(
            group: group,
            level: NotificationRules.levelFor(
              settings,
              group.id,
              group.roles.length,
            ),
            isDefault: !settings.groupLevels.containsKey(group.id),
          ),
      ],
      mutedChats: [
        for (final chat in [...inbox.chats, ...inbox.archived])
          if (chat.muted) chat,
      ],
    );
  }

  @override
  Future<void> setPush(String viewer, NotificationType type, bool push) async {
    final settings = _of(viewer);
    _settings[viewer] = settings.copyWith(push: {...settings.push, type: push});
  }

  static void _checkMinute(int? value) {
    if (value != null && (value < 0 || value >= 24 * 60)) {
      throw const CircleFailure('Choose a time of day.');
    }
  }

  @override
  Future<void> setQuietHours(
    String viewer, {
    bool? enabled,
    int? start,
    int? end,
  }) async {
    _checkMinute(start);
    _checkMinute(end);
    _settings[viewer] = _of(
      viewer,
    ).copyWith(quietHours: enabled, quietStart: start, quietEnd: end);
  }

  @override
  Future<void> setDigest(String viewer, {bool? enabled, int? at}) async {
    _checkMinute(at);
    _settings[viewer] = _of(viewer).copyWith(digest: enabled, digestAt: at);
  }

  @override
  Future<void> setGroupLevel(
    String viewer,
    String groupId,
    GroupNotifyLevel? level,
  ) async {
    await _member(viewer, groupId);
    final settings = _of(viewer);
    final levels = {...settings.groupLevels};
    if (level == null) {
      levels.remove(groupId);
    } else {
      levels[groupId] = level;
    }
    _settings[viewer] = settings.copyWith(groupLevels: levels);
  }

  // ------------------------------------------------------------------- seed

  /// A few fixed fictional items for the showcase viewer. They point at
  /// real fictional places (a group, an event, a chat), so tapping works.
  void _seed({required bool showcase}) {
    _settings.clear();
    _read.clear();
    _seeded = [];
    if (!showcase) return;
    final seedTime = _now().toUtc();
    DateTime ago(Duration age) => seedTime.subtract(age);
    // Mentions are real now: Sam's "@You" in Northbank 2009 and Tomas's
    // comment carry mention metadata, so they need no fixed item.
    _seeded = [
      ActivityItem(
        id: 'seed-event-changed-cycling',
        kind: ActivityKind.eventChanged,
        at: ago(const Duration(hours: 6)),
        text:
            'Mira (co-host) moved the meeting point for Take the long way '
            'home',
        groupId: 'club',
        target: const ActivityTarget(ActivityTargetKind.event, 'cycling'),
      ),
      ActivityItem(
        id: 'seed-role-college',
        kind: ActivityKind.roleChange,
        at: ago(const Duration(days: 2)),
        text: 'Mira made you an admin of Northbank 2009',
        groupId: 'college',
        target: const ActivityTarget(ActivityTargetKind.group, 'college'),
      ),
      ActivityItem(
        id: 'seed-approved-cse',
        kind: ActivityKind.approved,
        at: ago(const Duration(days: 5)),
        text: 'Dev approved your request to join Computer science',
        target: const ActivityTarget(ActivityTargetKind.group, 'cse'),
      ),
    ];
  }
}
