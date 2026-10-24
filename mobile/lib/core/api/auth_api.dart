import 'api_client.dart';
import 'api_json.dart';

/// The signed-in person (`GET /me`). Mobile numbers are only ever the
/// person's own.
class ApiAccount {
  const ApiAccount({required this.id, required this.displayName});
  final String id, displayName;

  factory ApiAccount.fromJson(Object? json) {
    final map = ApiJson.map(json);
    return ApiAccount(
      id: ApiJson.id(map['id']),
      displayName: ApiJson.string(map['display_name']),
    );
  }

  StoredAccount get stored => StoredAccount(id: id, displayName: displayName);
}

/// Accounts and sessions (ADR 0005). Passwords are sent exactly as typed
/// and are never stored, logged or trimmed.
class AuthApi {
  AuthApi(this.client);
  final ApiClient client;

  /// `202` for new and already-registered numbers alike; no tokens.
  Future<void> register({
    required String mobile,
    required String password,
    String? displayName,
  }) async {
    final name = displayName?.trim() ?? '';
    await client.post(
      '/auth/register',
      auth: false,
      body: {
        'mobile': mobile,
        'password': password,
        if (name.isNotEmpty) 'display_name': name,
      },
    );
  }

  /// Opens a session and stores its tokens.
  Future<ApiAccount> login({
    required String mobile,
    required String password,
  }) async {
    final data = await client.post(
      '/auth/login',
      auth: false,
      body: {'mobile': mobile, 'password': password},
    );
    final account = ApiAccount.fromJson(ApiJson.map(data)['user']);
    await client.saveTokens(client.tokensFrom(data, account: account.stored));
    return account;
  }

  Future<ApiAccount> me() async {
    final account = ApiAccount.fromJson(await client.get('/me'));
    final tokens = await client.currentTokens();
    if (tokens != null) {
      await client.saveTokens(tokens.copyWith(account: account.stored));
    }
    return account;
  }

  /// Revokes the session on the server when possible, then forgets the
  /// tokens on this device either way.
  Future<void> logout() async {
    try {
      if (await client.currentTokens() != null) {
        await client.post('/auth/logout');
      }
    } on ApiError {
      // Offline or already ended: the tokens are forgotten below anyway.
    } finally {
      await client.clearTokens();
    }
  }
}
