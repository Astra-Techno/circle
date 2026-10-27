import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/native_push.dart';
import '../../../core/notifications/push_config.dart';
import '../../workspace/application/server_session.dart';
import '../application/push_presentation.dart';
import '../application/push_session_coordinator.dart';
import '../application/push_settings.dart';

/// App injects a generated internal destination; feature code never imports app/.
class PushPresentationHost extends ConsumerStatefulWidget {
  const PushPresentationHost({
    super.key,
    required this.child,
    required this.onOpen,
  });
  final Widget child;
  final void Function(String destination) onOpen;
  @override
  ConsumerState<PushPresentationHost> createState() =>
      _PushPresentationHostState();
}

class _PushPresentationHostState extends ConsumerState<PushPresentationHost>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  PushPresentation? _presenter;
  bool _foreground = true;
  int _connectionEpoch = 0;
  PushSessionCoordinator? _attached;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenter?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _connectionEpoch++;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _presenter?.dispose();
      _presenter = null;
      _dismiss();
    }
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ref.read(pushClientEnabledProvider)) {
      ref.invalidate(pushSettingsProvider);
    }
  }

  void _dismiss() {
    _messenger.currentState?.clearMaterialBanners();
  }

  void _connect() {
    if (!mounted || !_foreground) return;
    final coordinator = ref.read(pushSessionCoordinatorProvider);
    if (!identical(_attached, coordinator)) {
      _presenter?.dispose();
      _presenter = null;
      _attached = coordinator;
    }
    _presenter ??= PushPresentation(
      coordinator: coordinator,
      dismiss: _dismiss,
      unavailable: () {
        if (mounted && _foreground) {
          _messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text('This update is no longer available.'),
            ),
          );
        }
      },
      display: (reception) async {
        if (!mounted || !_foreground || !coordinator.active) return false;
        return const NativePushBridge().show(
          scope: reception.envelope.scope.key,
          event: reception.envelope.eventId,
          expires: reception.envelope.expiresAt,
          data: reception.envelope.toData(),
        );
      },
      open: (reception) async {
        if (!mounted || !_foreground || !coordinator.active) return false;
        widget.onOpen(reception.envelope.destination);
        _dismiss();
        return true;
      },
    );
    _presenter!.listen();
    unawaited(() async {
      if (await coordinator.start() && mounted && _foreground) {
        await _presenter?.pump();
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(pushClientEnabledProvider);
    if (enabled) {
      ref.listen(serverAccountProvider.select((a) => a?.id), (_, _) {
        _connectionEpoch++;
        _presenter?.dispose();
        _presenter = null;
        _dismiss();
      });
      ref.listen(pushSettingsProvider, (_, next) {
        final epoch = ++_connectionEpoch;
        _presenter?.dispose();
        _presenter = null;
        _dismiss();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_foreground || epoch != _connectionEpoch) return;
          final choices = next.value;
          if (!next.isLoading && choices?.enabled == true) {
            _connect();
          } else if (!next.isLoading) {
            unawaited(ref.read(pushSessionCoordinatorProvider).stop());
            _dismiss();
          }
        });
      });
      // Watch establishes loading; no SDK work occurs until saved opt-in is true.
      ref.watch(pushSettingsProvider);
    }
    return enabled
        ? ScaffoldMessenger(key: _messenger, child: widget.child)
        : widget.child;
  }
}
