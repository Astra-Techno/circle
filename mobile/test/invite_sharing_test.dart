import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_failure.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/groups/application/invite_sharing.dart';
import 'package:mobile/features/groups/data/invite_share_bridge.dart';
import 'package:mobile/features/groups/domain/circle_group.dart';
import 'package:mobile/features/groups/presentation/invite_share_actions.dart';

final now = DateTime.utc(2026, 10, 27);
InviteShareSnapshot snapshot({
  String session = 'fictional-session',
  Object? owner,
  String token = 'FictionalInvite_Code123',
  bool expired = false,
  int? limit,
}) => InviteShareSnapshot(
  session: session,
  owner: owner,
  origin: Uri.parse('https://fictional.example'),
  link: InviteLink(
    token: token,
    createdBy: '7',
    createdAt: now,
    expiresAt: now.add(Duration(days: expired ? -1 : 7)),
    maxUses: limit,
  ),
);

class ShareBridge extends InviteShareBridge {
  String? phone = '+91 (555) 123-4567';
  Completer<String?>? picker;
  bool available = true;
  int picked = 0, opened = 0;
  String? lastPhone, message;
  InviteShareTarget? target;
  @override
  bool get supported => true;
  @override
  Future<String?> pickPhone() async {
    picked++;
    return picker == null ? phone : picker!.future;
  }

  @override
  Future<bool> compose(
    InviteShareTarget target,
    String message, {
    String? phone,
  }) async {
    opened++;
    this.target = target;
    this.message = message;
    lastPhone = phone;
    return available;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'selected SMS number stays local; web invite preserves case and no private group text',
    () async {
      final bridge = ShareBridge();
      final service = InviteSharing(
        bridge: bridge,
        current: (_) => snapshot(),
        clock: () => now,
      );
      expect(
        await service.share('3', InviteShareTarget.smsContact),
        InviteShareResult.opened,
      );
      expect(bridge.lastPhone, '+915551234567');
      expect(
        bridge.message,
        'Join my circle on CIRCLE:\nhttps://fictional.example/invite.html#FictionalInvite_Code123',
      );
      expect(bridge.picked, 1);
    },
  );
  for (final target in [
    InviteShareTarget.whatsapp,
    InviteShareTarget.smsManual,
    InviteShareTarget.other,
  ]) {
    test('$target opens composer without reading a contact', () async {
      final bridge = ShareBridge();
      await InviteSharing(
        bridge: bridge,
        current: (_) => snapshot(),
        clock: () => now,
      ).share('3', target);
      expect(bridge.picked, 0);
      expect(bridge.opened, 1);
      expect(bridge.lastPhone, isNull);
    });
  }
  test('cancelled contact selection does not compose or report sent', () async {
    final bridge = ShareBridge()..phone = null;
    final result = await InviteSharing(
      bridge: bridge,
      current: (_) => snapshot(),
      clock: () => now,
    ).share('3', InviteShareTarget.smsContact);
    expect(result, InviteShareResult.cancelled);
    expect(bridge.opened, 0);
  });
  for (final mode in [
    'session',
    'api',
    'reset',
    'revoked',
    'expired',
    'exhausted',
  ]) {
    test('$mode during contact picker cannot share stale invite', () async {
      final bridge = ShareBridge()..picker = Completer<String?>();
      InviteShareSnapshot? current = snapshot();
      final service = InviteSharing(
        bridge: bridge,
        current: (_) => current,
        clock: () => now,
      );
      final pending = service.share('3', InviteShareTarget.smsContact);
      final checked = expectLater(pending, throwsA(isA<CircleFailure>()));
      current = switch (mode) {
        'session' => snapshot(session: 'new-session'),
        'api' => snapshot(owner: Object()),
        'reset' => snapshot(token: 'AnotherFictional_Code123'),
        'expired' => snapshot(expired: true),
        'exhausted' => snapshot(limit: 0),
        _ => null,
      };
      bridge.picker!.complete('5551234567');
      await checked;
      expect(bridge.opened, 0);
    });
  }
  test(
    'missing WhatsApp is calm; malformed phone cannot inject composer parameters',
    () async {
      final bridge = ShareBridge()..available = false;
      final service = InviteSharing(
        bridge: bridge,
        current: (_) => snapshot(),
        clock: () => now,
      );
      await expectLater(
        service.share('3', InviteShareTarget.whatsapp),
        throwsA(
          isA<CircleFailure>().having(
            (e) => e.message,
            'message',
            contains('WhatsApp'),
          ),
        ),
      );
      bridge.phone = '555?body=bad';
      await expectLater(
        service.share('3', InviteShareTarget.smsContact),
        throwsA(isA<CircleFailure>()),
      );
      expect(bridge.opened, 1);
    },
  );
  test(
    'native channel uses selected-number picker and draft-only destination',
    () async {
      const channel = MethodChannel('circle/invite_share');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'pickPhone' ? '5551234567' : true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const native = InviteShareBridge();
      expect(await native.pickPhone(), '5551234567');
      expect(
        await native.compose(
          InviteShareTarget.smsContact,
          'Fictional link',
          phone: '5551234567',
        ),
        isTrue,
      );
      expect(calls.last.arguments, {
        'target': 'sms',
        'text': 'Fictional link',
        'phone': '5551234567',
      });
    },
  );
  for (final width in [320.0, 900.0]) {
    testWidgets('SMS explanation/cancel/manual and 200% text at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = ShareBridge();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteShareBridgeProvider.overrideWithValue(bridge),
            inviteSharingProvider.overrideWithValue(
              InviteSharing(
                bridge: bridge,
                current: (_) => snapshot(),
                clock: () => now,
              ),
            ),
          ],
          child: MaterialApp(
            theme: circleTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: InviteShareActions(groupId: '3'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('address book isn’t uploaded'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bridge.picked, 0);
      expect(bridge.opened, 0);
      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enter number in SMS app'));
      await tester.tap(find.text('Enter number in SMS app'));
      await tester.pumpAndSettle();
      expect(bridge.target, InviteShareTarget.smsManual);
      expect(bridge.picked, 0);
      expect(find.textContaining('Review the invite'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
