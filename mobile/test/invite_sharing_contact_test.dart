import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/groups/data/contact_invitation_client.dart';
import 'package:mobile/features/groups/domain/contact_invitation.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';

void main() {
  test('local numbers require explicit international correction', () {
    expect(AccessValidation.mobile('5551234567'), isNotNull);
    expect(AccessValidation.mobile('+1 (555) 123-4567'), isNull);
  });
  test(
    'contact invitations send one confirmed E164 number and never create membership',
    () async {
      final api = ApiClient(
        config: ApiConfig.parse('https://fictional.example/api/v1')!,
        tokens: MemoryTokenStore(),
      );
      final calls = <RequestOptions>[];
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {'outcome': 'invited', 'invitation_id': '18'},
                },
              ),
            );
          },
        ),
      );
      final client = ContactInvitationClient(api, '7', api.sessionRevision);
      final result = await client.invite('9', '+15551234567');
      expect(result.outcome, 'invited');
      expect(result.invitationId, '18');
      expect(calls.single.path, '/groups/9/contact-invitations');
      expect(calls.single.data, {'mobile': '+15551234567'});
      expect(calls.single.extra['circle.expectedAccount'], '7');
      expect(calls.single.extra['circle.expectedSession'], api.sessionRevision);
    },
  );
  test(
    'invitation model preserves consent, expiry and group approval state',
    () {
      final item = ContactInvitation.fromJson({
        'id': 18,
        'group_id': 9,
        'group_name': 'Fictional circle',
        'inviter_name': 'Fictional host',
        'status': 'pending',
        'approval_required': true,
        'expires_at': '2026-12-01T12:00:00Z',
      });
      expect(item.id, '18');
      expect(item.status, 'pending');
      expect(item.approvalRequired, isTrue);
      expect(item.expiresAt, DateTime.utc(2026, 12, 1, 12));
    },
  );
  test(
    'inbox uses bounded offset pagination and guards account/session',
    () async {
      final api = ApiClient(
        config: ApiConfig.parse('https://fictional.example/api/v1')!,
        tokens: MemoryTokenStore(),
      );
      final calls = <RequestOptions>[];
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [
                    {
                      'id': 18,
                      'group_id': 9,
                      'recipient_id': 7,
                      'group_name': 'Fictional circle',
                      'inviter_name': 'Fictional host',
                      'status': 'pending',
                      'approval_required': false,
                      'expires_at': '2026-12-01 12:00:00.123456',
                    },
                  ],
                  'pagination': {'total': 21, 'offset': 20, 'limit': 20},
                },
              ),
            );
          },
        ),
      );
      final page = await ContactInvitationClient(
        api,
        '7',
        api.sessionRevision,
      ).list(offset: 20);
      expect(page.items, hasLength(1));
      expect(calls.single.queryParameters, {'limit': 20, 'offset': 20});
      expect(calls.single.extra['circle.expectedAccount'], '7');
      expect(calls.single.extra['circle.expectedSession'], api.sessionRevision);
      expect(
        ContactInvitation.fromJson(page.items.single).expiresAt,
        DateTime.utc(2026, 12, 1, 12, 0, 0, 123, 456),
      );
    },
  );
  test('recipient mismatch and malformed outcomes fail closed', () async {
    final api = ApiClient(
      config: ApiConfig.parse('https://fictional.example/api/v1')!,
      tokens: MemoryTokenStore(),
    );
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'success': true,
                'data': request.method == 'GET'
                    ? {
                        'invitation': {'recipient_id': 999},
                      }
                    : {'outcome': 'invited'},
              },
            ),
          );
        },
      ),
    );
    final client = ContactInvitationClient(api, '7', api.sessionRevision);
    await expectLater(client.detail('18'), throwsA(isA<ApiError>()));
    await expectLater(
      client.invite('9', '+15551234567'),
      throwsA(isA<ApiError>()),
    );
  });
}
