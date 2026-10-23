import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/app/workspace_providers.dart';

Future<ProviderContainer> openCircle(
  WidgetTester tester, {
  bool entered = true,
  bool showcase = true,
  Size size = const Size(393, 852),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (entered) {
    container
        .read(circlePreviewSessionProvider.notifier)
        .enter(showcase: showcase);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CircleExperience(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> revealCircle(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 50,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'welcome offers open registration and an explicit fictional tour',
    (tester) async {
      await openCircle(tester, entered: false);
      await revealCircle(tester, find.text('Explore fictional circles'));
      await tester.tap(find.text('Explore fictional circles'));
      await tester.pumpAndSettle();
      expect(find.text('Memories'), findsOneWidget);
      for (final label in ['Home', 'Chats', 'Groups', 'Events', 'You']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
        );
      }
      expect(find.text('Shared with The Sunday table'), findsOneWidget);
    },
  );
  testWidgets(
    'mobile/password preview grants no sample memberships; first group and Memory work',
    (tester) async {
      final container = await openCircle(tester, entered: false);
      await revealCircle(tester, find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('access-mobile')),
        '+99912345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('access-password')),
        'a fictional passphrase',
      );
      await revealCircle(tester, find.text('Preview registration'));
      await tester.tap(find.text('Preview registration'));
      await tester.pumpAndSettle();
      expect(
        container.read(circleWorkspaceProvider).requireValue.groups,
        isEmpty,
      );
      await revealCircle(tester, find.text('Create a group'));
      await tester.tap(find.text('Create a group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Our weekend circle');
      await revealCircle(tester, find.text('Create private group'));
      await tester.tap(find.text('Create private group'));
      await tester.pumpAndSettle();
      expect(
        container.read(circleWorkspaceProvider).requireValue.groups.single.name,
        'Our weekend circle',
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Memory'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Our first shared moment.',
      );
      await revealCircle(tester, find.text('Share Memory'));
      await tester.tap(find.text('Share Memory'));
      await tester.pumpAndSettle();
      expect(find.text('Our first shared moment.'), findsOneWidget);
    },
  );
  testWidgets(
    'group detail stack survives tab switches and hidden content stays denied',
    (tester) async {
      final container = await openCircle(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'window-seat');
      await tester.pumpAndSettle();
      await tester.tap(find.text('The window-seat crew'));
      await tester.pumpAndSettle();
      expect(find.text('Computer science'), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Computer science'), findsOneWidget);
      container.read(circleRouterProvider).go('/groups/g/private-plans');
      await tester.pumpAndSettle();
      expect(find.text('This circle is private'), findsOneWidget);
      expect(find.text('A private planning note.'), findsNothing);
    },
  );
  testWidgets(
    'love, save, comments, RSVP and ending preview persist then clear',
    (tester) async {
      final container = await openCircle(tester);
      await tester.tap(find.byTooltip('Save Memory').first);
      await tester.pumpAndSettle();
      container.read(circleRouterProvider).go('/home/memory/table');
      await tester.pumpAndSettle();
      await revealCircle(tester, find.text('Love'));
      await tester.tap(find.text('Love'));
      await tester.pumpAndSettle();
      await revealCircle(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'See you next Sunday.');
      await revealCircle(tester, find.text('Send comment'));
      await tester.tap(find.text('Send comment'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(circleWorkspaceProvider)
            .requireValue
            .memories
            .first
            .comments
            .last,
        'You: See you next Sunday.',
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
      await tester.pumpAndSettle();
      await revealCircle(tester, find.text('Going').first);
      await tester.tap(find.text('Going').first);
      await tester.pumpAndSettle();
      expect(
        container
            .read(circleWorkspaceProvider)
            .requireValue
            .events
            .first
            .attendance,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Same table'), findsOneWidget);
      await revealCircle(
        tester,
        find.text('End preview and clear local changes'),
      );
      await tester.tap(find.text('End preview and clear local changes'));
      await tester.pumpAndSettle();
      expect(container.read(circlePreviewSessionProvider), false);
      container
          .read(circlePreviewSessionProvider.notifier)
          .enter(showcase: false);
      await tester.pumpAndSettle();
      expect(
        container.read(circleWorkspaceProvider).requireValue.memories,
        isEmpty,
      );
    },
  );
  testWidgets(
    'protected route resumes after entry without granting unauthorized access',
    (tester) async {
      final container = await openCircle(tester, entered: false);
      container.read(circleRouterProvider).go('/groups/g/private-plans');
      await tester.pumpAndSettle();
      expect(find.text('Good to have\nyou back.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('access-mobile')),
        '+99912345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('access-password')),
        'fictional password',
      );
      await revealCircle(tester, find.text('Preview log in'));
      await tester.tap(find.text('Preview log in'));
      await tester.pumpAndSettle();
      expect(find.text('This circle is private'), findsOneWidget);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('new experience supports dark, large text at $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      for (final route in [
        '/home',
        '/chats',
        '/groups',
        '/events',
        '/you',
        '/groups/g/friends',
        '/groups/new',
        '/compose',
        '/home/memory/table',
      ]) {
        container.read(circleRouterProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
  testWidgets('main home navigation has accessible labels and touch targets', (
    tester,
  ) async {
    await openCircle(tester);
    final handle = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });
  for (final route in [
    '/home',
    '/chats',
    '/groups',
    '/events',
    '/you',
    '/groups/g/friends',
    '/groups/new',
    '/compose',
  ]) {
    testWidgets('original circle golden $route', (tester) async {
      final container = await openCircle(tester);
      container.read(circleRouterProvider).go(route);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/circle_${route.substring(1).replaceAll('/', '_')}.png',
        ),
      );
    });
  }
  testWidgets('original circle golden dark home', (tester) async {
    await openCircle(tester, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/circle_home_dark.png'),
    );
  });
}
