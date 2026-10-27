import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/account_security_api.dart';
import '../../../core/platform/session_device.dart';
import '../../workspace/application/server_session.dart';
export '../../../core/api/account_security_api.dart';
export '../../../core/api/api_error.dart';

final accountSecurityProvider = Provider<AccountSecurity?>((ref) {
  final api = ref.watch(apiClientProvider),
      account = ref.watch(serverAccountProvider);
  return api == null || account == null
      ? null
      : AccountSecurity(
          ref,
          AccountSecurityApi(api, account.id, api.sessionRevision),
        );
});

class AccountSecurity {
  AccountSecurity(this.ref, this.api);
  final Ref ref;
  final AccountSecurityApi api;
  bool get active =>
      ref.mounted &&
      identical(ref.read(apiClientProvider), api.client) &&
      ref.read(serverAccountProvider)?.id == api.account &&
      api.client.sessionRevision == api.revision;
  void check() {
    if (!active) {
      throw const ApiError(
        'Your session changed. Open Account again.',
        code: 'session_changed',
      );
    }
  }

  Future<AccountSessionPage> sessions({int offset = 0}) async {
    check();
    final page = await api.sessions(offset: offset);
    check();
    return page;
  }

  Future<void> updateDevice() async {
    check();
    final details = await ref.read(sessionDeviceProvider).details();
    check();
    if (details.isNotEmpty) await api.update(details);
  }

  Future<void> shareLocation() async {
    check();
    final label = await ref.read(sessionDeviceProvider).approximateLocation();
    check();
    await api.update({'location_label': label});
    check();
  }

  Future<void> clearLocation() async {
    check();
    await api.update({'location_label': null});
    check();
  }

  Future<void> finish(String notice) async {
    if (active) {
      await ref
          .read(serverSessionProvider.notifier)
          .finishSecuritySession(api.client, api.account, api.revision, notice);
    }
  }

  Future<void> revoke(AccountSession session) async {
    check();
    final current = await api.revoke(session.id);
    check();
    if (current) {
      await finish('This device was logged out. Sign in again to continue.');
    }
  }

  Future<void> password(String current, String next) async {
    check();
    try {
      await api.password(current, next);
    } on ApiError catch (error) {
      if (error.status == 401) {
        await finish('Sign in again before changing your password.');
      }
      rethrow;
    }
    await finish('Password changed. Sign in again on each device.');
  }
}
