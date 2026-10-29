import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/features/groups/application/group_photos.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

class GroupPicker implements ProfilePhotoPicker {
  ProfilePickedPhoto? result;
  Completer<ProfilePickedPhoto?>? pending;
  @override
  Future<ProfilePickedPhoto?> pick() async => pending?.future ?? result;
}

final image = ProfilePickedPhoto(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR4nGNocFhAEmIY1TCqYfhqAAACpWAQ99uwLAAAAABJRU5ErkJggg==',
  ),
  mimeType: 'image/png',
);
void main() {
  testWidgets('admin adds replaces and independently removes group photos', (
    tester,
  ) async {
    final server = FakeCircleServer(mediaAvailable: true);
    final owner = server.addUser(
      '+9995550000782',
      'fictional password',
      'Owner',
    );
    final id = server.addGroup('Fictional friends', owner);
    final picker = GroupPicker();
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, owner),
      profilePicker: picker,
    );
    c.read(circleRouterProvider).go('/groups/g/$id');
    await settle(tester);
    Future<void> choose(String button, String action) async {
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip(button)),
        alignment: 0.5,
      );
      await tester.tap(find.byTooltip(button));
      await settle(tester);
      await tester.tap(find.text(action));
      await settle(tester);
    }

    await choose('Add group picture', 'Choose a photo');
    expect(server.adapter.count('PUT', '/groups/$id/photos/avatar'), 0);
    picker.result = image;
    await choose('Add group picture', 'Choose a photo');
    final original = server.groups[id]!['avatar_version'];
    expect(original, isNotNull);
    await choose('Add banner', 'Choose a photo');
    final cover = server.groups[id]!['cover_version'];
    expect(cover, isNotNull);
    expect(find.byKey(ValueKey('group-cover-$id')), findsOneWidget);
    await choose('Change group picture', 'Replace photo');
    expect(server.groups[id]!['avatar_version'], isNot(original));
    await choose('Change group picture', 'Remove photo');
    expect(server.groups[id]!['avatar_version'], isNull);
    expect(server.groups[id]!['cover_version'], cover);
    await choose('Change banner', 'Remove photo');
    expect(server.groupPhotos, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'member views banner without edit controls and stale admin picker cannot upload',
    (tester) async {
      final server = FakeCircleServer(mediaAvailable: true);
      final owner = server.addUser(
        '+9995550000783',
        'fictional password',
        'Owner',
      );
      final id = server.addGroup('Fictional friends', owner);
      final picker = GroupPicker()..pending = Completer<ProfilePickedPhoto?>();
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
        profilePicker: picker,
      );
      final actions = c.read(groupPhotoActionsProvider);
      final scope = actions.capture('$id');
      final pending = actions.change(
        scope,
        ProfilePhotoKind.avatar,
        remove: false,
      );
      final assertion = expectLater(pending, throwsA(anything));
      server.members[id]![owner] = 'member';
      server.groups[id]!['owner_user_id'] = 9999;
      server.groups[id]!['cover_version'] = 'fictional-cover';
      server.groupPhotos['$id:cover'] = (
        bytes: image.bytes,
        mime: image.mimeType,
      );
      final refresh = c.read(circleWorkspaceProvider.notifier).refresh();
      await settle(tester);
      await refresh;
      picker.pending!.complete(image);
      await tester.pump();
      await assertion;
      expect(server.adapter.count('PUT', '/groups/$id/photos/avatar'), 0);
      c.read(circleRouterProvider).go('/groups/g/$id');
      await settle(tester);
      expect(find.byTooltip('Add group picture'), findsNothing);
      expect(find.byTooltip('Change banner'), findsNothing);
      expect(find.byKey(ValueKey('group-cover-$id')), findsOneWidget);
      server.groups[id]!['cover_version'] = 'fictional-replacement';
      await tester.tap(find.byTooltip('Refresh group photos'));
      await settle(tester);
      expect(
        c.read(circleWorkspaceProvider).value!.group('$id')!.coverVersion,
        'fictional-replacement',
      );
      expect(
        server.adapter.count('GET', '/groups/$id/photos/cover'),
        greaterThanOrEqualTo(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a newer same-account session blocks an old picker upload', (
    tester,
  ) async {
    final server = FakeCircleServer(mediaAvailable: true);
    final owner = server.addUser(
      '+9995550000785',
      'fictional password',
      'Owner',
    );
    final id = server.addGroup('Fictional friends', owner);
    final picker = GroupPicker()..pending = Completer<ProfilePickedPhoto?>();
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, owner),
      profilePicker: picker,
    );
    final actions = c.read(groupPhotoActionsProvider);
    final pending = actions.change(
      actions.capture('$id'),
      ProfilePhotoKind.cover,
      remove: false,
    );
    final assertion = expectLater(pending, throwsA(anything));
    final api = c.read(apiClientProvider)!;
    final tokens = (await api.currentTokens())!;
    await api.saveTokens(
      TokenPair(
        accessToken: 'fictional-new-session',
        refreshToken: tokens.refreshToken,
        server: tokens.server,
      ),
    );
    picker.pending!.complete(image);
    await tester.pump();
    await assertion;
    expect(server.adapter.count('PUT', '/groups/$id/photos/cover'), 0);
  });
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('group branding $width ${brightness.name} at 200% text', (
        tester,
      ) async {
        final server = FakeCircleServer(mediaAvailable: true);
        final owner = server.addUser(
          '+9995550000784',
          'fictional password',
          'Owner',
        );
        final id = server.addGroup('Fictional friends', owner);
        for (final kind in ['avatar', 'cover']) {
          server.groups[id]!['${kind}_version'] = 'fictional-$kind';
          server.groupPhotos['$id:$kind'] = (
            bytes: image.bytes,
            mime: image.mimeType,
          );
        }
        final c = await openServerCircle(
          tester,
          server,
          tokens: await storedSession(server, owner),
          size: Size(width, 1000),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        c
            .read(themeProvider.notifier)
            .change(
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            );
        c.read(circleRouterProvider).go('/groups/g/$id');
        await settle(tester);
        // At 200% text the banner steps aside; its controls stay.
        expect(find.byKey(ValueKey('group-cover-$id')), findsNothing);
        expect(find.byTooltip('Change banner'), findsOneWidget);
        expect(find.byTooltip('Change group picture'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final capture = await boundary.toImage();
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/circle-group-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
      });
    }
  }
}
