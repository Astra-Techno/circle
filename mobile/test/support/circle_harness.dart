import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'fake_api.dart';
import 'mock_circle_repository.dart';

/// The fake account the fictional test data belongs to.
const testViewer = 'you';

/// Pumps the real app signed in to a fictional account whose data comes
/// from [MockCircleRepository] (a test double; the app has no demo mode).
/// [entered] false shows the signed-out welcome; [showcase] loads the
/// fictional circles; [now] fixes the app's clock, or [clock] supplies one a
/// test can move forward. The network is never touched: the API points at
/// a test host and every request fails.
Future<ProviderContainer> openCircle(
  WidgetTester tester, {
  bool entered = true,
  bool showcase = true,
  Size size = const Size(393, 852),
  double scale = 1,
  Brightness brightness = Brightness.light,
  double keyboard = 0,
  DateTime? now,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final appClock = clock ?? (now == null ? null : () => now);
  final repository = MockCircleRepository(showcase: showcase, now: appClock);
  final container = ProviderContainer(
    overrides: [
      if (appClock != null) circleClockProvider.overrideWithValue(appClock),
      apiConfigProvider.overrideWithValue(
        ApiConfig.parse('https://circle.test/api/v1'),
      ),
      apiHttpAdapterProvider.overrideWithValue(
        FakeHttpAdapter(
          (_) async =>
              const FakeResponse.network(DioExceptionType.connectionError),
        ),
      ),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      circleRepositoryProvider.overrideWithValue(repository),
      circleViewerProvider.overrideWithValue(entered ? testViewer : ''),
      circleSessionActiveProvider.overrideWithValue(entered),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(themeProvider.notifier)
      .change(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CircleExperience(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Scrolls the innermost vertical scrollable (down, then up) until
/// [finder] is built, then brings it into view.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (final delta in [200.0, -200.0]) {
    if (finder.evaluate().isNotEmpty) break;
    try {
      await tester.scrollUntilVisible(
        finder,
        delta,
        scrollable: vertical.last,
        maxScrolls: 60,
      );
    } on StateError {
      // Reached the end without finding it; try the other direction.
    }
  }
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> go(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  container.read(circleRouterProvider).go(location);
  await tester.pumpAndSettle();
}

CircleWorkspace workspaceOf(ProviderContainer container) =>
    container.read(circleWorkspaceProvider).requireValue;

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// The visible location, including pages opened with `push`.
Uri currentUri(ProviderContainer container) {
  final config = container
      .read(circleRouterProvider)
      .routerDelegate
      .currentConfiguration;
  // The leaf match, also inside the shell's branches.
  final last = config.lastOrNull;
  return last is ImperativeRouteMatch ? last.matches.uri : config.uri;
}

/// Scrolls the tab bar to [label] if needed and selects it.
Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  // At large text the tabs can sit below a tall header: scroll to them.
  if (tab.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tab,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
