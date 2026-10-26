import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/local_settings.dart';

export '../../../core/api/auth_api.dart' show ApiAccount;

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
  @override
  ServerSessionState build() {
    final api = ref.watch(apiClientProvider);
    if (api == null) return const ServerSessionState();
    api.onSessionEnded = _ended;
    Future.microtask(_restore);
    return const ServerSessionState(restoring: true);
  }

  AuthApi get _auth => AuthApi(ref.read(apiClientProvider)!);

  /// Opens the stored session, if any: `/me` validates it (refreshing the
  /// access token when needed). Offline, the last known account opens and
  /// screens show their calm offline states.
  Future<void> _restore() async {
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    final tokens = await api.currentTokens();
    if (!ref.mounted) return;
    if (tokens == null) {
      state = const ServerSessionState();
      return;
    }
    try {
      final account = await _auth.me();
      if (ref.mounted) state = ServerSessionState(account: account);
    } on ApiError catch (error) {
      if (!ref.mounted || !state.restoring) return;
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
    try {
      final account = await _auth.login(mobile: mobile, password: password);
      state = ServerSessionState(account: account);
      return null;
    } on ApiError catch (error) {
      return error.message;
    }
  }

  Future<String?> updateDisplayName(String name) async {
    final accountId = state.account?.id;
    if (accountId == null) return 'Please log in again to edit your profile.';
    try {
      final account = await _auth.updateDisplayName(name);
      if (ref.mounted && state.account?.id == accountId) {
        state = ServerSessionState(account: account);
      }
      return null;
    } on ApiError catch (error) {
      return error.message;
    }
  }

  /// Ends the session on the server and forgets it on this device. Use
  /// [CircleWorkspaceController.logOut], which first sends deletions still
  /// waiting for their Undo window.
  Future<void> logOut() async {
    final account = state.account;
    final config = ref.read(apiConfigProvider);
    if (account != null && config != null) {
      await ref
          .read(memoryDraftStoreProvider)
          .clearScope(
            DraftScope(server: config.baseUrl.toString(), account: account.id),
          );
    }
    await _auth.logout();
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
