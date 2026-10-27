import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/native_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('circle/push_native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'bridge transmits generic references; initial payload is parsed safely',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initial') {
          return jsonEncode({'event_id': 'fictional'});
        }
        return call.method == 'show' ? true : null;
      });
      const native = NativePushBridge();
      await native.bind('a' * 64);
      expect(
        await native.show(
          scope: 'a' * 64,
          event: 'b' * 64,
          expires: 123,
          data: {'memory_id': '7'},
        ),
        isTrue,
      );
      expect(jsonDecode(calls[1].arguments['payload'] as String), {
        'memory_id': '7',
      });
      expect(await native.initial(), {'event_id': 'fictional'});
      await native.bind(null);
      expect(calls.last.arguments, {'scope': ''});
    },
  );
  test('native mutex releases its exact lease after action failure', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'lock' ? 'fictional-lease' : null;
    });
    await expectLater(
      const NativePushBridge().run<void>(
        () async => throw StateError('fictional'),
      ),
      throwsStateError,
    );
    expect(calls.map((c) => c.method), ['lock', 'unlock']);
    expect(calls.last.arguments, {'lease': 'fictional-lease'});
  });
  test(
    'mutex waits for another engine and malformed taps fail closed',
    () async {
      var locks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'lock') return ++locks == 1 ? null : 'lease';
        if (call.method == 'initial') return '{broken';
        return null;
      });
      expect(await const NativePushBridge().run(() async => 7), 7);
      expect(locks, 2);
      expect(await const NativePushBridge().initial(), isNull);
    },
  );
}
