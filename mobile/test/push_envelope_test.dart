import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';

final now = DateTime.utc(2026, 10, 27, 5);
final scope = PushScope(
  server: 'https://fictional.example/api/v1',
  account: '7',
  sessionHash: 'b' * 64,
);
Map<String, dynamic> envelope([PushScope? selected]) {
  final s = selected ?? scope;
  return {
    'event_id': 'a' * 64,
    'type': 'memory.created',
    'api_base_url': s.server,
    'recipient_id': s.account,
    'session_scope': s.sessionHash,
    'group_id': '3',
    'memory_id': '4',
    'comment_id': '',
    'expires_at': '${now.millisecondsSinceEpoch ~/ 1000 + 3600}',
  };
}

String jwt(Map<String, Object?> claims) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.fictional-signature';

class FailingStore extends MemoryLocalSettingsStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('Fictional storage failure');
}

void main() {
  test('validates strict current scope, type, IDs and expiry', () {
    final parsed = PushEnvelope.parse(envelope(), scope, now)!;
    expect(parsed.memoryId, '4');
    expect(parsed.belongsTo(scope, now), isTrue);
    for (final change in [
      {'api_base_url': 'https://untrusted.example/api/v1'},
      {'recipient_id': '8'},
      {'session_scope': 'c' * 64},
      {'event_id': 'x' * 64},
      {'memory_id': 4},
      {'memory_id': '0'},
      {'memory_id': '18446744073709551616'},
      {'group_id': '03'},
      {'type': 'arbitrary.route'},
      {'comment_id': '2'},
      {'expires_at': '${now.millisecondsSinceEpoch ~/ 1000}'},
      {'expires_at': '${now.millisecondsSinceEpoch ~/ 1000 + 90000}'},
      {'expires_at': '1e20'},
      {'route': 'https://untrusted.example'},
      {'body': 'Private text'},
    ]) {
      expect(
        PushEnvelope.parse({...envelope(), ...change}, scope, now),
        isNull,
        reason: change.keys.join(),
      );
    }
    final missing = envelope()..remove('group_id');
    expect(PushEnvelope.parse(missing, scope, now), isNull);
    expect(
      PushEnvelope.parse(
        {...envelope(), 'type': 'comment.reply', 'comment_id': '9'},
        scope,
        now,
      ),
      isNotNull,
    );
    expect(
      PushEnvelope.parse({...envelope(), 'type': 'comment.reply'}, scope, now),
      isNull,
    );
    expect(parsed.belongsTo(scope, now.add(const Duration(hours: 2))), isFalse);
  });

  test(
    'derives scope from stored access-token claims without claiming authentication',
    () {
      final sid = 'c' * 32;
      final token = jwt({'sub': 7, 'sid': sid, 'type': 'access', 'exp': 1});
      final derived = PushScope.fromAccessToken(
        server: scope.server,
        account: '7',
        token: token,
      )!;
      expect(derived.sessionHash, sha256.convert(utf8.encode(sid)).toString());
      expect(
        PushScope.fromAccessToken(
          server: scope.server,
          account: '8',
          token: token,
        ),
        isNull,
      );
      expect(
        PushScope.fromAccessToken(
          server: 'http://fictional.example/api/v1',
          account: '7',
          token: token,
        ),
        isNull,
      );
      for (final invalid in [
        'bad',
        'header.%%%.sig',
        jwt({'sub': 7, 'sid': 'bad', 'type': 'access'}),
        jwt({'sub': 7, 'sid': sid, 'type': 'refresh'}),
      ]) {
        expect(
          PushScope.fromAccessToken(
            server: scope.server,
            account: '7',
            token: invalid,
          ),
          isNull,
        );
      }
    },
  );

  test(
    'persistent serialized dedup scopes display separately from opening',
    () async {
      final store = MemoryLocalSettingsStore(),
          parsed = PushEnvelope.parse(envelope(), scope, now)!;
      final ledger = PushLedger(store);
      final claims = await Future.wait(
        List.generate(10, (_) => ledger.claim(parsed, PushAction.display, now)),
      );
      expect(claims.where((x) => x).length, 1);
      expect(
        await PushLedger(store).claim(parsed, PushAction.display, now),
        isFalse,
      );
      expect(await ledger.claim(parsed, PushAction.open, now), isTrue);
      expect(await ledger.claim(parsed, PushAction.open, now), isFalse);
      for (final other in [
        PushScope(
          server: scope.server,
          account: '8',
          sessionHash: scope.sessionHash,
        ),
        PushScope(
          server: 'https://other.example/api/v1',
          account: scope.account,
          sessionHash: scope.sessionHash,
        ),
        PushScope(
          server: scope.server,
          account: scope.account,
          sessionHash: 'd' * 64,
        ),
      ]) {
        expect(
          await ledger.claim(
            PushEnvelope.parse(envelope(other), other, now)!,
            PushAction.display,
            now,
          ),
          isTrue,
        );
      }
      expect(store.values.keys.any((key) => key.contains('https://')), isFalse);
    },
  );

  test(
    'capacity and storage failures fail closed; expiry frees capacity',
    () async {
      final store = MemoryLocalSettingsStore();
      final ledger = PushLedger(store, capacity: 1);
      final parsed = PushEnvelope.parse(envelope(), scope, now)!;
      expect(await ledger.claim(parsed, PushAction.display, now), isTrue);
      expect(await ledger.claim(parsed, PushAction.open, now), isFalse);
      final later = now.add(const Duration(hours: 2));
      final fresh = PushEnvelope.parse(
        {
          ...envelope(),
          'expires_at': '${later.millisecondsSinceEpoch ~/ 1000 + 300}',
        },
        scope,
        later,
      )!;
      expect(await ledger.claim(fresh, PushAction.display, later), isTrue);
      expect(
        await PushLedger(FailingStore()).claim(parsed, PushAction.display, now),
        isFalse,
      );
      await ledger.clear(scope);
      expect(store.values, isEmpty);
    },
  );
}
