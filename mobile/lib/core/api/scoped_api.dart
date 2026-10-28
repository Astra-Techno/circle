import 'api_client.dart';
import 'api_json.dart';

/// A feature service never replays a dialog/action under another login.
class ScopedApi {
  ScopedApi(this.api, this.account, this.session, this.current);
  final ApiClient api;
  final String account;
  final int session;
  final bool Function() current;
  void check() {
    if (!current() || api.sessionRevision != session) {
      throw const ApiError(
        'Your session changed. Open this screen again.',
        code: 'session_changed',
      );
    }
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?>? query,
  }) async {
    check();
    final data = await api.get(
      path,
      query: query,
      expectedAccount: account,
      expectedSession: session,
    );
    check();
    return ApiJson.map(data);
  }

  Future<Map<String, Object?>> change(
    String method,
    String path,
    Map<String, Object?> body,
  ) async {
    check();
    final data = await switch (method) {
      'POST' => api.post(
        path,
        body: body,
        expectedAccount: account,
        expectedSession: session,
      ),
      'PUT' => api.put(
        path,
        body: body,
        expectedAccount: account,
        expectedSession: session,
      ),
      _ => api.patch(
        path,
        body: body,
        expectedAccount: account,
        expectedSession: session,
      ),
    };
    check();
    return data == null ? {} : ApiJson.map(data);
  }
}
