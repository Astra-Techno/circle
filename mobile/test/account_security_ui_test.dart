import 'package:mobile/core/platform/session_device.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/core/notifications/push_lifecycle.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'support/server_harness.dart';
import 'support/fake_api.dart';

class FakeSessionDevice extends SessionDevice {
  int calls = 0;
  @override
  Future<Map<String, String>> details() async => {};
  @override
  Future<String> approximateLocation() async {
    calls++;
    return 'Fictional Updated City';
  }
}

Map<String, Object?> row(bool current) => {
  'id': (current ? 'a' : 'b') * 32,
  'is_current': current,
  'device_label': current ? 'Fictional phone' : 'Fictional tablet',
  'os_version': 'Android 16',
  'app_version': '1.0.12 (13)',
  'ip_address': '192.0.2.8',
  'location_label': current ? 'Fictional City, Test Region' : null,
  'location_updated_at': current ? '2026-10-27 12:00:00' : null,
  'created_at': '2026-10-26 12:00:00',
  'last_seen_at': '2026-10-27 12:01:00',
};
Future<ProviderContainer> open(
  WidgetTester tester, {
  Size size = const Size(393, 1000),
  FakeSessionDevice? device,
  FakeHandler? password,
}) async {
  final server = FakeCircleServer();
  final owner = server.addUser(
    '+15550000001',
    'fictional password',
    'Fictional Tester',
  );
  final container = await openServerCircle(
    tester,
    server,
    sessionDevice: device,
    tokens: await storedSession(server, owner),
    size: size,
  );
  final api = container.read(apiClientProvider)!;
  final rows = [row(true), row(false)];
  api.dio.httpClientAdapter = FakeHttpAdapter((r) async {
    if (r.path == '/me/sessions') {
      return FakeResponse.page(rows, {
        'total': rows.length,
        'limit': 30,
        'offset': 0,
      });
    }
    if (r.path == '/me/session') {
      if (r.json.containsKey('location_label')) {
        rows.first['location_label'] = r.json['location_label'];
      }
      return FakeResponse.ok(null);
    }
    if (r.path.startsWith('/me/sessions/') && r.method == 'DELETE') {
      rows.removeWhere((x) => x['id'] == r.path.split('/').last);
      return FakeResponse.ok({'current_session_revoked': false});
    }
    if (r.path == '/auth/change-password') {
      return password == null
          ? FakeResponse.ok({'sign_in_required': true})
          : await password(r);
    }
    return server.handle(r);
  });
  return container;
}

void main() {
  testWidgets(
    'password success clears auth/drafts and invalidates optional push independently',
    (tester) async {
      final c = await open(tester);
      final api = c.read(apiClientProvider)!;
      final account = c.read(serverAccountProvider)!.id;
      final drafts = c.read(memoryDraftStoreProvider);
      final scope = DraftScope(
        server: api.config.baseUrl.toString(),
        account: account,
      );
      final lease = drafts.open(scope);
      await drafts.save(
        lease,
        const MemoryTextDraft(text: 'Fictional private draft'),
      );
      var invalidated = false;
      c.read(pushLifecycleProvider).listen(() {
        throw StateError('Optional SDK failure');
      });
      c.read(pushLifecycleProvider).listen(() {
        invalidated = true;
      });
      c.read(circleRouterProvider).go('/you/account/password');
      await settle(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fictional password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'a new secure password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'a new secure password',
      );
      await tester.ensureVisible(find.text('Change password and log out'));
      await tester.tap(find.text('Change password and log out'));
      await settle(tester);
      expect(c.read(serverAccountProvider), isNull);
      expect(await api.currentTokens(), isNull);
      expect(invalidated, isTrue);
      expect(await drafts.read(drafts.open(scope)), isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain password result disables resubmission and gives sign-in guidance',
    (tester) async {
      var calls = 0;
      final c = await open(
        tester,
        password: (r) async {
          calls++;
          return FakeResponse.error(500, 'server_error');
        },
      );
      c.read(circleRouterProvider).go('/you/account/password');
      await settle(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fictional password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'a new secure password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'a new secure password',
      );
      await tester.ensureVisible(find.text('Change password and log out'));
      await tester.tap(find.text('Change password and log out'));
      await settle(tester);
      expect(calls, 1);
      expect(find.text('Log out and sign in'), findsOneWidget);
      expect(find.text('Change password and log out'), findsNothing);
      expect(
        find.textContaining('Don’t send the change again'),
        findsOneWidget,
      );
    },
  );
  testWidgets('late password completion preserves a newer same-account login', (
    tester,
  ) async {
    final started = Completer<void>(), release = Completer<void>();
    final c = await open(
      tester,
      password: (r) async {
        started.complete();
        await release.future;
        return FakeResponse.ok({'sign_in_required': true});
      },
    );
    c.read(circleRouterProvider).go('/you/account/password');
    await settle(tester);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'fictional password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'a new secure password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'a new secure password',
    );
    await tester.ensureVisible(find.text('Change password and log out'));
    await tester.tap(find.text('Change password and log out'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(started.isCompleted, isTrue);
    final api = c.read(apiClientProvider)!;
    final tokens = (await api.currentTokens())!;
    await api.saveTokens(
      TokenPair(
        accessToken: 'fictional-newer-login',
        refreshToken: 'fictional-newer-refresh',
        server: tokens.server,
        account: tokens.account,
      ),
    );
    release.complete();
    await settle(tester);
    expect(c.read(serverAccountProvider), isNotNull);
    expect((await api.currentTokens())!.accessToken, 'fictional-newer-login');
  });

  testWidgets(
    'device session logout refreshes list without signing out this device',
    (tester) async {
      final c = await open(tester);
      c.read(circleRouterProvider).go('/you/account/sessions');
      await settle(tester);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Fictional tablet'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Log out session'), 400);
      await Scrollable.ensureVisible(
        tester.element(find.text('Log out session')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out session'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await settle(tester);
      expect(find.text('Fictional tablet'), findsNothing);
      expect(c.read(serverAccountProvider), isNotNull);
    },
  );
  testWidgets(
    'location is shared only after explicit confirmation and can be removed',
    (tester) async {
      final device = FakeSessionDevice();
      final c = await open(tester, device: device);
      c.read(circleRouterProvider).go('/you/account/sessions');
      await settle(tester);
      expect(device.calls, 0);
      await tester.scrollUntilVisible(find.text('Remove location'), 300);
      await tester.tap(find.text('Remove location'));
      await settle(tester);
      expect(find.text('Add location'), findsOneWidget);
      await tester.tap(find.text('Add location'));
      await settle(tester);
      expect(device.calls, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);
      expect(device.calls, 1);
      expect(find.textContaining('Fictional Updated City'), findsOneWidget);
    },
  );
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      for (final page in ['password', 'sessions']) {
        testWidgets('$page $width ${brightness.name} at 200% text', (
          tester,
        ) async {
          final c = await open(tester, size: Size(width, 1100));
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          c
              .read(themeProvider.notifier)
              .change(
                brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
              );
          c.read(circleRouterProvider).go('/you/account/$page');
          await settle(tester);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/circle-security-$page-$width-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
}
