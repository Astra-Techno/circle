import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/private_photo.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';
import 'live_chat_events_test.dart' show LiveFixture;
import 'support/fake_api.dart';
import 'support/server_harness.dart';

class MediaPicker implements ProfilePhotoPicker {
  bool cancel = false;
  final photo = ProfilePickedPhoto(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR4nGNocFhAEmIY1TCqYfhqAAACpWAQ99uwLAAAAABJRU5ErkJggg==',
    ),
    mimeType: 'image/png',
  );
  @override
  Future<ProfilePickedPhoto?> pick() async => cancel ? null : photo;
}

void wireMedia(LiveFixture f, MediaPicker picker) {
  f.server.adapter.handler = (r) async {
    if (r.path.startsWith('/chats/501/uploads/') && r.method == 'PUT') {
      return FakeResponse.ok({'id': r.path.split('/').last});
    }
    if (r.path.startsWith('/chats/501/media/') ||
        (r.path == '/events/91/cover' && r.method == 'GET')) {
      return FakeResponse(200, picker.photo.bytes, {
        'content-type': 'image/png',
      });
    }
    if (r.path == '/chats/501/messages' && r.method == 'POST') {
      f.messages.add({
        'id': 1,
        'author_id': f.owner,
        'display_name': 'Fictional Owner',
        'body': r.json['body'],
        'attachments': r.json['attachments'],
        'removed': false,
        'edited': false,
        'reply_to_id': null,
        'reactions': [],
      });
      return FakeResponse.ok({'id': 1});
    }
    if (r.path == '/events/91/cover') {
      expect(r.query['version'], '${f.event['version']}');
      f.event['version'] = (f.event['version'] as int) + 1;
      f.event['cover_id'] = r.method == 'DELETE'
          ? null
          : 'fictional-cover-uuid';
      return FakeResponse.ok(f.event);
    }
    return f.handle(r);
  };
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  for (final width in [320.0, 900.0]) {
    for (final dark in [false, true]) {
      for (final surface in ['chat', 'event']) {
        testWidgets('media $surface $width dark=$dark 200% text', (
          tester,
        ) async {
          final f = LiveFixture();
          final picker = MediaPicker();
          wireMedia(f, picker);
          f.event['cover_id'] = 'fictional-cover';
          f.messages.add({
            'id': 1,
            'author_id': f.owner,
            'display_name': 'Fictional Owner',
            'body': 'A shared moment',
            'attachments': ['fictional-photo'],
            'removed': false,
            'edited': false,
            'reply_to_id': null,
            'reactions': [],
          });
          final c = await openServerCircle(
            tester,
            f.server,
            tokens: await storedSession(f.server, f.owner),
            size: Size(width, 1000),
          );
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          c
              .read(themeProvider.notifier)
              .change(dark ? ThemeMode.dark : ThemeMode.light);
          c
              .read(circleRouterProvider)
              .go(surface == 'chat' ? '/chats/c/501' : '/events/e/91');
          await settle(tester);
          expect(find.byType(PrivatePhoto), findsOneWidget);
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
                '/tmp/circle-media-$surface-$width-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets(
    'chat photos attach with no caption, render, expand and clear after send',
    (tester) async {
      final f = LiveFixture();
      final picker = MediaPicker();
      wireMedia(f, picker);
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
        profilePicker: picker,
      );
      c.read(circleRouterProvider).go('/chats/c/501');
      await settle(tester);
      picker.cancel = true;
      await tapVisible(tester, find.text('Add photo'));
      expect(
        f.server.adapter.requests.where((r) => r.path.contains('/uploads/')),
        isEmpty,
      );
      picker.cancel = false;
      await tapVisible(tester, find.text('Add photo'));
      expect(find.text('Photo 1'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Send'));
      expect(f.messages.single['body'], '');
      expect(f.messages.single['attachments'], hasLength(1));
      expect(find.text('Photo 1'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await settle(tester);
      expect(find.byType(PrivatePhoto), findsOneWidget);
      await tester.tap(find.byType(PrivatePhoto));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'event cover add change and remove use current version and private bytes',
    (tester) async {
      final f = LiveFixture();
      final picker = MediaPicker();
      wireMedia(f, picker);
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
        profilePicker: picker,
      );
      c.read(circleRouterProvider).go('/events/e/91');
      await settle(tester);
      await tapVisible(tester, find.text('Add cover photo'));
      expect(f.event['version'], 2);
      expect(find.byType(PrivatePhoto), findsOneWidget);
      await tapVisible(tester, find.text('Change cover photo'));
      expect(f.event['version'], 3);
      await tapVisible(tester, find.text('Remove cover'));
      expect(f.event['cover_id'], isNull);
      expect(f.event['version'], 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pending direct requests never show a photo upload action', (
    tester,
  ) async {
    final f = LiveFixture()
      ..direct = true
      ..pendingRequest = true;
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/chats/c/501');
    await settle(tester);
    expect(find.text('Add photo'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('photo viewer removes bytes when access is revoked', (
    tester,
  ) async {
    final photo = MediaPicker().photo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivatePhoto(
            load: AsyncData<Uint8List>(photo.bytes),
            label: 'Fictional photo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(PrivatePhoto));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivatePhoto(
            load: AsyncError<Uint8List>(
              StateError('Fictional access lost'),
              StackTrace.current,
            ),
            label: 'Fictional photo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Photo unavailable'), findsOneWidget);
  });
}
