import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/local_settings.dart';

export '../../../core/api/auth_api.dart'
    show ApiAccount, ProfilePhotoKind, ProfilePickedPhoto;

/// The signed-in account on a CIRCLE server (server builds only).
class ServerSessionState {
  const ServerSessionState({this.account, this.restoring = false, this.notice});
  final ApiAccount? account;

  /// Checking stored tokens at start-up.
  final bool restoring;

  /// A calm message for the log-in screen, e.g. after the session ended.
  final String? notice;
}

final serverSessionProvider =
    NotifierProvider<ServerSession, ServerSessionState>(ServerSession.new);

/// The signed-in server account, or null (preview, or signed out).
final serverAccountProvider = Provider<ApiAccount?>(
  (ref) => ref.watch(serverSessionProvider.select((state) => state.account)),
);

/// Real registration and log-in against the API (ADR 0005). Passwords are
/// passed straight through, never stored, trimmed or logged.
class ServerSession extends Notifier<ServerSessionState> {
  int _sessionEpoch = 0, _profileRevision = 0;
  Future<void> _profileMutationTail = Future.value();
  @override
  ServerSessionState build() {
    _sessionEpoch++;
    _profileRevision++;
    final api = ref.watch(apiClientProvider);
    if (api == null) return const ServerSessionState();
    api.onSessionEnded = (message) {
      if (ref.mounted && identical(ref.read(apiClientProvider), api)) {
        _ended(message);
      }
    };
    Future.microtask(_restore);
    return const ServerSessionState(restoring: true);
  }

  AuthApi get _auth =>
      AuthApi(ref.read(apiClientProvider)!, persistAccount: false);

  /// Opens the stored session, if any: `/me` validates it (refreshing the
  /// access token when needed). Offline, the last known account opens and
  /// screens show their calm offline states.
  Future<void> _restore() async {
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    final epoch = _sessionEpoch;
    final tokens = await api.currentTokens();
    if (!ref.mounted ||
        epoch != _sessionEpoch ||
        !identical(ref.read(apiClientProvider), api)) {
      return;
    }
    if (tokens == null) {
      state = const ServerSessionState();
      return;
    }
    try {
      final account = await _auth.me();
      if (ref.mounted &&
          epoch == _sessionEpoch &&
          state.restoring &&
          identical(ref.read(apiClientProvider), api)) {
        state = ServerSessionState(account: account);
        await _rememberAccount(api, account, epoch);
      }
    } on ApiError catch (error) {
      if (!ref.mounted ||
          epoch != _sessionEpoch ||
          !state.restoring ||
          !identical(ref.read(apiClientProvider), api)) {
        return;
      }
      final stored = tokens.account;
      final ended =
          error.code == ApiError.sessionExpired ||
          error.code == 'account_inactive' ||
          await api.currentTokens() == null;
      state = !ended && stored != null
          ? ServerSessionState(
              account: ApiAccount(
                id: stored.id,
                displayName: stored.displayName,
              ),
            )
          : ServerSessionState(notice: ended ? error.message : null);
    }
  }

  void _ended(String message) {
    if (!ref.mounted) return;
    _sessionEpoch++;
    _profileRevision++;
    _forgetImages();
    state = ServerSessionState(notice: message);
  }

  /// Registers, then logs in with the same details (the server never
  /// issues tokens on registration). Returns a calm error, or null.
  Future<String?> register({
    required String mobile,
    required String password,
    String? displayName,
  }) async {
    try {
      await _auth.register(
        mobile: mobile,
        password: password,
        displayName: displayName,
      );
    } on ApiError catch (error) {
      return error.message;
    }
    final failure = await logIn(mobile: mobile, password: password);
    // Registration looks the same for numbers that already have an account
    // (ADR 0005), so a failed log-in here gets a gentle hint.
    return failure == null
        ? null
        : failure == ApiError.messageFor('invalid_credentials')
        ? 'We couldn’t sign you in with these details. If this number already has an account, log in with its password.'
        : failure;
  }

  /// Returns a calm error, or null once signed in.
  Future<String?> logIn({
    required String mobile,
    required String password,
  }) async {
    final epoch = ++_sessionEpoch;
    _profileRevision++;
    try {
      final account = await _auth.login(mobile: mobile, password: password);
      if (!ref.mounted || epoch != _sessionEpoch) {
        return 'Your session changed. Please try again.';
      }
      state = ServerSessionState(account: account);
      return null;
    } on ApiError catch (error) {
      return error.message;
    }
  }

  Future<String?> updateDisplayName(String name) =>
      updateProfile({'display_name': name.trim()});

  Future<String?> refreshProfile() =>
      _profileChange((auth) => auth.me(), readOnly: true);

  Future<String?> updateProfile(Map<String, String> fields) =>
      _queueProfileChange((auth) => auth.updateProfile(fields));

  Future<String?> uploadProfilePhoto(
    ProfilePhotoKind kind,
    ProfilePickedPhoto photo,
  ) => _queueProfileChange((auth) => auth.uploadProfilePhoto(kind, photo));

  Future<String?> deleteProfilePhoto(ProfilePhotoKind kind) =>
      _queueProfileChange((auth) => auth.deleteProfilePhoto(kind));

  /// Profile changes are serialized so one complete Me response cannot lose
  /// a concurrent photo/details change that is still committing on the server.
  Future<String?> _queueProfileChange(
    Future<ApiAccount> Function(AuthApi auth) operation,
  ) {
    final epoch = _sessionEpoch;
    final accountId = state.account?.id;
    final api = ref.read(apiClientProvider);
    final result = _profileMutationTail.then((_) {
      if (!ref.mounted ||
          epoch != _sessionEpoch ||
          state.account?.id != accountId ||
          !identical(ref.read(apiClientProvider), api)) {
        return Future<String?>.value('Your session changed. Please try again.');
      }
      return _profileChange(operation);
    });
    _profileMutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<String?> _profileChange(
    Future<ApiAccount> Function(AuthApi auth) operation, {
    bool readOnly = false,
  }) async {
    final accountId = state.account?.id;
    final api = ref.read(apiClientProvider);
    if (accountId == null || api == null) {
      return 'Please log in again to edit your profile.';
    }
    final epoch = _sessionEpoch;
    final revision = readOnly ? _profileRevision : ++_profileRevision;
    try {
      final account = await operation(AuthApi(api, persistAccount: false));
      if (!ref.mounted ||
          epoch != _sessionEpoch ||
          revision != _profileRevision ||
          state.account?.id != accountId ||
          account.id != accountId ||
          !identical(ref.read(apiClientProvider), api)) {
        return 'Your session changed. Please try again.';
      }
      // Invalidate any read started while a mutation was in flight, so its
      // old response cannot replace the newly saved details or photo version.
      if (!readOnly) _profileRevision++;
      state = ServerSessionState(account: account);
      await _rememberAccount(api, account, epoch);
      return null;
    } on ApiError catch (error) {
      return error.message;
    }
  }

  Future<void> _rememberAccount(
    ApiClient api,
    ApiAccount account,
    int epoch,
  ) async {
    final tokens = await api.currentTokens();
    if (ref.mounted &&
        epoch == _sessionEpoch &&
        identical(state.account, account) &&
        identical(ref.read(apiClientProvider), api) &&
        tokens != null) {
      await api.saveTokens(tokens.copyWith(account: account.stored));
    }
  }

  /// Ends the session on the server and forgets it on this device. Use
  /// [CircleWorkspaceController.logOut], which first sends deletions still
  /// waiting for their Undo window.
  Future<void> logOut() async {
    _sessionEpoch++;
    _profileRevision++;
    final auth = _auth;
    final account = state.account;
    final config = ref.read(apiConfigProvider);
    if (account != null && config != null) {
      await ref
          .read(memoryDraftStoreProvider)
          .clearScope(
            DraftScope(server: config.baseUrl.toString(), account: account.id),
          );
    }
    await auth.logout();
    _forgetImages();
    state = const ServerSessionState();
  }

  /// Photos already on screen stay in Flutter's image cache; drop them.
  void _forgetImages() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}
