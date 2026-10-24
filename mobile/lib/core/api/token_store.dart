import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The signed-in person as last confirmed by `GET /me`, kept with the
/// tokens so the app can open while offline. Never contains the password.
class StoredAccount {
  const StoredAccount({required this.id, required this.displayName});
  final String id, displayName;

  Map<String, Object?> toJson() => {'id': id, 'display_name': displayName};

  static StoredAccount? fromJson(Object? json) =>
      json is Map && json['id'] is String
      ? StoredAccount(
          id: json['id'] as String,
          displayName: json['display_name'] as String? ?? '',
        )
      : null;
}

/// One session's tokens, bound to the server that issued them.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.server,
    this.account,
  });
  final String accessToken, refreshToken;

  /// The API base URL the tokens belong to; tokens for another server are
  /// ignored.
  final String server;
  final StoredAccount? account;

  TokenPair copyWith({StoredAccount? account}) => TokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    server: server,
    account: account ?? this.account,
  );

  String encode() => jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'server': server,
    'account': account?.toJson(),
  });

  static TokenPair? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map ||
          json['access_token'] is! String ||
          json['refresh_token'] is! String ||
          json['server'] is! String) {
        return null;
      }
      return TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        server: json['server'] as String,
        account: StoredAccount.fromJson(json['account']),
      );
    } on FormatException {
      return null;
    }
  }

  /// Never print tokens.
  @override
  String toString() => 'TokenPair(<redacted>)';
}

/// Where the session tokens live. The app uses [SecureTokenStore]; tests
/// use [MemoryTokenStore].
abstract interface class TokenStore {
  Future<TokenPair?> read();
  Future<void> write(TokenPair tokens);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed encrypted storage (Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'circle.session';

  @override
  Future<TokenPair?> read() async {
    try {
      return TokenPair.decode(await _storage.read(key: _key));
    } on Exception {
      // Unreadable storage (e.g. restored from a backup on another device)
      // means signing in again, never a crash.
      return null;
    }
  }

  @override
  Future<void> write(TokenPair tokens) =>
      _storage.write(key: _key, value: tokens.encode());

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Nothing more to clear.
    }
  }
}

/// In-memory store for tests and for platforms without secure storage.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);
  TokenPair? _tokens;

  @override
  Future<TokenPair?> read() async => _tokens;
  @override
  Future<void> write(TokenPair tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}
