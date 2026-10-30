import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/theme_controller.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

final picture = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR4nGNocFhAEmIY1TCqYfhqAAACpWAQ99uwLAAAAABJRU5ErkJggg==',
);
void main() {
  testWidgets(
    'another shared member sees both uploaded photos and refresh removes deleted photos',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+15550000001',
        'fictional password',
        'Fictional Owner',
      );
      final viewer = server.addUser(
        '+15550000002',
        'fictional password',
        'Fictional Viewer',
      );
      final group = server.addGroup('Fictional friends', owner);
      server.members[group]![viewer] = 'member';
      for (final kind in ['avatar', 'cover']) {
        server.profilePhotos['$owner:$kind'] = (
          bytes: picture,
          mime: 'image/png',
        );
      }
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, viewer),
      );
      c.read(circleRouterProvider).go('/people/$owner');
      await settle(tester);
      expect(find.byKey(ValueKey('shared-avatar-$owner')), findsOneWidget);
      expect(find.byKey(ValueKey('shared-cover-$owner')), findsOneWidget);
      expect(server.adapter.count('GET', '/profiles/$owner/photos/avatar'), 1);
      expect(server.adapter.count('GET', '/profiles/$owner/photos/cover'), 1);
      expect(server.adapter.count('GET', '/me/photos/avatar'), 0);
      server.profilePhotos.clear();
      await tester.tap(find.text('Photo options'));
      await settle(tester);
      await tester.tap(find.text('Refresh photos'));
      await settle(tester);
      expect(find.byKey(ValueKey('shared-avatar-$owner')), findsNothing);
      expect(find.byKey(ValueKey('shared-cover-$owner')), findsNothing);
      expect(find.byTooltip('Retry loading profile photo'), findsNothing);
      expect(find.byTooltip('Retry loading cover photo'), findsNothing);
      expect(server.adapter.count('GET', '/profiles/$owner/photos/avatar'), 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a stranger cannot fetch or render another person’s photos', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15550000001',
      'fictional password',
      'Fictional Owner',
    );
    final viewer = server.addUser(
      '+15550000002',
      'fictional password',
      'Fictional Stranger',
    );
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, viewer),
    );
    c.read(circleRouterProvider).go('/people/$owner');
    await settle(tester);
    expect(find.text('This profile isn’t available'), findsOneWidget);
    expect(
      server.adapter.requests.where((r) => r.path.startsWith('/profiles/')),
      isEmpty,
    );
  });
  testWidgets('late photo bytes cannot cross a newer same-account session', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15550000001',
      'fictional password',
      'Fictional Owner',
    );
    final viewer = server.addUser(
      '+15550000002',
      'fictional password',
      'Fictional Viewer',
    );
    final group = server.addGroup('Fictional friends', owner);
    server.members[group]![viewer] = 'member';
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, viewer),
    );
    final api = c.read(apiClientProvider)!;
    final release = Completer<void>();
    api.dio.httpClientAdapter = FakeHttpAdapter((r) async {
      if (r.path.startsWith('/profiles/')) {
        await release.future;
        return FakeResponse(200, picture, {'content-type': 'image/png'});
      }
      return server.handle(r);
    });
    c.read(circleRouterProvider).go('/people/$owner');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final tokens = (await api.currentTokens())!;
    await api.saveTokens(
      TokenPair(
        accessToken: 'fictional-new-session',
        refreshToken: 'fictional-new-refresh',
        server: tokens.server,
        account: tokens.account,
      ),
    );
    release.complete();
    await settle(tester);
    expect(find.byKey(ValueKey('shared-avatar-$owner')), findsNothing);
    expect(find.byKey(ValueKey('shared-cover-$owner')), findsNothing);
    expect((await api.currentTokens())!.accessToken, 'fictional-new-session');
  });
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('shared profile $width ${brightness.name} at 200% text', (
        tester,
      ) async {
        final server = FakeCircleServer();
        final owner = server.addUser(
          '+15550000001',
          'fictional password',
          'Fictional Owner',
        );
        final viewer = server.addUser(
          '+15550000002',
          'fictional password',
          'Fictional Viewer',
        );
        final group = server.addGroup('Fictional friends', owner);
        server.members[group]![viewer] = 'member';
        for (final kind in ['avatar', 'cover']) {
          server.profilePhotos['$owner:$kind'] = (
            bytes: picture,
            mime: 'image/png',
          );
        }
        final c = await openServerCircle(
          tester,
          server,
          tokens: await storedSession(server, viewer),
          size: Size(width, 1000),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        c
            .read(themeProvider.notifier)
            .change(
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            );
        c.read(circleRouterProvider).go('/people/$owner');
        await settle(tester);
        expect(find.byKey(ValueKey('shared-avatar-$owner')), findsOneWidget);
        expect(find.byKey(ValueKey('shared-cover-$owner')), findsOneWidget);
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
              '/tmp/circle-shared-profile-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
