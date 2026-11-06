import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart' show currentUri;
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';
import 'support/fake_api.dart';
import 'group_photo_ui_test.dart' show image;
import 'screen_audit_visual_review_test.dart' show capture;
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';

void main() {
  for (final layout in [
    (393.0, 1.0, false),
    (393.0, 1.0, true),
    (320.0, 2.0, true),
    (900.0, 2.0, true),
  ]) {
    testWidgets(
      'Circle actions keep full labels ${layout.$1} ${layout.$2} bold=${layout.$3}',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(boldText: layout.$3);
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        });
        final f = RootStyleFixture();
        final c = await openServerCircle(
          tester,
          f.server,
          tokens: await storedSession(f.server, f.owner),
          size: Size(layout.$1, 1100),
        );
        c.read(circleRouterProvider).go('/groups/g/${f.group}');
        await settle(tester);
        for (final label in [
          'Chat',
          'Invite',
          'Events',
          'Polls',
          'Memory',
          'Settings',
        ]) {
          final target = find.byTooltip(label).first;
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final text = find.descendant(of: target, matching: find.text(label));
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        }
        await capture(
          tester,
          'circle-actions',
          '${layout.$1.toInt()}-${layout.$2}-bold-${layout.$3}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cover and Memories fail once and recover through their own Retry',
    (tester) async {
      final f = RootStyleFixture();
      f.server.groups[f.group]!['cover_version'] = 'fictional-cover';
      var coverCalls = 0, pageCalls = 0;
      var failCover = true, failPage = true;
      f.server.adapter.handler = (r) async {
        if (r.path == '/groups/${f.group}/photos/cover') {
          coverCalls++;
          return failCover
              ? FakeResponse.error(503, 'server_error')
              : FakeResponse(200, image.bytes, {'content-type': 'image/png'});
        }
        if (r.path == '/memories' &&
            r.query['group_id'] == f.group.toString()) {
          pageCalls++;
          return failPage
              ? FakeResponse.error(503, 'server_error')
              : FakeResponse.page([], {'has_more': false});
        }
        return f.handle(r);
      };
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/groups/g/${f.group}');
      await settle(tester);
      expect(find.byTooltip('Retry group banner'), findsOneWidget);
      expect(find.byTooltip('Refresh group photos'), findsNothing);
      expect(find.byTooltip('Edit Circle photos'), findsOneWidget);
      expect(find.text("Memories couldn't load"), findsOneWidget);
      expect(find.textContaining('server can’t do this'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      await settle(tester);
      expect(coverCalls, 1);
      expect(pageCalls, 1);
      await capture(tester, 'circle-loading-error', '393-light');
      failCover = false;
      await tester.tap(find.byTooltip('Retry group banner'));
      await settle(tester);
      expect(coverCalls, 2);
      expect(find.byTooltip('Retry group banner'), findsNothing);
      expect(find.byKey(ValueKey('group-cover-${f.group}')), findsOneWidget);
      failPage = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await settle(tester);
      expect(pageCalls, 2);
      expect(find.text('The first Memory is yours to make'), findsOneWidget);
      expect(currentUri(c).path, '/groups/g/${f.group}');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('corrupt cover bytes show one recoverable error', (tester) async {
    final f = RootStyleFixture();
    f.server.groups[f.group]!['cover_version'] = 'fictional-cover';
    var healthy = false;
    var requests = 0;
    f.server.adapter.handler = (r) async {
      if (r.path == '/groups/${f.group}/photos/cover') {
        requests++;
        return FakeResponse(
          200,
          healthy ? image.bytes : Uint8List.fromList([1, 2, 3]),
          {'content-type': 'image/png'},
        );
      }
      return f.handle(r);
    };
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/groups/g/${f.group}');
    await settle(tester);
    expect(find.byTooltip('Retry group banner'), findsOneWidget);
    healthy = true;
    await tester.tap(find.byTooltip('Retry group banner'));
    await settle(tester);
    expect(requests, 2);
    final cover = find.byKey(ValueKey('group-cover-${f.group}'));
    final provider = tester.widget<Image>(cover).image;
    await tester.runAsync(() => precacheImage(provider, tester.element(cover)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retry group banner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo menu rejects permission changes before choosing a kind', (
    tester,
  ) async {
    final f = RootStyleFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/groups/g/${f.group}');
    await settle(tester);
    await tester.tap(find.byTooltip('Edit Circle photos'));
    await settle(tester);
    f.server.members[f.group]![f.owner] = 'member';
    f.server.groups[f.group]!['owner_user_id'] = 9999;
    final refresh = c.read(circleWorkspaceProvider.notifier).refresh();
    await settle(tester);
    await refresh;
    await tester.tap(find.text('Circle photo'));
    await settle(tester);
    expect(find.text('Choose a photo'), findsNothing);
    expect(
      find.text('Only current group admins can change these photos.'),
      findsOneWidget,
    );
    expect(
      f.server.adapter.count('PUT', '/groups/${f.group}/photos/avatar'),
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
