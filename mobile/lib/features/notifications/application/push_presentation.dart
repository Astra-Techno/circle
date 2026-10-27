import 'dart:async';
import '../../../core/api/api_json.dart';
import '../../../core/api/api_error.dart';
import '../data/push_preferences_api.dart';
import '../domain/push_envelope.dart';
import 'push_session_coordinator.dart';
import 'push_settings.dart';

/// Local reception is not content authorization. Never navigate/fetch a URL
/// from the payload; use only the active binding's API and generated id route.
class PushPresentation {
  PushPresentation({
    required this.coordinator,
    required this.display,
    required this.open,
    required this.dismiss,
    this.unavailable,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final PushSessionCoordinator coordinator;
  final Future<bool> Function(PushReception) display, open;
  final void Function() dismiss;
  final void Function()? unavailable;
  final DateTime Function() clock;
  Future<void> _tail = Future.value();
  StreamSubscription<PushReception>? _subscription;
  bool _disposed = false;

  void listen() {
    _subscription ??= coordinator.accepted.listen((_) {
      unawaited(pump());
    });
  }

  Future<void> pump() {
    final task = _tail.then((_) async {
      if (_disposed) return;
      for (final reception in await coordinator.pending()) {
        if (_disposed) return;
        final binding = await coordinator.bindingFor(reception.envelope);
        if (binding == null) return;
        try {
          final preferences = await PushPreferencesApi(
            binding.api,
            accountId: binding.scope.account,
          ).load();
          final category =
              (reception.envelope.isInvitation || reception.envelope.isReport)
              ? PushCategory.groups
              : reception.envelope.type == 'memory.created'
              ? PushCategory.memories
              : PushCategory.repliesReactions;
          if (!preferences.enabled ||
              preferences.categories[category] != true) {
            await coordinator.ledger.complete(reception, clock());
            continue;
          }
          if (pushQuietNow(preferences, clock())) continue;
          if (!await authorize(reception, checkPreferences: false)) {
            if (await coordinator.bindingFor(reception.envelope) != null) {
              await coordinator.ledger.complete(reception, clock());
              if (!_disposed && reception.action == PushAction.open) {
                unavailable?.call();
              }
            }
            continue;
          }
          if (_disposed || !coordinator.active) return;
          final shown = await (reception.action == PushAction.display
              ? display(reception)
              : open(reception));
          if (shown && !_disposed) {
            await coordinator.ledger.complete(reception, clock());
          }
        } on ApiError catch (error) {
          if (const {
            'not_found',
            'not_member',
            'account_inactive',
          }.contains(error.code)) {
            await coordinator.ledger.complete(reception, clock());
            if (!_disposed &&
                coordinator.active &&
                reception.action == PushAction.open) {
              unavailable?.call();
            }
          }
          // Transient/offline errors leave the persistent handoff pending.
        } catch (_) {}
      }
    });
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  /// Re-run on an actual banner action, not only when it was first received.
  Future<bool> authorize(
    PushReception reception, {
    bool checkPreferences = true,
  }) async {
    if (_disposed) return false;
    final binding = await coordinator.bindingFor(reception.envelope);
    if (binding == null) return false;
    if (checkPreferences) {
      final preferences = await PushPreferencesApi(
        binding.api,
        accountId: binding.scope.account,
      ).load();
      final category =
          (reception.envelope.isInvitation || reception.envelope.isReport)
          ? PushCategory.groups
          : reception.envelope.type == 'memory.created'
          ? PushCategory.memories
          : PushCategory.repliesReactions;
      if (!preferences.enabled ||
          preferences.categories[category] != true ||
          pushQuietNow(preferences, clock())) {
        return false;
      }
    }
    final data = ApiJson.map(
      await binding.api.get(
        reception.envelope.authorizationPath,
        expectedAccount: binding.scope.account,
      ),
    );
    if (!reception.envelope.authorizes(data, clock())) return false;
    final live = await coordinator.bindingFor(reception.envelope);
    return !_disposed && live != null;
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    dismiss();
  }
}
