import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/chat/domain/chat_models.dart' show ChatMute;
import 'package:mobile/features/notifications/data/mock_notification_repository.dart';
import 'package:mobile/features/notifications/domain/notification_repository.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

ActivityItem item(
  ActivityKind kind, {
  String id = 'item',
  String? groupId,
  DateTime? at,
}) => ActivityItem(
  id: id,
  kind: kind,
  at: at ?? fixed,
  text: kind.name,
  groupId: groupId,
  target: const ActivityTarget(ActivityTargetKind.invitations),
);

int minute(int hour, [int minute = 0]) => hour * 60 + minute;

({
  MockCircleRepository groups,
  MockChatRepository chat,
  MockNotificationRepository notifications,
})
setup({DateTime? now}) {
  DateTime clock() => now ?? fixed;
  final groups = MockCircleRepository(showcase: true, now: clock);
  final chat = MockChatRepository(groups: groups, showcase: true, now: clock);
  return (
    groups: groups,
    chat: chat,
    notifications: MockNotificationRepository(
      groups: groups,
      chat: chat,
      showcase: true,
      now: clock,
    ),
  );
}

void main() {
  group('NotificationRules', () {
    final defaults = NotificationSettings();

    test('personal types push by default; the rest go to the digest', () {
      for (final type in NotificationType.values) {
        expect(
          NotificationRules.pushOn(defaults, type),
          type.personal,
          reason: type.name,
        );
      }
      expect(
        NotificationRules.deliver(
          item(ActivityKind.directMessage),
          defaults,
          minuteOfDay: minute(12),
        ),
        Delivery.push,
      );
      expect(
        NotificationRules.deliver(
          item(ActivityKind.newMemory),
          defaults,
          minuteOfDay: minute(12),
        ),
        Delivery.digest,
      );
      expect(
        NotificationRules.deliver(
          item(ActivityKind.reactions),
          defaults.copyWith(digest: false),
          minuteOfDay: minute(12),
        ),
        Delivery.inbox,
      );
    });

    test('quiet hours default to 10 PM–7 AM and wrap past midnight', () {
      expect(defaults.quietHours, isTrue);
      bool quiet(int at, [NotificationSettings? settings]) =>
          NotificationRules.inQuietHours(settings ?? defaults, at);
      expect(quiet(minute(21, 59)), isFalse);
      expect(quiet(minute(22)), isTrue);
      expect(quiet(minute(23, 30)), isTrue);
      expect(quiet(minute(0)), isTrue);
      expect(quiet(minute(6, 59)), isTrue);
      expect(quiet(minute(7)), isFalse);
      expect(quiet(minute(12)), isFalse);
      // A same-day window.
      final afternoon = defaults.copyWith(
        quietStart: minute(13),
        quietEnd: minute(15),
      );
      expect(quiet(minute(14), afternoon), isTrue);
      expect(quiet(minute(15), afternoon), isFalse);
      expect(quiet(minute(23), afternoon), isFalse);
      // Off, or an empty window, is never quiet.
      expect(quiet(minute(23), defaults.copyWith(quietHours: false)), isFalse);
      expect(
        quiet(
          minute(23),
          defaults.copyWith(quietStart: minute(1), quietEnd: minute(1)),
        ),
        isFalse,
      );
      expect(
        NotificationRules.deliver(
          item(ActivityKind.mention),
          defaults,
          minuteOfDay: minute(23),
        ),
        Delivery.heldForQuietHours,
      );
    });

    test('groups over 50 members default to mentions only', () {
      expect(
        NotificationRules.levelFor(defaults, 'big', 57),
        GroupNotifyLevel.mentionsOnly,
      );
      expect(
        NotificationRules.levelFor(defaults, 'small', 50),
        GroupNotifyLevel.all,
      );
      final promoted = defaults.copyWith(
        push: {...defaults.push, NotificationType.newMemories: true},
      );
      Delivery deliver(
        ActivityKind kind,
        int members, [
        NotificationSettings? settings,
      ]) => NotificationRules.deliver(
        item(kind, groupId: 'g'),
        settings ?? promoted,
        minuteOfDay: minute(12),
        groupMembers: members,
      );
      expect(deliver(ActivityKind.newMemory, 10), Delivery.push);
      expect(deliver(ActivityKind.newMemory, 57), Delivery.digest);
      expect(deliver(ActivityKind.mention, 57), Delivery.push);
      expect(deliver(ActivityKind.eventChanged, 57), Delivery.push);
      final everything = promoted.copyWith(
        groupLevels: {'g': GroupNotifyLevel.all},
      );
      expect(deliver(ActivityKind.newMemory, 57, everything), Delivery.push);
    });

    test('a muted group or chat never pushes or badges', () {
      final muted = defaults.copyWith(
        groupLevels: {'g': GroupNotifyLevel.muted},
      );
      final delivery = NotificationRules.deliver(
        item(ActivityKind.mention, groupId: 'g'),
        muted,
        minuteOfDay: minute(12),
        groupMembers: 4,
      );
      expect(delivery, Delivery.muted);
      expect(NotificationRules.countsForBadge(delivery), isFalse);
      expect(
        NotificationRules.deliver(
          item(ActivityKind.directMessage),
          defaults,
          minuteOfDay: minute(12),
          chatMuted: true,
        ),
        Delivery.muted,
      );
      expect(NotificationRules.countsForBadge(Delivery.push), isTrue);
      expect(
        NotificationRules.countsForBadge(Delivery.heldForQuietHours),
        isTrue,
      );
      expect(NotificationRules.countsForBadge(Delivery.digest), isFalse);
    });

    test('time labels', () {
      expect(NotificationRules.timeLabel(minute(22)), '10:00 PM');
      expect(NotificationRules.timeLabel(minute(7)), '7:00 AM');
      expect(NotificationRules.timeLabel(minute(0, 5)), '12:05 AM');
      expect(NotificationRules.timeLabel(minute(12)), '12:00 PM');
    });
  });

  group('ActivityInboxRules', () {
    test('generation uses only what the viewer sees, batched', () async {
      final repository = MockCircleRepository(showcase: true, now: () => fixed);
      final id = await repository.createMemory('you', 'family', 'Our walk');
      await repository.react('mira', id, '❤️');
      await repository.react('dev', id, '😂');
      final comment = await repository.comment('mira', id, 'Lovely!');
      await repository.comment('dev', id, 'Agreed', replyTo: comment);
      final mine = await repository.comment('you', 'table', 'See you there');
      await repository.comment('mira', 'table', 'Yes!', replyTo: mine);
      final workspace = await repository.load('you');
      final items = ActivityInboxRules.generate(
        workspace: workspace,
        now: fixed.add(const Duration(minutes: 1)),
      );
      final kinds = {for (final item in items) item.id: item.kind};
      // One batched line for both reactions.
      final batch = items.where((i) => i.kind == ActivityKind.reactions);
      expect(batch.single.text, '2 people reacted to your Memory “Our walk”');
      expect(kinds['reply:$comment'], ActivityKind.reply);
      expect(
        items.where((i) => i.kind == ActivityKind.reply).length,
        2,
        reason: 'a comment on your Memory and a reply to your comment',
      );
      expect(kinds.keys, contains('invite:invite-cousins'));
      expect(kinds.keys, contains('join:request-arjun-family'));
      expect(kinds.keys, contains('memory:table'));
      expect(kinds.keys, isNot(contains('memory:private-memory')));
      expect(kinds.keys, contains('poll-closing:reunion-poll-poll'));
      expect(kinds.keys, contains('poll-results:route-poll-poll'));
      // Newest first.
      for (var i = 1; i < items.length; i++) {
        expect(items[i - 1].at.isBefore(items[i].at), isFalse);
      }
    });

    test('event changes and cancellations reach people who answered', () async {
      final repository = MockCircleRepository(showcase: true, now: () => fixed);
      await repository.rsvp('you', 'lunch', const Rsvp(Attendance.going));
      await repository.cancelEvent('mira', 'lunch');
      final items = ActivityInboxRules.generate(
        workspace: await repository.load('you'),
        now: fixed,
      );
      expect(
        items.where((i) => i.id == 'cancelled:lunch').single.kind,
        ActivityKind.eventCancelled,
      );
      // Noor isn't in the family group, so nothing about it reaches her.
      final noor = ActivityInboxRules.generate(
        workspace: await repository.load('noor'),
        now: fixed,
      );
      expect(noor.any((i) => i.id == 'cancelled:lunch'), isFalse);
    });

    test('tap-through respects exact-group access', () async {
      final repository = MockCircleRepository(showcase: true, now: () => fixed);
      final workspace = await repository.load('you');
      String? go(ActivityTargetKind kind, String id) =>
          ActivityInboxRules.location(
            ActivityTarget(kind, id),
            workspace,
            conversations: {'d-mira-you'},
          );
      expect(go(ActivityTargetKind.memory, 'table'), '/home/memory/table');
      expect(go(ActivityTargetKind.memory, 'private-memory'), isNull);
      expect(go(ActivityTargetKind.event, 'surprise'), isNull);
      expect(go(ActivityTargetKind.group, 'college'), '/groups/g/college');
      expect(go(ActivityTargetKind.group, 'private-plans'), isNull);
      expect(
        go(ActivityTargetKind.conversation, 'd-mira-you'),
        '/chats/c/d-mira-you',
      );
      expect(go(ActivityTargetKind.conversation, 'd-dev-you'), isNull);
    });
  });

  group('MockNotificationRepository', () {
    test('badge counts only unread items that need the person', () async {
      final s = setup();
      final feed = await s.notifications.activity('you');
      final badged = {
        for (final entry in feed.entries)
          if (entry.badged) entry.item.id,
      };
      expect(badged, contains('mention:college-mention'), reason: 'mention');
      expect(badged, contains('invite:invite-cousins'));
      expect(badged, contains('join:request-arjun-family'));
      expect(badged, contains('request:d-kavya-you'));
      expect(badged.any((id) => id.startsWith('dm:d-dev-you')), isTrue);
      expect(badged, isNot(contains('memory:table')), reason: 'digest');
      expect(badged, isNot(contains('seed-role-college')));
      expect(feed.badge, badged.length);
      expect(feed.unread, feed.entries.length);
    });

    test('read state: one item, then all', () async {
      final s = setup();
      final before = await s.notifications.activity('you');
      await s.notifications.markRead('you', 'mention:college-mention');
      final after = await s.notifications.activity('you');
      expect(after.badge, before.badge - 1);
      await s.notifications.markAllRead('you');
      final cleared = await s.notifications.activity('you');
      expect(cleared.badge, 0);
      expect(cleared.unread, 0);
    });

    test('settings change badge classification', () async {
      final s = setup();
      final before = (await s.notifications.activity('you')).badge;
      // New Memories become pushes; Northbank 2009 (57) stays mentions-only.
      await s.notifications.setPush('you', NotificationType.newMemories, true);
      var feed = await s.notifications.activity('you');
      Delivery of(String id) =>
          feed.entries.firstWhere((e) => e.item.id == id).delivery;
      expect(of('memory:table'), Delivery.push);
      expect(of('memory:reunion-poll'), Delivery.digest);
      final promoted = feed.badge;
      expect(promoted, greaterThan(before));
      await s.notifications.setGroupLevel(
        'you',
        'college',
        GroupNotifyLevel.all,
      );
      feed = await s.notifications.activity('you');
      expect(of('memory:reunion-poll'), Delivery.push);
      await s.notifications.setGroupLevel(
        'you',
        'family',
        GroupNotifyLevel.muted,
      );
      feed = await s.notifications.activity('you');
      expect(of('memory:table'), Delivery.muted);
      expect(of('join:request-arjun-family'), Delivery.muted);
      await expectLater(
        s.notifications.setGroupLevel(
          'you',
          'private-plans',
          GroupNotifyLevel.all,
        ),
        throwsA(isA<CircleFailure>()),
      );
    });

    test('a chat the person muted stops its DM badge', () async {
      final s = setup();
      await s.chat.mute('you', 'd-dev-you', ChatMute.always);
      final feed = await s.notifications.activity('you');
      final dm = feed.entries.firstWhere(
        (e) => e.item.id.startsWith('dm:d-dev-you'),
      );
      expect(dm.delivery, Delivery.muted);
      expect(dm.badged, isFalse);
      final view = await s.notifications.settings('you');
      expect(view.mutedChats.map((c) => c.id), contains('d-dev-you'));
      final college = view.mutedChats.firstWhere((c) => c.id == 'g-college');
      expect(college.mutedByDefault, isTrue);
      expect(
        view.groups.firstWhere((g) => g.group.id == 'college').level,
        GroupNotifyLevel.mentionsOnly,
      );
    });

    test('quiet hours hold pushes but still badge in the app', () async {
      // 23:30 local on the test machine's clock.
      final late = DateTime(2026, 10, 23, 23, 30);
      final s = setup(now: late);
      final feed = await s.notifications.activity('you');
      final mention = feed.entries.firstWhere(
        (e) => e.item.id == 'mention:college-mention',
      );
      expect(mention.delivery, Delivery.heldForQuietHours);
      expect(mention.badged, isTrue);
      await s.notifications.setQuietHours('you', enabled: false);
      final loud = await s.notifications.activity('you');
      expect(
        loud.entries
            .firstWhere((e) => e.item.id == 'mention:college-mention')
            .delivery,
        Delivery.push,
      );
      await expectLater(
        s.notifications.setQuietHours('you', start: 24 * 60),
        throwsA(isA<CircleFailure>()),
      );
    });

    test('reset clears read state and settings', () async {
      final s = setup();
      await s.notifications.markAllRead('you');
      await s.notifications.setPush('you', NotificationType.reactions, true);
      await s.notifications.reset(showcase: true);
      expect((await s.notifications.activity('you')).badge, greaterThan(0));
      expect(
        (await s.notifications.settings(
          'you',
        )).settings.push[NotificationType.reactions],
        isFalse,
      );
    });
  });
}
