import '../../../core/api/api_client.dart';
import '../../../core/api/api_json.dart';
import '../domain/contact_invitation.dart';

class ContactInvitationClient {
  ContactInvitationClient(this.api, this.account, this.session);
  final ApiClient api;
  final String account;
  final int session;
  Future<ContactInviteOutcome> invite(String group, String mobile) async {
    final data = ApiJson.map(
      await api.post(
        '/groups/${Uri.encodeComponent(group)}/contact-invitations',
        body: {'mobile': mobile},
        expectedAccount: account,
        expectedSession: session,
      ),
    );
    final outcome = data['outcome'];
    if (outcome is! String ||
        !const {
          'invited',
          'already_pending',
          'share_link',
          'already_member',
          'unavailable',
        }.contains(outcome)) {
      ApiJson.unexpected();
    }
    final id = ApiJson.optionalId(data['invitation_id']);
    if ((outcome == 'invited' || outcome == 'already_pending') && id == null) {
      ApiJson.unexpected();
    }
    return ContactInviteOutcome(outcome, id);
  }

  Future<ApiPage> list({int offset = 0, int limit = 20}) async {
    final page = await api.getPage(
      '/me/group-invitations',
      query: {'limit': limit, 'offset': offset},
      expectedAccount: account,
      expectedSession: session,
    );
    for (final item in page.items) {
      _decode(item);
    }
    return page;
  }

  ContactInvitation _decode(Object? value) {
    final map = ApiJson.map(value);
    if (ApiJson.id(map['recipient_id']) != account) ApiJson.unexpected();
    return ContactInvitation.fromJson(map);
  }

  Future<ContactInvitation> detail(String id) async {
    final data = ApiJson.map(
      await api.get(
        '/group-invitations/${Uri.encodeComponent(id)}',
        expectedAccount: account,
        expectedSession: session,
      ),
    );
    return _decode(data['invitation']);
  }

  Future<String> respond(String id, {required bool accept}) async {
    final data = ApiJson.map(
      await api.post(
        '/group-invitations/${Uri.encodeComponent(id)}/${accept ? 'accept' : 'decline'}',
        body: <String, Object?>{},
        expectedAccount: account,
        expectedSession: session,
      ),
    );
    _decode(data['invitation']);
    final status = data['status'];
    if (status is! String ||
        !const {
          'joined',
          'pending_approval',
          'accepted',
          'declined',
          'expired',
        }.contains(status)) {
      ApiJson.unexpected();
    }
    return status;
  }
}
