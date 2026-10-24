import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';

void main() {
  test('return destinations allow known in-app paths only', () {
    for (final path in [
      '/home',
      '/chats',
      '/groups',
      '/events',
      '/you',
      '/groups/new',
      '/compose',
      '/compose?group=family',
      '/home/memory/table',
      '/home/memory/table/photos?index=2',
      '/chats/g/family',
      '/chats/new',
      '/chats/archived',
      '/chats/c/d-mira-you',
      '/chats/c/g-family/details',
      '/chats/reply/table',
      '/you/privacy',
      '/groups/g/local-1',
      '/groups/g/club/settings',
      '/groups/g/club/invite',
      '/invite/chapter-verse-preview',
      '/events/new',
      '/events/new?group=family',
      '/events/e/lunch',
      '/events/e/lunch/attendees',
      '/events/e/local-event-00000001/edit',
      '/activity',
      '/search',
      '/you/notifications',
      '/you/account',
      '/people/mira',
      '/groups/g/college/reports',
      '/groups/g/club/albums/ride-days',
      '/groups/g/club/albums/ride-days/photos?index=1',
    ]) {
      expect(circleReturnDestination(path), path, reason: path);
    }
  });

  test('return destinations reject external, malformed and unknown input', () {
    for (final input in [
      null,
      '',
      'home',
      'https://example.invalid/home',
      '//example.invalid/home',
      'javascript:alert(1)',
      r'/home\..\you',
      '/admin',
      '/groups/g/',
      '/groups/g/a/b',
      '/groups/g/club/delete',
      '/invite/a b',
      '/home/memory/%2E%2E',
      '/home/memory/table/photos/extra',
      '/home/memory/table/delete',
      '/events/e/',
      '/events/e/lunch/delete',
      '/events/e/lunch/attendees/extra',
      '/events/x/lunch',
      '/chats/c/',
      '/chats/c/a/b',
      '/chats/c/g-family/delete',
      '/chats/reply/a b',
      '/you/privacy/extra',
      '/people/',
      '/people/a/b',
      '/groups/g/club/albums/',
      '/groups/g/club/albums/a/b',
      '/groups/g/club/reports/x',
      '/activity/x',
    ]) {
      expect(circleReturnDestination(input), isNull, reason: '$input');
    }
  });

  test('only branch roots hide the back button', () {
    for (final root in ['/home', '/chats', '/groups', '/events', '/you']) {
      expect(circleIsDetailPath(root), isFalse, reason: root);
    }
    for (final detail in [
      '/home/memory/table',
      '/home/memory/table/photos',
      '/groups/g/family',
      '/groups/g/family/settings',
      '/groups/new',
      '/chats/g/family',
      '/chats/new',
      '/chats/c/d-mira-you',
      '/chats/c/d-mira-you/details',
      '/you/privacy',
      '/you/notifications',
      '/groups/g/club/albums/ride-days',
      '/events/new',
      '/events/e/lunch',
      '/events/e/lunch/attendees',
    ]) {
      expect(circleIsDetailPath(detail), isTrue, reason: detail);
    }
  });
}
