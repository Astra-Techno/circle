import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/local_settings.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/push_lifecycle.dart';
import '../../../core/notifications/push_config.dart';
import '../../../core/notifications/native_push.dart';
import '../../workspace/application/server_session.dart';
import '../domain/push_envelope.dart';
import 'push_ledger.dart';

export '../domain/push_envelope.dart' show PushReception;

/// Safe connection stages only; never expose provider errors or device tokens.
enum PushConnectionProblem {
  disconnected('This phone is not connected. Try connecting again.'),
  buildDisabled(
    'Notifications are not included in this app build. Install the latest CIRCLE update.',
  ),
  unsupported('Phone notifications are not supported on this device yet.'),
  session(
    'Your notification session changed. Sign in again, then connect this phone.',
  ),
  firebase(
    'The phone notification service could not start. Update CIRCLE and check your internet connection.',
  ),
  permission(
    'Allow CIRCLE notifications in your phone settings, then try again.',
  ),
  token(
    'Google notification registration could not finish. Check internet access and Google Play services, then retry.',
  ),
  registration(
    'CIRCLE could not register this phone with the server. Check your connection and try again.',
  ),
  delivery(
    'The phone notification connection could not finish. Restart CIRCLE and try again.',
  );

  const PushConnectionProblem(this.message);
  final String message;
}

class PushBinding {
  PushBinding(this.api, this.scope) : sessionRevision = api.sessionRevision;
  final int sessionRevision;
  final ApiClient api;
  final PushScope scope;
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
  bool get active => enabled && !_disposed && _healthy && _binding != null;
  Future<void> _tail = Future.value();
  Future<bool>? _starting;
  int _epoch = 0;
  bool _disposed = false, _initialized = false, _healthy = false;
  PushBinding? _binding;
  String? _registeredToken;
  PushConnectionProblem _problem = PushConnectionProblem.disconnected;
  int? _registrationStatus;
  final connectionRevision = ValueNotifier<int>(0);
  void _changed() {
    scheduleMicrotask(() {
      if (!_disposed) connectionRevision.value++;
    });
  }

  String get connectionExplanation {
    final problem = connectionProblem;
    final status = _registrationStatus;
    return problem == PushConnectionProblem.registration && status != null
        ? '${problem.message} (HTTP $status)'
        : problem.message;
  }

  PushConnectionProblem get connectionProblem => !gateway.supported
      ? PushConnectionProblem.unsupported
      : !enabled
      ? PushConnectionProblem.buildDisabled
      : _problem;
  final _knownTokens = <String>{};

  void _record(PushConnectionProblem problem, int epoch) {
    if (!_disposed && epoch == _epoch) {
      _problem = problem;
      _changed();
    }
  }

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
      var stage = PushConnectionProblem.session;
      if (epoch == _epoch) _registrationStatus = null;
      _record(PushConnectionProblem.disconnected, epoch);
      try {
        binding = await current();
        if (binding == null || !await _valid(binding, epoch)) return false;
        if (_binding != null &&
            (_binding!.scope.key != binding.scope.key ||
                !identical(_binding!.api, binding.api))) {
          unawaited(stop(clearProblem: false));
          return false;
        }
        if (_healthy && _binding?.scope.key == binding.scope.key) {
          stage = PushConnectionProblem.permission;
          final allowed = await gateway.permission(request: requestPermission);
          if (!allowed) {
            _record(PushConnectionProblem.permission, epoch);
            unawaited(stop(clearProblem: false));
            return false;
          }
          if (!await _valid(binding, epoch)) return false;
          stage = PushConnectionProblem.token;
          final token = await gateway.token();
          if (!await _valid(binding, epoch)) return false;
          if (token == null) {
            _record(PushConnectionProblem.token, epoch);
            unawaited(stop(clearProblem: false));
            return false;
          }
          final registered =
              token == _registeredToken ||
              await _register(binding, epoch, token);
          if (registered && await _valid(binding, epoch)) {
            stage = PushConnectionProblem.delivery;
            final pendingTap = await gateway.initialMessage();
            if (pendingTap != null) {
              _receive(pendingTap, binding, epoch, PushAction.open);
            }
          }
          return registered;
        }
        _cancelListeners();
        stage = PushConnectionProblem.firebase;
        if (!_initialized) {
          await gateway.initialize();
          _initialized = true;
        }
        if (!await _valid(binding, epoch)) return false;
        stage = PushConnectionProblem.permission;
        if (!await gateway.permission(request: requestPermission)) {
          _record(PushConnectionProblem.permission, epoch);
          unawaited(stop(clearProblem: false));
          return false;
        }
        if (!await _valid(binding, epoch)) return false;
        stage = PushConnectionProblem.firebase;
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
              unawaited(stop(clearProblem: false));
            },
          ),
        );
        _subscriptions.add(
          gateway.foreground.listen(
            (data) => _receive(data, captured, epoch, PushAction.display),
            onError: (Object _) {
              unawaited(stop(clearProblem: false));
            },
          ),
        );
        _subscriptions.add(
          gateway.opened.listen(
            (data) => _receive(data, captured, epoch, PushAction.open),
            onError: (Object _) {
              unawaited(stop(clearProblem: false));
            },
          ),
        );
        stage = PushConnectionProblem.token;
        final token = await gateway.token();
        if (token == null) _record(PushConnectionProblem.token, epoch);
        if (token == null || !await _register(binding, epoch, token)) {
          if (epoch == _epoch) {
            unawaited(stop(clearProblem: false));
          }
          return false;
        }
        stage = PushConnectionProblem.delivery;
        final initial = await gateway.initialMessage();
        if (initial != null) _receive(initial, binding, epoch, PushAction.open);
        return await _valid(binding, epoch);
      } catch (_) {
        if (epoch == _epoch) {
          _problem = stage;
          unawaited(stop(clearProblem: false));
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
      if (epoch == _epoch) _problem = PushConnectionProblem.token;
      return false;
    }
    var stage = PushConnectionProblem.registration;
    try {
      if (_knownTokens.length >= 8 && !_knownTokens.contains(token)) {
        unawaited(stop(clearProblem: false));
        return false;
      }
      _knownTokens.add(token);
      final previous = _registeredToken;
      _registeredToken = token; // Track ambiguous network outcomes for cleanup.
      await binding.api.post(
        '/devices/register',
        body: {'fcm_token': token, 'platform': 'android'},
        expectedAccount: binding.scope.account,
        expectedSession: binding.sessionRevision,
      );
      if (!await _valid(binding, epoch)) return false;
      stage = PushConnectionProblem.delivery;
      await gateway.bindScope(binding.scope.key);
      if (!await _valid(binding, epoch)) {
        await gateway.bindScope(null);
        return false;
      }
      _healthy = true;
      _changed();
      if (previous != null &&
          previous != token &&
          await _valid(binding, epoch)) {
        try {
          await binding.api.post(
            '/devices/unregister',
            body: {'fcm_token': previous},
            expectedAccount: binding.scope.account,
            expectedSession: binding.sessionRevision,
          );
          _knownTokens.remove(previous);
        } catch (_) {}
      }
      return true;
    } catch (error) {
      if (epoch == _epoch) {
        _healthy = false;
        _problem = stage;
        final status = error is ApiError ? error.status : null;
        _registrationStatus = status != null && status >= 100 && status <= 599
            ? status
            : null;
        _changed();
      }
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
        String? nativeId;
        final handoff = data['circle_native_tap'];
        if (handoff is Map &&
            handoff['id'] is String &&
            handoff['data'] is Map) {
          nativeId = handoff['id'] as String;
          if (nativeId.length > 64) return;
          data = Map<String, dynamic>.from(handoff['data'] as Map);
        }
        final envelope = PushEnvelope.parse(data, binding.scope, clock());
        if (envelope == null) {
          if (nativeId != null) {
            await const NativePushBridge()
                .acknowledge(nativeId)
                .catchError((Object _) {});
          }
          return;
        }
        final staged = await ledger
            .stage(envelope, action, clock())
            .catchError((Object _) => false);
        if (nativeId != null &&
            (staged ||
                await ledger
                    .recorded(envelope, action, clock())
                    .catchError((Object _) => false))) {
          await const NativePushBridge()
              .acknowledge(nativeId)
              .catchError((Object _) {});
        }
        if (!staged) return;
        if (await _valid(binding, epoch) &&
            !_disposed &&
            epoch == _epoch &&
            envelope.belongsTo(binding.scope, clock())) {
          _accepted.add(PushReception(envelope, action));
        }
      }).catchError((Object _) {}),
    );
  }

  Future<PushBinding?> bindingFor(PushEnvelope envelope) async {
    final binding = _binding, epoch = _epoch;
    if (!active || binding == null || !await _valid(binding, epoch)) {
      return null;
    }
    return active &&
            epoch == _epoch &&
            envelope.belongsTo(binding.scope, clock())
        ? binding
        : null;
  }

  Future<List<PushReception>> pending() async {
    final binding = _binding, epoch = _epoch;
    if (!active || binding == null || !await _valid(binding, epoch)) return [];
    return ledger
        .pending(binding.scope, clock())
        .catchError((Object _) => <PushReception>[]);
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
  Future<void> stop({bool clearProblem = true}) {
    if (clearProblem) {
      _problem = PushConnectionProblem.disconnected;
      _registrationStatus = null;
    }
    _epoch++;
    unawaited(gateway.bindScope(null).catchError((Object _) {}));
    _starting = null;
    _healthy = false;
    _cancelListeners();
    final old = _binding;
    final tokens = Set<String>.of(_knownTokens);
    _knownTokens.clear();
    _binding = null;
    _registeredToken = null;
    _changed();
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
              expectedAccount: old.scope.account,
              expectedSession: old.sessionRevision,
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
    unawaited(stop(clearProblem: false));
    unawaited(_accepted.close());
    connectionRevision.dispose();
  }
}

final pushSessionCoordinatorProvider = Provider<PushSessionCoordinator>((ref) {
  final coordinator = PushSessionCoordinator(
    gateway: ref.watch(fcmGatewayProvider),
    ledger: PushLedger(
      ref.watch(localSettingsStoreProvider),
      mutex: ref.watch(pushClientEnabledProvider)
          ? const NativePushBridge()
          : null,
    ),
    enabled: ref.watch(pushClientEnabledProvider),
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
