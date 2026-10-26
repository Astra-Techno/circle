import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/invite_entry.dart';

void main() {
  final origin = Uri.parse('https://circle.example/api/v1');
  test(
    'supports custom and configured HTTPS invites, preserving token case',
    () {
      for (final input in [
        'circle://invite/AbC_def-123',
        'https://circle.example/i/AbC_def-123',
      ]) {
        expect(
          circleInviteDestination(Uri.parse(input), serverOrigin: origin),
          '/invite/AbC_def-123',
        );
      }
    },
  );
  test(
    'rejects untrusted hosts, credentials, extra paths and unsafe tokens',
    () {
      for (final input in [
        'https://other.example/i/token',
        'http://circle.example/i/token',
        'https://circle.example:444/i/token',
        'circle://other/token',
        'circle://invite/token/extra',
        'circle://invite/token?next=/home',
        'circle://user@invite/token',
        'circle://invite/token#fragment',
        'circle://invite/a%2Fb',
        'circle://invite/a%5Cb',
        'circle://invite/',
        'circle://invite/${'a' * 129}',
      ]) {
        expect(
          circleInviteDestination(Uri.parse(input), serverOrigin: origin),
          isNull,
          reason: input,
        );
      }
    },
  );
  test('HTTPS invites need an explicitly configured server', () {
    expect(
      circleInviteDestination(Uri.parse('https://circle.example/i/token')),
      isNull,
    );
  });
}
