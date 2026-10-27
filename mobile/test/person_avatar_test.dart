import 'support/circle_harness.dart' show openTab;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:mobile/core/theme_controller.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';
import 'package:mobile/features/profile/presentation/person_avatar.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

final photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR4nGNocFhAEmIY1TCqYfhqAAACpWAQ99uwLAAAAABJRU5ErkJggg==',
);
const version = '00000000-0000-4000-8000-000000000001';
void main() {
  test(
    'avatar LRU is bounded, expires lazily and cannot reuse a previous session',
    () {
      var now = DateTime.utc(2026, 10, 27);
      final cache = PersonPhotoCache(() => now);
      cache.put('photo', Uint8List.fromList([1]), 1);
      expect(cache.read('photo', 1)!.bytes, [1]);
      now = now.add(const Duration(seconds: 46));
      expect(cache.read('photo', 1), isNull);
      cache.put('photo', Uint8List.fromList([2]), 1);
      expect(cache.read('photo', 2), isNull);
      for (var i = 0; i < 65; i++) {
        cache.put('$i', Uint8List.fromList([i]), 2);
      }
      expect(cache.read('0', 2), isNull);
      expect(cache.read('64', 2), isNotNull);
      cache.clear();
      expect(cache.read('64', 2), isNull);
    },
  );
  testWidgets(
    'Memory authors and group members reuse one private avatar by person ID',
    (tester) async {
      final server = FakeCircleServer();
      final author = server.addUser(
        '+15550000001',
        'fictional password',
        'Same Name',
      );
      final viewer = server.addUser(
        '+15550000002',
        'fictional password',
        'Same Name',
      );
      final group = server.addGroup('Fictional friends', author);
      server.members[group]![viewer] = 'member';
      server.users[author]!['avatar_version'] = version;
      server.profilePhotos['$author:avatar'] = (
        bytes: photo,
        mime: 'image/png',
      );
      final memory = server.addMemory(group, author, 'Fictional first Memory');
      server.comments[memory] = [
        {
          'id': 999,
          'author_id': author,
          'author_name': 'Same Name',
          'body': 'Fictional comment',
          'created_at': FakeCircleServer.now,
          'parent_id': null,
        },
      ];
      server.addMemory(group, author, 'Fictional second Memory');
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, viewer),
        size: const Size(393, 1600),
      );
      await settle(tester);
      Finder avatar() => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is PersonAvatar && w.person == '$author',
        ),
        matching: find.byType(CircleAvatar),
      );
      expect(avatar(), findsAtLeastNWidgets(1));
      for (final w in tester.widgetList<CircleAvatar>(avatar())) {
        expect(w.foregroundImage, isA<MemoryImage>());
      }
      expect(server.adapter.count('GET', '/profiles/$author/photos/avatar'), 1);
      expect(server.adapter.count('GET', '/profiles/$viewer/photos/avatar'), 0);
      c.read(circleRouterProvider).go('/home/memory/$memory');
      await settle(tester);
      expect(avatar(), findsAtLeastNWidgets(2));
      expect(server.adapter.count('GET', '/profiles/$author/photos/avatar'), 1);
      c.read(circleRouterProvider).go('/groups/g/$group');
      await settle(tester);
      await openTab(tester, 'Members');
      await settle(tester);
      expect(avatar(), findsAtLeastNWidgets(1));
      expect(
        tester.widget<CircleAvatar>(avatar().first).foregroundImage,
        isA<MemoryImage>(),
      );
      expect(server.adapter.count('GET', '/profiles/$author/photos/avatar'), 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workspace refresh replaces and removes list avatars without cached stale bytes',
    (tester) async {
      final server = FakeCircleServer();
      final author = server.addUser(
        '+15550000001',
        'fictional password',
        'Fictional Author',
      );
      final viewer = server.addUser(
        '+15550000002',
        'fictional password',
        'Fictional Viewer',
      );
      final group = server.addGroup('Fictional friends', author);
      server.members[group]![viewer] = 'member';
      server.users[author]!['avatar_version'] = version;
      server.profilePhotos['$author:avatar'] = (
        bytes: photo,
        mime: 'image/png',
      );
      server.addMemory(group, author, 'Fictional Memory');
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, viewer),
      );
      await settle(tester);
      expect(
        c.read(circleWorkspaceProvider).value!.avatarVersions['$author'],
        version,
      );
      server.users[author]!['avatar_version'] =
          '00000000-0000-4000-8000-000000000002';
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await settle(tester);
      expect(server.adapter.count('GET', '/profiles/$author/photos/avatar'), 2);
      server.users[author]!['avatar_version'] = null;
      server.profilePhotos.remove('$author:avatar');
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await settle(tester);
      final avatars = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is PersonAvatar && w.person == '$author',
        ),
        matching: find.byType(CircleAvatar),
      );
      expect(
        tester.widget<CircleAvatar>(avatars.first).foregroundImage,
        isNull,
      );
      // A previously subscribed provider may confirm removal with one 404.
      expect(
        server.adapter.count('GET', '/profiles/$author/photos/avatar'),
        lessThanOrEqualTo(3),
      );
    },
  );
  testWidgets('large member lists request avatars for the first page only', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15550000001',
      'fictional password',
      'Fictional Owner',
    );
    final group = server.addGroup('Fictional large group', owner);
    for (var i = 0; i < 40; i++) {
      final id = server.addUser(
        '+15551${i.toString().padLeft(6, '0')}',
        'fictional password',
        'Member $i',
      );
      server.members[group]![id] = 'member';
      server.users[id]!['avatar_version'] = version;
      server.profilePhotos['$id:avatar'] = (bytes: photo, mime: 'image/png');
    }
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, owner),
    );
    c.read(circleRouterProvider).go('/groups/g/$group');
    await settle(tester);
    await openTab(tester, 'Members');
    await settle(tester);
    expect(find.byType(PersonAvatar), findsNWidgets(30));
    expect(find.text('Show more members'), findsOneWidget);
    expect(
      server.adapter.requests
          .where((r) => r.path.startsWith('/profiles/'))
          .length,
      lessThanOrEqualTo(30),
    );
  });
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      for (final page in ['memories', 'members']) {
        testWidgets('$page avatars $width ${brightness.name} at 200% text', (
          tester,
        ) async {
          final server = FakeCircleServer();
          final author = server.addUser(
            '+15550000001',
            'fictional password',
            'Fictional Author',
          );
          final viewer = server.addUser(
            '+15550000002',
            'fictional password',
            'Fictional Viewer',
          );
          final group = server.addGroup('Fictional friends', author);
          server.members[group]![viewer] = 'member';
          server.users[author]!['avatar_version'] = version;
          server.profilePhotos['$author:avatar'] = (
            bytes: photo,
            mime: 'image/png',
          );
          final memory = server.addMemory(
            group,
            author,
            'A fictional Memory with a private avatar.',
          );
          server.comments[memory] = [
            {
              'id': 999,
              'author_id': author,
              'author_name': 'Fictional Author',
              'body': 'A fictional comment.',
              'created_at': FakeCircleServer.now,
              'parent_id': null,
            },
          ];
          final c = await openServerCircle(
            tester,
            server,
            tokens: await storedSession(server, viewer),
            size: Size(width, 1100),
          );
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          c
              .read(themeProvider.notifier)
              .change(
                brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
              );
          if (page == 'members') {
            c.read(circleRouterProvider).go('/groups/g/$group');
            await settle(tester);
            await openTab(tester, 'Members');
          }
          await settle(tester);
          expect(tester.takeException(), isNull);
          final avatars = find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is PersonAvatar && w.person == '$author',
            ),
            matching: find.byType(CircleAvatar),
          );
          expect(avatars, findsAtLeastNWidgets(1));
          expect(
            tester.widget<CircleAvatar>(avatars.first).foregroundImage,
            isA<MemoryImage>(),
          );
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
                '/tmp/circle-all-avatar-$page-$width-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
}
