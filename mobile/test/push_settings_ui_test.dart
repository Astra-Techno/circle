import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/notifications/application/push_settings.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/presentation/server_push_settings.dart';
import 'support/fake_fcm.dart';
import 'package:mobile/core/notifications/push_config.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'package:mobile/features/notifications/presentation/push_presentation_host.dart';

class Choices extends PushSettings {
  int permissions = 0;
  bool fail = false;
  @override
  Future<PushPreferences> build() async => PushPreferences(
    enabled: false,
    categories: {for (final c in PushCategory.values) c: false},
    quietHours: true,
    quietStart: 1320,
    quietEnd: 420,
    timezone: 'UTC',
  );
  @override
  Future<void> change({
    bool? enabled,
    Map<PushCategory, bool>? categories,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
    String? timezone,
    bool requestPermission = false,
  }) async {
    if (requestPermission) permissions++;
    if (fail) throw Exception('Fictional offline');
    final old = state.requireValue;
    state = AsyncData(
      PushPreferences(
        enabled: enabled ?? old.enabled,
        categories: {...old.categories, ...?categories},
        quietHours: quietHours ?? old.quietHours,
        quietStart: quietStart ?? old.quietStart,
        quietEnd: quietEnd ?? old.quietEnd,
        timezone: timezone ?? old.timezone,
      ),
    );
  }
}

class DefaultOnChoices extends Choices {
  @override
  Future<PushPreferences> build() async => PushPreferences(
    enabled: true,
    categories: {for (final c in PushCategory.values) c: true},
    quietHours: true,
    quietStart: 1320,
    quietEnd: 420,
    timezone: 'UTC',
  );
}

class DeferredChoices extends PushSettings {
  final result = Completer<PushPreferences>();
  @override
  Future<PushPreferences> build() => result.future;
}

class TrackingCoordinator extends PushSessionCoordinator {
  TrackingCoordinator()
    : super(
        gateway: Gateway(),
        current: () async => null,
        ledger: PushLedger(MemoryLocalSettingsStore()),
      );
  int starts = 0;
  @override
  Future<bool> start({bool requestPermission = false}) async {
    starts++;
    return false;
  }
}

class ReactiveCoordinator extends TrackingCoordinator {
  bool registered = false;
  @override
  bool get active => registered;
  void registeredNow() {
    registered = true;
    connectionRevision.value++;
  }
}

void main() {
  testWidgets('connection label updates when passive registration completes', (
    tester,
  ) async {
    final coordinator = ReactiveCoordinator();
    final container = ProviderContainer(
      overrides: [
        pushSettingsProvider.overrideWith(DefaultOnChoices.new),
        pushSessionCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: circleTheme(Brightness.light),
          home: const Scaffold(body: ServerPushSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications are connected on this phone.'),
      findsNothing,
    );
    coordinator.registeredNow();
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications are connected on this phone.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'default-on account can turn off notifications without changing category choices or requesting permission',
    (tester) async {
      final choices = DefaultOnChoices();
      final container = ProviderContainer(
        overrides: [pushSettingsProvider.overrideWith(() => choices)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: circleTheme(Brightness.light),
            home: const Scaffold(body: ServerPushSettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final off = find.text('Turn off notifications');
      await tester.scrollUntilVisible(off, 200);
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(
        container.read(pushSettingsProvider).requireValue.enabled,
        isFalse,
      );
      expect(
        container.read(pushSettingsProvider).requireValue.categories.values,
        everyElement(isTrue),
      );
      expect(choices.permissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paused host cannot reconnect after delayed preferences load', (
    tester,
  ) async {
    final choices = DeferredChoices();
    final coordinator = TrackingCoordinator();
    final container = ProviderContainer(
      overrides: [
        pushClientEnabledProvider.overrideWithValue(true),
        serverAccountProvider.overrideWithValue(null),
        pushSettingsProvider.overrideWith(() => choices),
        pushSessionCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) =>
              PushPresentationHost(onOpen: (_) {}, child: child!),
          home: const Scaffold(body: Text('Fictional home')),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    choices.result.complete(
      PushPreferences(
        enabled: true,
        categories: {},
        quietHours: false,
        quietStart: 1320,
        quietEnd: 420,
        timezone: 'UTC',
      ),
    );
    await tester.pumpAndSettle();
    expect(coordinator.starts, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(coordinator.starts, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('settings $width $brightness at double text', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final choices = Choices();
        final coordinator = PushSessionCoordinator(
          gateway: Gateway(),
          current: () async => null,
          ledger: PushLedger(MemoryLocalSettingsStore()),
        );
        final container = ProviderContainer(
          overrides: [
            pushSettingsProvider.overrideWith(() => choices),
            pushSessionCoordinatorProvider.overrideWithValue(coordinator),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: circleTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const RepaintBoundary(
                key: ValueKey('capture'),
                child: Scaffold(body: ServerPushSettingsScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/circle-push-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final groupChoice = find.byKey(const ValueKey('push-groups'));
        await tester.scrollUntilVisible(groupChoice, 300);
        expect(find.text('Groups and safety'), findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(groupChoice),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(groupChoice);
        await tester.pumpAndSettle();
        expect(
          container
              .read(pushSettingsProvider)
              .requireValue
              .categories[PushCategory.groups],
          isTrue,
        );
        expect(choices.permissions, 0);
        final enable = find.text('Enable notifications');
        await tester.scrollUntilVisible(enable, -300);
        await tester.ensureVisible(enable);
        await tester.pumpAndSettle();
        await tester.tap(enable);
        await tester.pumpAndSettle();
        expect(find.text('Choose what reaches you'), findsOneWidget);
        expect(choices.permissions, 0);
        await tester.ensureVisible(find.text('Not now'));
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        expect(choices.permissions, 0);
        await tester.ensureVisible(enable);
        await tester.tap(enable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(choices.permissions, 1);
        expect(find.text('Turn off notifications'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('quiet hours use IANA timezone and daylight saving', () {
    final prefs = PushPreferences(
      enabled: true,
      categories: {},
      quietHours: true,
      quietStart: 1320,
      quietEnd: 420,
      timezone: 'America/New_York',
    );
    expect(pushQuietNow(prefs, DateTime.utc(2026, 7, 1, 2)), isTrue);
    expect(pushQuietNow(prefs, DateTime.utc(2026, 1, 1, 2)), isFalse);
    expect(pushQuietNow(prefs, DateTime.utc(2026, 7, 1, 11)), isFalse);
  });
}
