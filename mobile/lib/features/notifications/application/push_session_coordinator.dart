import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/local_settings.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/push_lifecycle.dart';
import '../../workspace/application/server_session.dart';
import '../domain/push_envelope.dart';
import 'push_ledger.dart';

class PushBinding {
  const PushBinding(this.api, this.scope);
  final ApiClient api;
  final PushScope scope;
}

class PushReception {
  const PushReception(this.envelope, this.action);
  final PushEnvelope envelope;
  final PushAction action;
}

/// Session changes invalidate callbacks immediately. SDK/network operations
/// serialize so an old registration cannot finish after the next registration.
class PushSessionCoordinator {
  PushSessionCoordinator({
    required this.gateway,
    required this.current,
    required this.ledger,
    this.enabled = false,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final FcmGateway gateway;
  final Future<PushBinding?> Function() current;
  final PushLedger ledger;
  final bool enabled;
  final DateTime Function() clock;
  final _accepted = StreamController<PushReception>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Stream<PushReception> get accepted => _accepted.stream;
  Future<void> _tail = Future.value();
  Future<bool>? _starting;
  int _epoch = 0;
  bool _disposed = false, _initialized = false, _healthy = false;
  PushBinding? _binding;
  String? _registeredToken;
  final _knownTokens = <String>{};

  Future<T> _queue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _valid(PushBinding binding, int epoch) async {
    if (_disposed || epoch != _epoch) return false;
    try {
      final live = await current();
      return !_disposed &&
          epoch == _epoch &&
          live != null &&
          identical(live.api, binding.api) &&
          live.scope.key == binding.scope.key;
    } catch (_) {
      return false;
    }
  }

  /// Only a future explained Enable notifications action may pass request=true.
  /// Passive restoration never requests OS permission.
  Future<bool> start({bool requestPermission = false}) {
    if (_disposed || !enabled || !gateway.supported) return Future.value(false);
    if (_starting != null) return _starting!;
    final epoch = _epoch;
    final future = _queue(() async {
      PushBinding? binding;
      try {
        binding = await current();
        if (binding == null || !await _valid(binding, epoch)) return false;
        if (_binding != null &&
            (_binding!.scope.key != binding.scope.key ||
                !identical(_binding!.api, binding.api))) {
          unawaited(stop());
          return false;
        }
        if (_healthy && _binding?.scope.key == binding.scope.key) {
          final allowed = await gateway.permission(request: requestPermission);
          if (!allowed) {
            unawaited(stop());
            return false;
          }
          if (!await _valid(binding, epoch)) return false;
          final token = await gateway.token();
          if (!await _valid(binding, epoch) || token == null) return false;
          return token == _registeredToken ||
              await _register(binding, epoch, token);
        }
        _cancelListeners();
        if (!_initialized) {
          await gateway.initialize();
          _initialized = true;
        }
        if (!await _valid(binding, epoch)) return false;
        if (!await gateway.permission(request: requestPermission)) {
          unawaited(stop());
          return false;
        }
        if (!await _valid(binding, epoch)) return false;
        await gateway.activate();
        if (!await _valid(binding, epoch)) return false;
        _binding = binding;
        final captured = binding;
        _subscriptions.add(
          gateway.tokenChanges.listen(
            (token) {
              unawaited(_queue(() => _register(captured, epoch, token)));
            },
            onError: (Object _) {
              unawaited(stop());
            },
          ),
        );
        _subscriptions.add(
          gateway.foreground.listen(
            (data) => _receive(data, captured, epoch, PushAction.display),
            onError: (Object _) {
              unawaited(stop());
            },
          ),
        );
        _subscriptions.add(
          gateway.opened.listen(
            (data) => _receive(data, captured, epoch, PushAction.open),
            onError: (Object _) {
              unawaited(stop());
            },
          ),
        );
        final token = await gateway.token();
        if (token == null || !await _register(binding, epoch, token)) {
          if (epoch == _epoch) {
            unawaited(stop());
          }
          return false;
        }
        final initial = await gateway.initialMessage();
        if (initial != null) _receive(initial, binding, epoch, PushAction.open);
        return await _valid(binding, epoch);
      } catch (_) {
        if (epoch == _epoch) {
          unawaited(stop());
        }
        return false;
      }
    });
    _starting = future;
    unawaited(
      future.then((_) {
        if (identical(_starting, future)) _starting = null;
      }),
    );
    return future;
  }

  Future<bool> _register(PushBinding binding, int epoch, String token) async {
    if (!RegExp(r'^[A-Za-z0-9:_-]{1,512}$').hasMatch(token) ||
        !await _valid(binding, epoch)) {
      return false;
    }
    try {
      if (_knownTokens.length >= 8 && !_knownTokens.contains(token)) {
        unawaited(stop());
        return false;
      }
      _knownTokens.add(token);
      final previous = _registeredToken;
      _registeredToken = token; // Track ambiguous network outcomes for cleanup.
      await binding.api.post(
        '/devices/register',
        body: {'fcm_token': token, 'platform': 'android'},
      );
      if (!await _valid(binding, epoch)) return false;
      _healthy = true;
      if (previous != null &&
          previous != token &&
          await _valid(binding, epoch)) {
        try {
          await binding.api.post(
            '/devices/unregister',
            body: {'fcm_token': previous},
          );
          _knownTokens.remove(previous);
        } catch (_) {}
      }
      return true;
    } catch (_) {
      if (epoch == _epoch) _healthy = false;
      return false;
    }
  }

  void _receive(
    Map<String, dynamic> data,
    PushBinding binding,
    int epoch,
    PushAction action,
  ) {
    unawaited(
      _queue(() async {
        if (!await _valid(binding, epoch)) return;
        final envelope = PushEnvelope.parse(data, binding.scope, clock());
        if (envelope == null ||
            !await ledger.claim(envelope, action, clock())) {
          return;
        }
        if (await _valid(binding, epoch) &&
            !_disposed &&
            epoch == _epoch &&
            envelope.belongsTo(binding.scope, clock())) {
          _accepted.add(PushReception(envelope, action));
        }
      }),
    );
  }

  void _cancelListeners() {
    for (final subscription in _subscriptions) {
      unawaited(() async {
        try {
          await subscription.cancel();
        } catch (_) {}
      }());
    }
    _subscriptions.clear();
  }

  /// Safe to call unawaited from authentication; local invalidation is immediate.
  Future<void> stop() {
    _epoch++;
    _starting = null;
    _healthy = false;
    _cancelListeners();
    final old = _binding;
    final tokens = Set<String>.of(_knownTokens);
    _knownTokens.clear();
    _binding = null;
    _registeredToken = null;
    return _queue(() async {
      if (_initialized) {
        try {
          await gateway.deactivate();
        } catch (_) {}
      }
      if (old != null) {
        for (final token in tokens) {
          try {
            final live = await current();
            if (live?.scope.key != old.scope.key ||
                !identical(live?.api, old.api)) {
              break;
            }
            await old.api.post(
              '/devices/unregister',
              body: {'fcm_token': token},
            );
          } catch (_) {}
        }
      }
      // Preserve scoped dedup on permission changes, SDK errors and restarts.
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    unawaited(_accepted.close());
  }
}

final pushSessionCoordinatorProvider = Provider<PushSessionCoordinator>((ref) {
  final coordinator = PushSessionCoordinator(
    gateway: ref.watch(fcmGatewayProvider),
    ledger: PushLedger(ref.watch(localSettingsStoreProvider)),
    enabled: const bool.fromEnvironment('CIRCLE_PUSH_ENABLED'),
    current: () async {
      if (!ref.mounted) return null;
      final api = ref.read(apiClientProvider),
          account = ref.read(serverAccountProvider);
      if (api == null || account == null || !api.config.secure) return null;
      final tokens = await api.currentTokens();
      if (!ref.mounted ||
          !identical(ref.read(apiClientProvider), api) ||
          ref.read(serverAccountProvider)?.id != account.id ||
          tokens == null ||
          tokens.server != api.config.baseUrl.toString() ||
          tokens.account?.id != account.id) {
        return null;
      }
      final scope = PushScope.fromAccessToken(
        server: tokens.server,
        account: account.id,
        token: tokens.accessToken,
      );
      return scope == null ? null : PushBinding(api, scope);
    },
  );
  final removeListener = ref.read(pushLifecycleProvider).listen(() {
    unawaited(coordinator.stop());
  });
  ref.onDispose(removeListener);
  ref.listen(serverAccountProvider.select((a) => a?.id), (_, _) {
    unawaited(coordinator.stop());
  });
  ref.listen(apiClientProvider, (_, _) {
    unawaited(coordinator.stop());
  });
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
