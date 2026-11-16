import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/profile/presentation/person_avatar.dart';
import 'support/circle_harness.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';
import 'screen_audit_visual_review_test.dart' show capture;

void main() {
  for (final layout in [
    (393.0, 844.0, 1.0, Brightness.light, 0.0),
    (393.0, 844.0, 1.0, Brightness.dark, 34.0),
    (320.0, 1000.0, 2.0, Brightness.dark, 34.0),
    (900.0, 1100.0, 2.0, Brightness.light, 0.0),
  ]) {
    testWidgets(
      'icon dock is centered and inset ${layout.$1} ${layout.$3} ${layout.$4.name}',
      (tester) async {
        tester.view.padding = FakeViewPadding(bottom: layout.$5);
        tester.view.viewPadding = FakeViewPadding(bottom: layout.$5);
        addTearDown(() {
          tester.view.resetPadding();
          tester.view.resetViewPadding();
        });
        await openCircle(
          tester,
          size: Size(layout.$1, layout.$2),
          scale: layout.$3,
          brightness: layout.$4,
        );
        final dock = tester.getRect(
          find.byKey(const ValueKey('circle-navigation-dock')),
        );
        expect(dock.height, CircleLayout.homeDockHeight);
        expect(
          dock.bottom,
          layout.$2 - CircleLayout.navigationBottomPadding(layout.$5),
        );
        expect(dock.width, lessThanOrEqualTo(CircleLayout.homeDockMaxWidth));
        final items = ['Home', 'Circles', 'Chats', 'Events', 'Profile'];
        final centers = <double>[];
        for (final label in items) {
          expect(find.text(label), findsNothing);
          final target = tester.getRect(find.byTooltip(label));
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));
          expect(target.center.dy, closeTo(dock.center.dy, 0.01));
          centers.add(target.center.dx);
        }
        for (var i = 1; i < centers.length; i++) {
          expect(centers[i] - centers[i - 1], closeTo(dock.width / 5, 0.01));
        }
        final avatar = find.descendant(
          of: find.byTooltip('Profile'),
          matching: find.byType(PersonAvatar),
        );
        expect(avatar, findsOneWidget);
        expect(tester.getCenter(avatar).dy, closeTo(dock.center.dy, 0.01));
        await capture(
          tester,
          'icon-navigation',
          '${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'icon tabs retain accessible names, selection and all five routes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = RootStyleFixture();
        final c = await openServerCircle(
          tester,
          fixture.server,
          tokens: await storedSession(fixture.server, fixture.owner),
        );
        for (final item in [
          ('Home', '/home'),
          ('Circles', '/groups'),
          ('Chats', '/chats'),
          ('Events', '/events'),
          ('Profile', '/you'),
        ]) {
          await tester.tap(find.byTooltip(item.$1));
          await tester.pumpAndSettle();
          expect(currentUri(c).path, item.$2);
          final data = tester
              .getSemantics(find.byKey(ValueKey('navigation-tab-${item.$1}')))
              .getSemanticsData();
          expect(data.label, item.$1);
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        }
        final avatar = tester.widget<PersonAvatar>(
          find.descendant(
            of: find.byTooltip('Profile'),
            matching: find.byType(PersonAvatar),
          ),
        );
        expect(avatar.person, fixture.owner.toString());
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
