import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/auth/application/country_provider.dart';
import 'package:mobile/features/auth/domain/country_locator.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';
import 'package:mobile/features/auth/presentation/access_design.dart';
import 'support/circle_harness.dart' show reveal;

class FakeLocator implements CountryLocator {
  final result = Completer<String>();
  int calls = 0;
  @override
  Future<String> detectCountry() {
    calls++;
    return result.future;
  }
}

void main() {
  test('release defaults to real API; explicit preview remains separate', () {
    expect(
      ApiConfig.forBuild(release: true)?.baseUrl.toString(),
      ApiConfig.deployedApi,
    );
    expect(ApiConfig.forBuild(release: true, preview: true), isNull);
    expect(ApiConfig.forBuild(release: false), isNull);
    expect(
      ApiConfig.forBuild(
        release: false,
        baseUrl: 'https://example.test/api/v1',
      )?.secure,
      isTrue,
    );
  });
  test('white is the initial appearance even on a dark device', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeProvider), ThemeMode.light);
    expect(circleTheme(Brightness.light).scaffoldBackgroundColor, Colors.white);
  });
  testWidgets(
    'India default; lookup is opt-in and never overrides a manual country choice',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final locator = FakeLocator();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [countryLocatorProvider.overrideWithValue(locator)],
          child: MaterialApp(
            theme: circleTheme(Brightness.light),
            home: AccessForm(registering: false, onPreviewComplete: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      DialCode? selected() => tester
          .widget<DropdownButtonFormField<DialCode>>(
            find.byType(DropdownButtonFormField<DialCode>),
          )
          .initialValue;
      expect(selected()?.region, 'IN');
      expect(locator.calls, 0);
      final locate = find.text('Use my location for country code');
      await reveal(tester, locate);
      await tester.tap(locate);
      await tester.pumpAndSettle();
      expect(locator.calls, 1);
      final picker = tester.widget<DropdownButtonFormField<DialCode>>(
        find.byType(DropdownButtonFormField<DialCode>),
      );
      picker.onChanged!(AccessValidation.dialCodeForRegion('GB'));
      await tester.pumpAndSettle();
      locator.result.complete('IN');
      await tester.pumpAndSettle();
      expect(selected()?.region, 'GB');
      expect(find.byIcon(Icons.waving_hand_outlined), findsNothing);
    },
  );
}
