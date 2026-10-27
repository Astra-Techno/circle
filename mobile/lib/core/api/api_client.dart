import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_config.dart';
import 'api_error.dart';
import 'token_store.dart';

export 'api_config.dart';
export 'api_error.dart';
export 'token_store.dart';

/// One page of a paginated list (`{success, data: [...], pagination}`).
class ApiPage {
  const ApiPage(this.items, this.pagination);
  final List<Object?> items;
  final Map<String, Object?> pagination;

  String? get nextCursor => pagination['next_cursor'] as String?;
  bool get hasMore => pagination['has_more'] == true;
}

/// Called once when the session can't continue (refresh refused, account
/// inactive). Tokens are already cleared; [message] is calm and final.
typedef SessionEnded = void Function(String message);

/// The only HTTP client in the app. JSON in and out, the contract's
/// envelope unwrapped, errors turned into [ApiError], bearer tokens added
/// and refreshed. Nothing here logs requests, bodies or tokens.
class ApiClient {
  ApiClient({
    required this.config,
    required TokenStore tokens,
    HttpClientAdapter? adapter,
    this.onSessionEnded,
    this.allowRefresh = true,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 30),
    String userAgent = 'CIRCLE-mobile/1.0.0',
  }) : _store = tokens,
       dio = Dio(
         BaseOptions(
           baseUrl: config.baseUrl.toString(),
           connectTimeout: connectTimeout,
           receiveTimeout: receiveTimeout,
           sendTimeout: const Duration(seconds: 60),
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
           headers: {'Accept': 'application/json', 'User-Agent': userAgent},
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(_AuthInterceptor(this));
  }

  final ApiConfig config;
  final Dio dio;
  final TokenStore _store;
  SessionEnded? onSessionEnded;
  final bool allowRefresh;

  TokenPair? _tokens;
  bool _tokensLoaded = false;
  int _tokenRevision = 0, _sessionRevision = 0;
  Future<void> _tokenWrites = Future.value();
  int get sessionRevision => _sessionRevision;
  Future<String?>? _refreshing;

  static const _noAuth = 'circle.noAuth',
      _retried = 'circle.retried',
      _expectedAccount = 'circle.expectedAccount',
      _expectedSession = 'circle.expectedSession';

  // ── Tokens ─────────────────────────────────────────────────────────

  /// The stored session for this server, if any.
  Future<TokenPair?> currentTokens() async {
    if (!_tokensLoaded) {
      final revision = _tokenRevision;
      final stored = await _store.read();
      if (revision == _tokenRevision && !_tokensLoaded) {
        _tokens = stored?.server == config.baseUrl.toString() ? stored : null;
        _tokensLoaded = true;
      }
    }
    return _tokens;
  }

  bool _sameCredentials(TokenPair? a, TokenPair b) =>
      a != null &&
      a.server == b.server &&
      a.accessToken == b.accessToken &&
      a.refreshToken == b.refreshToken;

  Future<void> _persist(Future<void> Function() operation) {
    final result = _tokenWrites.then((_) => operation());
    _tokenWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> saveTokens(TokenPair tokens, {bool refresh = false}) async {
    if (!refresh && !_sameCredentials(_tokens, tokens)) _sessionRevision++;
    _tokenRevision++;
    _tokens = tokens;
    _tokensLoaded = true;
    await _persist(() => _store.write(tokens));
  }

  Future<void> clearTokens() async {
    _sessionRevision++;
    _tokenRevision++;
    _tokens = null;
    _tokensLoaded = true;
    await _persist(_store.clear);
  }

  /// Turns a login/refresh `TokenPair` response into stored tokens.
  TokenPair tokensFrom(Object? data, {StoredAccount? account}) {
    if (data is! Map ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String) {
      throw const ApiError(
        'The server sent something unexpected. Please try again later.',
        code: ApiError.badResponse,
      );
    }
    return TokenPair(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      server: config.baseUrl.toString(),
      account: account,
    );
  }

  /// Ends the session: tokens are cleared and [onSessionEnded] is told.
  Future<void> endSession(String message, {int? expectedSession}) async {
    if (expectedSession != null && expectedSession != _sessionRevision) return;
    final endedRevision = _sessionRevision + 1;
    final hadSession = _tokens != null;
    try {
      await clearTokens();
    } finally {
      // A secure-storage failure must not retain the old account/private UI.
      if (hadSession && _sessionRevision == endedRevision) {
        onSessionEnded?.call(message);
      }
    }
  }

  /// Single-flight refresh. Concurrent 401s share one `/auth/refresh`
  /// call, because each refresh token can be redeemed exactly once.
  /// Returns the new access token, or null when the session has ended.
  Future<String?> _refresh(String? failedAccessToken) async {
    final current = await currentTokens();
    if (current == null) return null;
    // Another request already refreshed after this one was sent.
    if (failedAccessToken != null && current.accessToken != failedAccessToken) {
      return current.accessToken;
    }
    return _refreshing ??= _redeem(
      current,
    ).whenComplete(() => _refreshing = null);
  }

  Future<String?> _redeem(TokenPair current) async {
    try {
      final response = await dio.post<Object?>(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
        options: Options(extra: {_noAuth: true}),
      );
      final data = _unwrap(response);
      final live = await currentTokens();
      if (!_sameCredentials(live, current)) return live?.accessToken;
      final fresh = tokensFrom(data, account: live?.account ?? current.account);
      await saveTokens(fresh, refresh: true);
      return fresh.accessToken;
    } on DioException catch (error) {
      final failure = ApiError.fromDio(error);
      if (!_sameCredentials(await currentTokens(), current)) {
        return (await currentTokens())?.accessToken;
      }
      // Offline, busy or rate limited: keep the session and try later.
      if (failure.isNetwork ||
          failure.code == 'rate_limited' ||
          (failure.status ?? 0) >= 500) {
        throw failure;
      }
      await endSession(ApiError.messageFor(ApiError.sessionExpired));
      return null;
    }
  }

  // ── Requests ───────────────────────────────────────────────────────

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    bool auth = true,
    String? expectedAccount,
    int? expectedSession,
  }) => _send(
    () => dio.get<Object?>(
      path,
      queryParameters: query,
      options: _options(auth, expectedAccount, expectedSession),
    ),
  );

  /// Authenticated private bytes. Error bodies are decoded by the auth
  /// interceptor before refresh/error mapping, even with ResponseType.bytes.
  Future<Uint8List> getBytes(
    String path, {
    Map<String, Object?>? query,
    String? expectedAccount,
    int? expectedSession,
  }) async {
    final response = await _raw(
      () => dio.get<Object?>(
        path,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'image/webp,image/jpeg,image/png'},
          extra: {
            _expectedAccount: ?expectedAccount,
            _expectedSession: ?expectedSession,
          },
        ),
      ),
    );
    final bytes = response.data;
    if (bytes is List<int> && bytes.isNotEmpty) {
      return Uint8List.fromList(bytes);
    }
    throw const ApiError(
      'This photo could not be loaded. Try again.',
      code: ApiError.badResponse,
    );
  }

  Future<ApiPage> getPage(
    String path, {
    Map<String, Object?>? query,
    String? expectedAccount,
    int? expectedSession,
  }) async {
    final response = await _raw(
      () => dio.get<Object?>(
        path,
        queryParameters: query,
        options: _options(true, expectedAccount, expectedSession),
      ),
    );
    final body = response.data;
    final items = body is Map && body['data'] is List
        ? body['data'] as List
        : const [];
    final pagination = body is Map && body['pagination'] is Map
        ? Map<String, Object?>.from(body['pagination'] as Map)
        : const <String, Object?>{};
    return ApiPage(List<Object?>.of(items), pagination);
  }

  Future<Object?> post(
    String path, {
    Object? body,
    bool auth = true,
    String? expectedAccount,
    int? expectedSession,
    bool replay = true,
    Map<String, String>? headers,
  }) => _send(
    () => dio.post<Object?>(
      path,
      data: body,
      options: Options(
        headers: headers,
        extra: {
          ...?_options(auth, expectedAccount, expectedSession)?.extra,
          if (!replay) 'circle.noReplay': true,
        },
      ),
    ),
  );

  Future<Object?> patch(
    String path, {
    Object? body,
    String? expectedAccount,
    int? expectedSession,
  }) => _send(
    () => dio.patch<Object?>(
      path,
      data: body,
      options: _options(true, expectedAccount, expectedSession),
    ),
  );

  Future<Object?> delete(
    String path, {
    Map<String, Object?>? query,
    String? expectedAccount,
    int? expectedSession,
  }) => _send(
    () => dio.delete<Object?>(
      path,
      queryParameters: query,
      options: _options(true, expectedAccount, expectedSession),
    ),
  );

  /// Sends raw bytes (photo uploads). [onProgress] gets sent/total bytes.
  Future<Object?> putBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
    String? expectedAccount,
    void Function(int sent, int total)? onProgress,
  }) => _send(
    () => dio.put<Object?>(
      path,
      data: bytes,
      options: Options(
        contentType: contentType,
        extra: {_expectedAccount: ?expectedAccount},
        headers: {Headers.contentLengthHeader: '${bytes.length}'},
        sendTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: onProgress,
    ),
  );

  Options? _options(
    bool auth, [
    String? expectedAccount,
    int? expectedSession,
  ]) => auth && expectedAccount == null && expectedSession == null
      ? null
      : Options(
          extra: {
            if (!auth) _noAuth: true,
            _expectedAccount: ?expectedAccount,
            _expectedSession: ?expectedSession,
          },
        );

  Future<Object?> _send(Future<Response<Object?>> Function() call) async =>
      _unwrap(await _raw(call));

  Future<Response<Object?>> _raw(
    Future<Response<Object?>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiError.fromDio(error);
    }
  }

  /// The envelope's `data`; anything that isn't `{success: true}` is an
  /// unexpected answer.
  Object? _unwrap(Response<Object?> response) {
    final body = response.data;
    if (body is Map && body['success'] == true) return body['data'];
    throw const ApiError(
      'The server sent something unexpected. Please try again later.',
      code: ApiError.badResponse,
    );
  }

  static String? _code(Object? body) {
    final error = body is Map ? body['error'] : null;
    return error is Map ? error['code'] as String? : null;
  }
}

/// Adds the bearer token and, on `401 invalid_token`, refreshes once and
/// retries the request once. A refused refresh ends the session.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.client);
  final ApiClient client;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[ApiClient._noAuth] != true) {
      options.extra.putIfAbsent(
        ApiClient._expectedSession,
        () => client.sessionRevision,
      );
      final tokens = await client.currentTokens();
      if (options.extra[ApiClient._expectedSession] != client.sessionRevision) {
        return handler.reject(_changed(options));
      }
      final expected = options.extra[ApiClient._expectedAccount];
      if (expected != null && tokens?.account?.id != expected) {
        return handler.reject(_changed(options));
      }
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  DioException _changed(RequestOptions options) => DioException(
    requestOptions: options,
    error: const ApiError(
      'Your session changed. Please try again.',
      code: 'session_changed',
    ),
  );

  Future<bool> _matches(RequestOptions options) async {
    final expected = options.extra[ApiClient._expectedAccount];
    final tokens = await client.currentTokens();
    return options.extra[ApiClient._expectedSession] ==
            client.sessionRevision &&
        (expected == null || tokens?.account?.id == expected);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final response = err.response;
    // Dio preserves raw error bytes for binary requests. Convert only error
    // JSON so expired sessions retain the usual single-flight refresh path.
    if (response?.data is List<int>) {
      try {
        response!.data = jsonDecode(utf8.decode(response.data as List<int>));
      } on FormatException {
        // Non-JSON errors use the existing generic, redacted error mapping.
      }
    }
    if (response == null ||
        options.extra[ApiClient._noAuth] == true ||
        options.extra[ApiClient._retried] == true) {
      return handler.next(err);
    }
    if (!await _matches(options)) return handler.next(_changed(options));
    final code = ApiClient._code(response.data);
    if (response.statusCode == 403 && code == 'account_inactive') {
      await client.endSession(
        ApiError.messageFor('account_inactive'),
        expectedSession: options.extra[ApiClient._expectedSession] as int?,
      );
      return handler.next(err);
    }
    if (options.extra['circle.noReplay'] == true ||
        !client.allowRefresh ||
        response.statusCode != 401 ||
        (code != 'invalid_token' && code != 'unauthorized')) {
      return handler.next(err);
    }
    final header = options.headers['Authorization'];
    final sent = header is String && header.startsWith('Bearer ')
        ? header.substring(7)
        : null;
    final String? fresh;
    try {
      fresh = await client._refresh(sent);
    } on ApiError catch (failure) {
      return handler.next(
        DioException(
          requestOptions: options,
          response: response,
          error: failure,
        ),
      );
    }
    if (fresh == null && await client.currentTokens() == null) {
      return handler.next(
        DioException(
          requestOptions: options,
          response: response,
          error: ApiError(
            ApiError.messageFor(ApiError.sessionExpired),
            code: ApiError.sessionExpired,
            status: 401,
          ),
        ),
      );
    }
    if (!await _matches(options)) return handler.next(_changed(options));
    options
      ..headers['Authorization'] = 'Bearer $fresh'
      ..extra[ApiClient._retried] = true;
    try {
      handler.resolve(await client.dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
