import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/route_policy.dart';

void main() {
  test('protected destinations survive invitation with query and fragment', () {
    final original = Uri.parse('/post/courtyard?view=comments#discussion');
    final invitation = Uri.parse(
      invitationRedirect(entered: false, location: original)!,
    );
    expect(invitation.path, '/invite');
    expect(invitation.queryParameters['next'], original.toString());
    expect(
      invitationRedirect(entered: true, location: invitation),
      original.toString(),
    );
  });
  test('public routes and entered protected routes do not loop', () {
    for (final path in ['/', '/invite']) {
      expect(
        invitationRedirect(entered: false, location: Uri.parse(path)),
        isNull,
      );
      expect(
        invitationRedirect(entered: true, location: Uri.parse(path)),
        '/feed',
      );
    }
    expect(
      invitationRedirect(entered: true, location: Uri.parse('/feed')),
      isNull,
    );
    expect(
      invitationRedirect(entered: false, location: Uri.parse('/missing')),
      '/invite',
    );
  });
  for (final destination in [
    'https://example.com/feed',
    '//example.com/feed',
    'javascript:alert(1)',
    '/invite?next=/invite',
    '/',
    '/unknown',
    '/post/',
    '/post/a/b',
    '/post/%2Fprivate',
    '/feed/../invite',
    r'/feed\example.com',
  ]) {
    test('unsafe or unknown return destination is rejected: $destination', () {
      expect(safeReturnDestination(destination), isNull);
      final invitation = Uri(
        path: '/invite',
        queryParameters: {'next': destination},
      );
      expect(invitationRedirect(entered: true, location: invitation), '/feed');
    });
  }
  test('all supported private routes may resume', () {
    for (final path in [
      '/feed',
      '/create',
      '/groups',
      '/memories',
      '/friends',
      '/events',
      '/profile',
      '/post/courtyard',
      '/group/theatre',
      '/album/campus',
      '/friend/mira',
      '/event/twenty',
    ]) {
      expect(safeReturnDestination(path), path);
    }
  });
}
