import 'api_client.dart';
import 'api_json.dart';

class AccountSession {
  AccountSession(Object? value) {
    final m = ApiJson.map(value);
    id = ApiJson.id(m['id']);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) || m['is_current'] is! bool) {
      ApiJson.unexpected();
    }
    current = m['is_current'] == true;
    device = ApiJson.string(m['device_label'], 'Unknown device');
    os = ApiJson.string(m['os_version']);
    app = ApiJson.string(m['app_version']);
    ip = ApiJson.string(m['ip_address']);
    location = ApiJson.optionalString(m['location_label']);
    created = ApiJson.time(m['created_at']);
    seen = ApiJson.time(m['last_seen_at']);
    locationUpdated = ApiJson.time(m['location_updated_at']);
  }
  late final String id, device, os, app, ip;
  late final bool current;
  late final String? location;
  late final DateTime? created, seen, locationUpdated;
}

class AccountSessionPage {
  const AccountSessionPage(this.items, this.total);
  final List<AccountSession> items;
  final int total;
}

class AccountSecurityApi {
  const AccountSecurityApi(this.client, this.account, this.revision);
  final ApiClient client;
  final String account;
  final int revision;
  Future<AccountSessionPage> sessions({int offset = 0}) async {
    final page = await client.getPage(
      '/me/sessions',
      query: {'limit': 30, 'offset': offset},
      expectedAccount: account,
      expectedSession: revision,
    );
    final total = ApiJson.integer(page.pagination['total']);
    if (total == null || total < 0) ApiJson.unexpected();
    return AccountSessionPage(
      page.items.map(AccountSession.new).toList(),
      total,
    );
  }

  Future<void> update(Map<String, Object?> details) async {
    await client.patch(
      '/me/session',
      body: details,
      expectedAccount: account,
      expectedSession: revision,
    );
  }

  Future<bool> revoke(String id) async {
    final data = ApiJson.map(
      await client.delete(
        '/me/sessions/${Uri.encodeComponent(id)}',
        expectedAccount: account,
        expectedSession: revision,
      ),
    );
    if (data['current_session_revoked'] is! bool) ApiJson.unexpected();
    return data['current_session_revoked'] == true;
  }

  Future<void> password(String current, String next) async {
    final data = ApiJson.map(
      await client.post(
        '/auth/change-password',
        body: {'current_password': current, 'new_password': next},
        expectedAccount: account,
        expectedSession: revision,
        replay: false,
      ),
    );
    if (data['sign_in_required'] != true) ApiJson.unexpected();
  }
}
