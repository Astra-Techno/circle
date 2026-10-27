import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/notifications/application/background_push.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/application/push_presentation.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'background_push_test.dart' show config, token, scope;
import 'push_presentation_test.dart' show now, preferences, binding, payload;
import 'support/fake_api.dart';
import 'support/fake_fcm.dart';

Map<String, dynamic> invitation(PushScope scope) => {
  ...payload(scope)
    ..remove('memory_id')
    ..remove('comment_id'),
  'type': 'group.invitation',
  'invitation_id': '12',
};
Map<String, dynamic> detail([Map<String, dynamic> changes = const {}]) => {
  'invitation': {
    'id': 12,
    'group_id': 3,
    'recipient_id': 7,
    'status': 'pending',
    'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
    ...changes,
  },
};

void main() {
  test(
    'invitation envelope has exactly eight scoped fields and a generated route',
    () {
      final s = scope(token()), raw = invitation(scope(token()));
      final envelope = PushEnvelope.parse(raw, s, now)!;
      expect(raw.length, 8);
      expect(envelope.toData(), raw);
      expect(envelope.memoryId, isEmpty);
      expect(envelope.commentId, isEmpty);
      expect(envelope.invitationId, '12');
      expect(envelope.destination, '/you/invitations');
      expect(
        PushEnvelope.parse(payload(s), s, now)!.destination,
        '/home/memory/4',
      );
      for (final changes in [
        {'memory_id': '4'},
        {'comment_id': ''},
        {'recipient_id': '8'},
        {'group_id': '0'},
        {'invitation_id': '0'},
        {'invitation_id': 12},
        {'invitation_id': '18446744073709551616'},
        {'session_scope': 'f' * 64},
        {'api_base_url': 'https://foreign.example/api/v1'},
        {'body': 'Private text'},
        {'route': '/anything'},
        {'expires_at': '${now.millisecondsSinceEpoch ~/ 1000}'},
      ]) {
        expect(
          PushEnvelope.parse({...raw, ...changes}, s, now),
          isNull,
          reason: changes.keys.join(),
        );
      }
      final missing = {...raw}..remove('invitation_id');
      expect(PushEnvelope.parse(missing, s, now), isNull);
    },
  );

  for (final mode in [
    'success',
    'wrong_recipient',
    'wrong_group',
    'wrong_id',
    'accepted',
    'declined',
    'expired',
    'missing_recipient',
    'disabled_groups',
    'offline',
    'not_found',
    'logout',
  ]) {
    test(
      'foreground invitation $mode authorizes current account before display/open',
      () async {
        final gateway = Gateway();
        final paths = <String>[];
        late final PushBinding original;
        PushBinding? current;
        original = binding((r) async {
          paths.add(r.path);
          if (r.path == '/me/notification-preferences') {
            return FakeResponse.ok({
              ...preferences(),
              if (mode == 'disabled_groups')
                'categories': {
                  ...preferences()['categories'] as Map,
                  'groups': false,
                },
            });
          }
          if (mode == 'logout') current = null;
          if (mode == 'offline') return FakeResponse.error(503, 'server_error');
          if (mode == 'not_found') return FakeResponse.error(404, 'not_found');
          final changes = <String, dynamic>{
            if (mode == 'wrong_recipient') 'recipient_id': 8,
            if (mode == 'wrong_group') 'group_id': 9,
            if (mode == 'wrong_id') 'id': 13,
            if (mode == 'accepted' || mode == 'declined') 'status': mode,
            if (mode == 'expired') 'expires_at': now.toIso8601String(),
          };
          final response = detail(changes);
          if (mode == 'missing_recipient') {
            (response['invitation'] as Map).remove('recipient_id');
          }
          return FakeResponse.ok(response);
        });
        current = original;
        final coordinator = PushSessionCoordinator(
          gateway: gateway,
          current: () async => current,
          ledger: PushLedger(MemoryLocalSettingsStore()),
          enabled: true,
          clock: () => now,
        );
        final routes = <String>[];
        final presenter = PushPresentation(
          coordinator: coordinator,
          display: (r) async {
            routes.add('display');
            return true;
          },
          open: (r) async {
            routes.add(r.envelope.destination);
            return true;
          },
          dismiss: () {},
          clock: () => now,
        );
        await coordinator.start();
        paths.clear();
        final parsed = PushEnvelope.parse(
          invitation(original.scope),
          original.scope,
          now,
        )!;
        await coordinator.ledger.stage(parsed, PushAction.display, now);
        await coordinator.ledger.stage(parsed, PushAction.open, now);
        await presenter.pump();
        expect(
          routes,
          mode == 'success' ? ['display', '/you/invitations'] : isEmpty,
        );
        expect(
          paths.every(
            (p) =>
                p == '/me/notification-preferences' ||
                p == '/group-invitations/12',
          ),
          isTrue,
        );
        presenter.dispose();
        await coordinator.stop();
        coordinator.dispose();
        await gateway.close();
      },
    );
    test(
      'headless invitation $mode enforces same content/category/session policy',
      () async {
        TokenPair? live = token();
        final initial = live;
        var shown = 0;
        final paths = <String>[];
        final processor = BackgroundPushProcessor(
          config: config,
          readTokens: () async => live,
          ledger: PushLedger(MemoryLocalSettingsStore()),
          clock: () => now,
          show: (_) async {
            shown++;
            return true;
          },
          clientFactory: (tokens) => ApiClient(
            config: config,
            tokens: MemoryTokenStore(tokens),
            allowRefresh: false,
            adapter: FakeHttpAdapter((r) async {
              paths.add(r.path);
              if (r.path == '/me/notification-preferences') {
                return FakeResponse.ok({
                  ...preferences(),
                  if (mode == 'disabled_groups')
                    'categories': {
                      ...preferences()['categories'] as Map,
                      'groups': false,
                    },
                });
              }
              if (mode == 'logout') live = null;
              if (mode == 'offline') {
                return FakeResponse.error(503, 'server_error');
              }
              if (mode == 'not_found') {
                return FakeResponse.error(404, 'not_found');
              }
              final response = detail({
                if (mode == 'wrong_recipient') 'recipient_id': 8,
                if (mode == 'wrong_group') 'group_id': 9,
                if (mode == 'wrong_id') 'id': 13,
                if (mode == 'accepted' || mode == 'declined') 'status': mode,
                if (mode == 'expired') 'expires_at': now.toIso8601String(),
              });
              if (mode == 'missing_recipient') {
                (response['invitation'] as Map).remove('recipient_id');
              }
              return FakeResponse.ok(response);
            }),
          ),
        );
        await processor.receive(invitation(scope(initial)));
        expect(shown, mode == 'success' ? 1 : 0);
        expect(
          paths.every(
            (p) =>
                p == '/me/notification-preferences' ||
                p == '/group-invitations/12',
          ),
          isTrue,
        );
      },
    );
  }
}
