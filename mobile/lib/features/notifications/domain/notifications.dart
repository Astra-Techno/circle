/// Activity inbox and notification settings (README §3.7, §4.0, I1, H4).
/// Pure Dart; no Flutter imports.
library;

import '../../chat/domain/chat_models.dart';
import '../../workspace/domain/circle_workspace.dart';

/// The person-facing notification types (H4). Personal types push by
/// default; everything else goes to the inbox or the daily digest.
enum NotificationType {
  directMessages('Direct messages and requests', personal: true),
  mentionsAndReplies('Mentions and replies to you', personal: true),
  yourEvents('Changes and reminders for your events', personal: true),
  invitationsAndApprovals('Invitations and approvals', personal: true),
  joinRequests('Join requests (groups you run)', personal: true),
  newMemories('New Memories in your groups'),
  reactions('Reactions to your Memories'),
  newEventsAndPolls('New events and polls'),
  pollResults('Poll results'),
  roleChanges('Role changes');

  const NotificationType(this.label, {this.personal = false});
  final String label;

  /// Pushed by default (README §3.7). The rest is inbox/digest by default.
  final bool personal;
}

/// What happened, for one activity item.
enum ActivityKind {
  reply(NotificationType.mentionsAndReplies, aboutYou: true),
  mention(NotificationType.mentionsAndReplies, aboutYou: true),
  reactions(NotificationType.reactions),
  newMemory(NotificationType.newMemories),
  invitation(NotificationType.invitationsAndApprovals, aboutYou: true),
  approved(NotificationType.invitationsAndApprovals, aboutYou: true),
  declined(NotificationType.invitationsAndApprovals, aboutYou: true),
  joinRequest(NotificationType.joinRequests, aboutYou: true),
  eventChanged(NotificationType.yourEvents, aboutYou: true),
  eventCancelled(NotificationType.yourEvents, aboutYou: true),
  eventReminder(NotificationType.yourEvents, aboutYou: true),
  newEvent(NotificationType.newEventsAndPolls),
  pollClosing(NotificationType.newEventsAndPolls),
  pollResults(NotificationType.pollResults),
  roleChange(NotificationType.roleChanges),
  messageRequest(NotificationType.directMessages, aboutYou: true),
  directMessage(NotificationType.directMessages, aboutYou: true);

  const ActivityKind(this.type, {this.aboutYou = false});
  final NotificationType type;

  /// Addressed to the person (a mention, a reply, their RSVP, their
  /// request…). Big groups in "mentions only" still let these through.
  final bool aboutYou;
}

enum ActivityTargetKind { memory, event, group, invitations, conversation }

/// Where tapping an item goes.
class ActivityTarget {
  const ActivityTarget(this.kind, [this.id = '']);
  final ActivityTargetKind kind;
  final String id;
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.at,
    required this.text,
    required this.target,
    this.groupId,
    this.conversationId,
  });

  /// Stable: the same thing always gets the same id, so read state holds.
  final String id;
  final ActivityKind kind;
  final DateTime at;

  /// One plain sentence: "Priya invited you to Cousins’ corner".
  final String text;
  final ActivityTarget target;

  /// The group it happened in (for group notification levels).
  final String? groupId;

  /// The chat it happened in (for chat mutes).
  final String? conversationId;
}

/// How much a group may notify (H4). Big groups default to mentions only.
enum GroupNotifyLevel {
  all('Everything'),
  mentionsOnly('Mentions and replies only'),
  muted('Nothing');

  const GroupNotifyLevel(this.label);
  final String label;
}

/// What would happen to an item if this were a real app.
enum Delivery {
  /// Sent as a push notification now.
  push,

  /// A push held until quiet hours end (shown in the app right away).
  heldForQuietHours,

  /// In the inbox and the daily digest.
  digest,

  /// In the inbox only (digest off).
  inbox,

  /// Muted: in the inbox, never pushed, never counted.
  muted,
}

class NotificationSettings {
  NotificationSettings({
    Map<NotificationType, bool> push = const {},
    this.quietHours = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
    this.digest = true,
    this.digestAt = 18 * 60,
    Map<String, GroupNotifyLevel> groupLevels = const {},
  }) : push = Map.unmodifiable({
         for (final type in NotificationType.values)
           type: push[type] ?? type.personal,
       }),
       groupLevels = Map.unmodifiable(groupLevels);

  /// Whether each type is pushed (personal types by default).
  final Map<NotificationType, bool> push;

  /// Quiet hours (on by default, 10 PM–7 AM local), as minutes after
  /// midnight. The window may wrap past midnight.
  final bool quietHours;
  final int quietStart, quietEnd;

  /// The daily digest (on by default) and its time, minutes after midnight.
  final bool digest;
  final int digestAt;

  /// Explicit per-group choices; groups without one use the size default.
  final Map<String, GroupNotifyLevel> groupLevels;

  NotificationSettings copyWith({
    Map<NotificationType, bool>? push,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
    bool? digest,
    int? digestAt,
    Map<String, GroupNotifyLevel>? groupLevels,
  }) => NotificationSettings(
    push: push ?? this.push,
    quietHours: quietHours ?? this.quietHours,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    digest: digest ?? this.digest,
    digestAt: digestAt ?? this.digestAt,
    groupLevels: groupLevels ?? this.groupLevels,
  );
}

/// Pure notification rules (README §3.7 and the calm rules in §4.0).
abstract final class NotificationRules {
  /// Groups bigger than this start at "mentions only".
  static const quietGroupAbove = 50;

  static bool pushOn(NotificationSettings settings, NotificationType type) =>
      settings.push[type] ?? type.personal;

  /// Whether [minuteOfDay] (local, 0–1439) falls in quiet hours. Handles
  /// windows that wrap past midnight (22:00–07:00). An empty window
  /// (start == end) is never quiet.
  static bool inQuietHours(NotificationSettings settings, int minuteOfDay) {
    if (!settings.quietHours) return false;
    final start = settings.quietStart, end = settings.quietEnd;
    if (start == end) return false;
    return start < end
        ? minuteOfDay >= start && minuteOfDay < end
        : minuteOfDay >= start || minuteOfDay < end;
  }

  /// The group's level: the person's choice, else "mentions only" for
  /// groups over 50 members and "everything" otherwise.
  static GroupNotifyLevel levelFor(
    NotificationSettings settings,
    String groupId,
    int memberCount,
  ) =>
      settings.groupLevels[groupId] ??
      (memberCount > quietGroupAbove
          ? GroupNotifyLevel.mentionsOnly
          : GroupNotifyLevel.all);

  /// How [item] would be delivered. [groupMembers] is the size of the
  /// item's group when the person is in it; [chatMuted] is a mute the
  /// person chose on the item's chat.
  static Delivery deliver(
    ActivityItem item,
    NotificationSettings settings, {
    required int minuteOfDay,
    int? groupMembers,
    bool chatMuted = false,
  }) {
    if (chatMuted) return Delivery.muted;
    var mayPush = pushOn(settings, item.kind.type);
    final groupId = item.groupId;
    if (groupId != null && groupMembers != null) {
      switch (levelFor(settings, groupId, groupMembers)) {
        case GroupNotifyLevel.muted:
          return Delivery.muted;
        case GroupNotifyLevel.mentionsOnly:
          if (!item.kind.aboutYou) mayPush = false;
        case GroupNotifyLevel.all:
          break;
      }
    }
    if (mayPush) {
      return inQuietHours(settings, minuteOfDay)
          ? Delivery.heldForQuietHours
          : Delivery.push;
    }
    return settings.digest ? Delivery.digest : Delivery.inbox;
  }

  /// Badges mean something: only what would reach the person directly.
  static bool countsForBadge(Delivery delivery) =>
      delivery == Delivery.push || delivery == Delivery.heldForQuietHours;

  /// "10:00 PM".
  static String timeLabel(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60, minute = minuteOfDay % 60;
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Pure generation of the activity inbox from what the viewer can see.
abstract final class ActivityInboxRules {
  /// How far back informational items reach.
  static const recent = Duration(hours: 72);

  /// Builds the items for [workspace] (and [inbox] and the readable chat
  /// [messages], when chat is loaded), newest first. Only things the
  /// viewer can already see are used, so nothing leaks; [seeded] are fixed
  /// fictional items.
  static List<ActivityItem> generate({
    required CircleWorkspace workspace,
    required DateTime now,
    ChatInbox? inbox,
    List<ReadableMessage> messages = const [],
    List<ActivityItem> seeded = const [],
  }) {
    final viewer = workspace.viewer;
    final items = <ActivityItem>[...seeded];
    String group(String id) => workspace.group(id)?.name ?? 'a group';
    bool isRecent(DateTime at) =>
        !at.isAfter(now) && now.difference(at) < recent;

    for (final invitation in workspace.invitations) {
      items.add(
        ActivityItem(
          id: 'invite:${invitation.invitation.id}',
          kind: ActivityKind.invitation,
          at: invitation.invitation.createdAt,
          text:
              '${invitation.inviterName} invited you to ${invitation.groupName}',
          target: const ActivityTarget(ActivityTargetKind.invitations),
        ),
      );
    }
    for (final request in workspace.joinRequests) {
      items.add(
        ActivityItem(
          id: 'join:${request.id}',
          kind: ActivityKind.joinRequest,
          at: request.createdAt,
          text:
              '${workspace.nameOf(request.person)} asked to join '
              '${group(request.groupId)}',
          groupId: request.groupId,
          target: ActivityTarget(ActivityTargetKind.group, request.groupId),
        ),
      );
    }

    for (final memory in workspace.memories) {
      final mine = memory.authorId == viewer;
      final about = memory.summary.length > 40
          ? '${memory.summary.substring(0, 39)}…'
          : memory.summary;
      // "@You" in a comment: a mention (personal), never from yourself.
      final mentioned = {
        for (final comment in memory.comments)
          if (MentionRules.recipients(
            comment.mentions,
            comment.authorId,
          ).contains(viewer))
            comment.id,
      };
      for (final comment in memory.comments) {
        if (!mentioned.contains(comment.id)) continue;
        items.add(
          ActivityItem(
            id: 'mention:${comment.id}',
            kind: ActivityKind.mention,
            at: comment.createdAt,
            text:
                '${comment.authorName} mentioned you in a comment: '
                '“${_short(comment.text)}”',
            groupId: memory.groupId,
            target: ActivityTarget(ActivityTargetKind.memory, memory.id),
          ),
        );
      }
      if (mine) {
        // Comments on your Memory.
        for (final comment in memory.comments) {
          if (comment.authorId == viewer ||
              comment.isReply ||
              mentioned.contains(comment.id)) {
            continue;
          }
          items.add(
            ActivityItem(
              id: 'reply:${comment.id}',
              kind: ActivityKind.reply,
              at: comment.createdAt,
              text:
                  '${comment.authorName} commented on your Memory: '
                  '“${comment.text}”',
              groupId: memory.groupId,
              target: ActivityTarget(ActivityTargetKind.memory, memory.id),
            ),
          );
        }
        // Reactions are batched into one line per Memory.
        final others =
            memory.reactions.total - (memory.reactions.mine == null ? 0 : 1);
        if (others > 0) {
          items.add(
            ActivityItem(
              id: 'reactions:${memory.id}:$others',
              kind: ActivityKind.reactions,
              at: memory.createdAt,
              text: others == 1
                  ? '1 person reacted to your Memory “$about”'
                  : '$others people reacted to your Memory “$about”',
              groupId: memory.groupId,
              target: ActivityTarget(ActivityTargetKind.memory, memory.id),
            ),
          );
        }
      } else if (isRecent(memory.createdAt)) {
        items.add(
          ActivityItem(
            id: 'memory:${memory.id}',
            kind: ActivityKind.newMemory,
            at: memory.createdAt,
            text:
                '${memory.author} shared a Memory in ${group(memory.groupId)}',
            groupId: memory.groupId,
            target: ActivityTarget(ActivityTargetKind.memory, memory.id),
          ),
        );
      }
      // Replies to your comments, on anyone's Memory.
      final yours = {
        for (final comment in memory.comments)
          if (comment.authorId == viewer) comment.id,
      };
      for (final reply in memory.comments) {
        if (reply.authorId == viewer ||
            !yours.contains(reply.parentId) ||
            mentioned.contains(reply.id)) {
          continue;
        }
        items.add(
          ActivityItem(
            id: 'reply:${reply.id}',
            kind: ActivityKind.reply,
            at: reply.createdAt,
            text:
                '${reply.authorName} replied to your comment: '
                '“${reply.text}”',
            groupId: memory.groupId,
            target: ActivityTarget(ActivityTargetKind.memory, memory.id),
          ),
        );
      }
      final poll = memory.poll;
      if (poll != null) {
        final closesAt = poll.closesAt;
        if (!poll.closed &&
            closesAt != null &&
            closesAt.isAfter(now) &&
            closesAt.difference(now) <= recent) {
          final start = closesAt.subtract(recent);
          items.add(
            ActivityItem(
              id: 'poll-closing:${poll.id}',
              kind: ActivityKind.pollClosing,
              at: start.isAfter(memory.createdAt) ? start : memory.createdAt,
              text:
                  'Poll closing soon in ${group(memory.groupId)}: '
                  '${poll.question}',
              groupId: memory.groupId,
              target: ActivityTarget(ActivityTargetKind.memory, memory.id),
            ),
          );
        } else if (poll.closed &&
            poll.resultsVisible &&
            now.difference(memory.createdAt) <= const Duration(days: 7)) {
          items.add(
            ActivityItem(
              id: 'poll-results:${poll.id}',
              kind: ActivityKind.pollResults,
              at: closesAt != null && !closesAt.isAfter(now)
                  ? closesAt
                  : memory.createdAt,
              text: 'Results are in: ${poll.question}',
              groupId: memory.groupId,
              target: ActivityTarget(ActivityTargetKind.memory, memory.id),
            ),
          );
        }
      }
    }

    for (final event in workspace.events) {
      final answer = event.rsvpOf(viewer)?.status;
      final yours =
          event.hosts.contains(viewer) ||
          answer == Attendance.going ||
          answer == Attendance.maybe;
      if (yours && event.createdBy != viewer) {
        final cancelledAt = event.cancelledAt;
        final editedAt = event.editedAt;
        if (cancelledAt != null) {
          items.add(
            ActivityItem(
              id: 'cancelled:${event.id}',
              kind: ActivityKind.eventCancelled,
              at: cancelledAt,
              text: '${event.title} was cancelled',
              groupId: event.groupId,
              target: ActivityTarget(ActivityTargetKind.event, event.id),
            ),
          );
        } else if (editedAt != null) {
          items.add(
            ActivityItem(
              id: 'changed:${event.id}:${editedAt.millisecondsSinceEpoch}',
              kind: ActivityKind.eventChanged,
              at: editedAt,
              text: '${event.title} was updated. Check the new details.',
              groupId: event.groupId,
              target: ActivityTarget(ActivityTargetKind.event, event.id),
            ),
          );
        }
      }
      final untilStart = event.startsAt.difference(now);
      if (yours &&
          !event.cancelled &&
          !untilStart.isNegative &&
          untilStart <= const Duration(hours: 24)) {
        items.add(
          ActivityItem(
            id: 'reminder:${event.id}',
            kind: ActivityKind.eventReminder,
            at: event.startsAt.subtract(const Duration(hours: 24)),
            text: 'Tomorrow or sooner: ${event.title}',
            groupId: event.groupId,
            target: ActivityTarget(ActivityTargetKind.event, event.id),
          ),
        );
      }
      if (!yours && event.createdBy != viewer && isRecent(event.createdAt)) {
        items.add(
          ActivityItem(
            id: 'event:${event.id}',
            kind: ActivityKind.newEvent,
            at: event.createdAt,
            text:
                '${workspace.nameOf(event.createdBy)} planned ${event.title} '
                'in ${group(event.groupId)}',
            groupId: event.groupId,
            target: ActivityTarget(ActivityTargetKind.event, event.id),
          ),
        );
      }
    }

    // "@You" in a group chat you can read (blocked people's messages and
    // anything after you left are already left out).
    for (final message in messages) {
      if (message.authorId == viewer || !message.mentions.contains(viewer)) {
        continue;
      }
      items.add(
        ActivityItem(
          id: 'mention:${message.messageId}',
          kind: ActivityKind.mention,
          at: message.at,
          text:
              '${message.authorName} mentioned you in '
              '${message.conversationTitle}: “${_short(message.text)}”',
          groupId: message.groupId,
          conversationId: message.conversationId,
          target: ActivityTarget(
            ActivityTargetKind.conversation,
            message.conversationId,
          ),
        ),
      );
    }

    if (inbox != null) {
      for (final request in inbox.requests) {
        items.add(
          ActivityItem(
            id: 'request:${request.id}',
            kind: ActivityKind.messageRequest,
            at: request.lastActivity ?? now,
            text: '${request.title} wants to send you a message',
            conversationId: request.id,
            target: ActivityTarget(ActivityTargetKind.conversation, request.id),
          ),
        );
      }
      for (final chat in [...inbox.chats, ...inbox.archived]) {
        final last = chat.lastActivity;
        if (chat.isGroup || !chat.unread || last == null) continue;
        items.add(
          ActivityItem(
            id: 'dm:${chat.id}:${last.millisecondsSinceEpoch}',
            kind: ActivityKind.directMessage,
            at: last,
            text: '${chat.title} sent you a message',
            conversationId: chat.id,
            target: ActivityTarget(ActivityTargetKind.conversation, chat.id),
          ),
        );
      }
    }

    final unique = <String, ActivityItem>{
      for (final item in items) item.id: item,
    };
    return unique.values.where((item) => !item.at.isAfter(now)).toList()
      ..sort((a, b) {
        final order = b.at.compareTo(a.at);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
  }

  /// A quote short enough for one Activity line.
  static String _short(String text) {
    final value = text.trim();
    return value.runes.length <= 80
        ? value
        : '${String.fromCharCodes(value.runes.take(79))}…';
  }

  /// Where tapping [target] goes, or null when the viewer can no longer
  /// open it (left the group, deleted, hidden). Exact-group access only.
  static String? location(
    ActivityTarget target,
    CircleWorkspace workspace, {
    Set<String> conversations = const {},
  }) => switch (target.kind) {
    ActivityTargetKind.memory =>
      workspace.memories.any((memory) => memory.id == target.id)
          ? '/home/memory/${target.id}'
          : null,
    ActivityTargetKind.event =>
      workspace.event(target.id) == null ? null : '/events/e/${target.id}',
    ActivityTargetKind.group =>
      workspace.group(target.id) == null ? null : '/groups/g/${target.id}',
    ActivityTargetKind.invitations => '/groups',
    ActivityTargetKind.conversation =>
      conversations.contains(target.id) ? '/chats/c/${target.id}' : null,
  };

  /// Today (same local day as [now]) or earlier.
  static bool isToday(DateTime at, DateTime now) {
    final a = at.toLocal(), b = now.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// One item with its read state and how it would be delivered.
class ActivityEntry {
  const ActivityEntry({
    required this.item,
    required this.read,
    required this.delivery,
  });
  final ActivityItem item;
  final bool read;
  final Delivery delivery;

  /// Counts toward the bell's badge: unread and something that needs you.
  bool get badged => !read && NotificationRules.countsForBadge(delivery);
}

class ActivityFeed {
  ActivityFeed({required List<ActivityEntry> entries})
    : entries = List.unmodifiable(entries);
  final List<ActivityEntry> entries;
  int get badge => entries.where((entry) => entry.badged).length;
  int get unread => entries.where((entry) => !entry.read).length;
}

/// A group in the settings list, with its effective level.
class GroupNotifyChoice {
  const GroupNotifyChoice({
    required this.group,
    required this.level,
    required this.isDefault,
  });
  final CircleGroup group;
  final GroupNotifyLevel level;
  final bool isDefault;
}

class NotificationSettingsView {
  NotificationSettingsView({
    required this.settings,
    required List<GroupNotifyChoice> groups,
    required List<ConversationSummary> mutedChats,
  }) : groups = List.unmodifiable(groups),
       mutedChats = List.unmodifiable(mutedChats);
  final NotificationSettings settings;
  final List<GroupNotifyChoice> groups;

  /// Muted chats, including big groups that are quiet by default.
  final List<ConversationSummary> mutedChats;
}
