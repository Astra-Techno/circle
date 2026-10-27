import 'dart:typed_data';
import 'api_client.dart';
import 'api_json.dart';

/// The signed-in person (`GET /me`). Mobile numbers are only ever the
/// person's own.
enum ProfilePhotoKind { avatar, cover }

class ProfilePickedPhoto {
  const ProfilePickedPhoto({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
  static const maxBytes = 5 * 1024 * 1024;
}

class ApiAccount {
  const ApiAccount({
    required this.id,
    required this.displayName,
    this.mobile = '',
    this.about = '',
    this.currentCity = '',
    this.hometown = '',
    this.work = '',
    this.education = '',
    this.avatarVersion,
    this.coverVersion,
  });
  final String id,
      displayName,
      mobile,
      about,
      currentCity,
      hometown,
      work,
      education;
  final String? avatarVersion, coverVersion;

  String? photoVersion(ProfilePhotoKind kind) =>
      kind == ProfilePhotoKind.avatar ? avatarVersion : coverVersion;

  factory ApiAccount.fromJson(Object? json) {
    final map = ApiJson.map(json);
    return ApiAccount(
      id: ApiJson.id(map['id']),
      displayName: ApiJson.string(map['display_name']),
      mobile: ApiJson.string(map['mobile']),
      about: ApiJson.string(map['about']),
      currentCity: ApiJson.string(map['current_city']),
      hometown: ApiJson.string(map['hometown']),
      work: ApiJson.string(map['work']),
      education: ApiJson.string(map['education']),
      avatarVersion: _version(map['avatar_version']),
      coverVersion: _version(map['cover_version']),
    );
  }

  static String? _version(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  StoredAccount get stored => StoredAccount(id: id, displayName: displayName);
}

/// Accounts and sessions (ADR 0005). Passwords are sent exactly as typed
/// and are never stored, logged or trimmed.
class AuthApi {
  AuthApi(this.client, {this.persistAccount = true, this.canCommitSession});
  final bool Function()? canCommitSession;
  final ApiClient client;
  final bool persistAccount;

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
    if (canCommitSession?.call() == false) {
      throw const ApiError(
        'Your session changed. Please try again.',
        code: 'session_changed',
      );
    }
    await client.saveTokens(client.tokensFrom(data, account: account.stored));
    return account;
  }

  Future<ApiAccount> me() async => _rememberAccount(await client.get('/me'));

  Future<ApiAccount> updateDisplayName(String name) =>
      updateProfile({'display_name': name.trim()});

  Future<ApiAccount> updateProfile(Map<String, String> fields) async =>
      _rememberAccount(
        await client.patch(
          '/me',
          body: fields,
          expectedAccount: (await client.currentTokens())?.account?.id,
        ),
      );

  Future<ApiAccount> uploadProfilePhoto(
    ProfilePhotoKind kind,
    ProfilePickedPhoto photo,
  ) async {
    if (photo.bytes.isEmpty ||
        photo.bytes.length > ProfilePickedPhoto.maxBytes) {
      throw const ApiError(
        'Choose a photo smaller than 5 MB.',
        code: 'media_too_large',
      );
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(photo.mimeType)) {
      throw const ApiError(
        'Choose a JPEG, PNG or WebP photo.',
        code: 'media_type_not_allowed',
      );
    }
    return _rememberAccount(
      await client.putBytes(
        '/me/photos/${kind.name}',
        photo.bytes,
        contentType: photo.mimeType,
        expectedAccount: (await client.currentTokens())?.account?.id,
      ),
    );
  }

  Future<ApiAccount> deleteProfilePhoto(ProfilePhotoKind kind) async =>
      _rememberAccount(
        await client.delete(
          '/me/photos/${kind.name}',
          expectedAccount: (await client.currentTokens())?.account?.id,
        ),
      );

  Future<ApiAccount> _rememberAccount(Object? data) async {
    final account = ApiAccount.fromJson(data);
    final tokens = await client.currentTokens();
    if (persistAccount &&
        tokens != null &&
        (tokens.account == null || tokens.account!.id == account.id)) {
      await client.saveTokens(tokens.copyWith(account: account.stored));
    }
    return account;
  }

  /// Revokes the session on the server when possible, then forgets the
  /// tokens on this device either way.
  Future<void> logout() async {
    final revision = client.sessionRevision;
    final before = await client.currentTokens();
    try {
      if (await client.currentTokens() != null) {
        await client.post(
          '/auth/logout',
          expectedAccount: before?.account?.id,
          expectedSession: revision,
        );
      }
    } on ApiError {
      // Offline or already ended: the tokens are forgotten below anyway.
    } finally {
      if (client.sessionRevision == revision) await client.clearTokens();
    }
  }
}
