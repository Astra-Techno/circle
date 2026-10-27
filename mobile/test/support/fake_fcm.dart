import 'dart:async';
import 'package:mobile/core/notifications/fcm_service.dart';

class Gateway implements FcmGateway {
  @override
  bool supported = true;
  bool allowed = true, failInit = false;
  int initialized = 0, activated = 0, deactivated = 0, requests = 0;
  Completer<void>? initGate;
  final tokens = StreamController<String>.broadcast(sync: true);
  final messages = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final taps = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Future<void> initialize() async {
    initialized++;
    if (failInit) throw StateError('Fictional SDK unavailable');
    if (initGate != null) await initGate!.future;
  }

  @override
  Future<bool> permission({required bool request}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<void> bindScope(String? scope) async {}
  @override
  Future<void> activate() async {
    activated++;
  }

  @override
  Future<void> deactivate() async {
    deactivated++;
  }

  @override
  Future<String?> token() async => 'fictional-device';
  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<Map<String, dynamic>> get foreground => messages.stream;
  @override
  Stream<Map<String, dynamic>> get opened => taps.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;
  Future<void> close() async {
    await tokens.close();
    await messages.close();
    await taps.close();
  }
}
