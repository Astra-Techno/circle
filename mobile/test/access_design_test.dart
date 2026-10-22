import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/auth_design_preview.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> openPreview(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double scale = 1,
  Brightness brightness = Brightness.light,
  double keyboard = 0,
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
  await tester.pumpWidget(const AuthDesignPreview());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome has accessible labels, contrast and touch targets', (
    tester,
  ) async {
    await openPreview(tester);
    final handle = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
    }
  });
  test(
    'international phone syntax validates without claiming verification',
    () {
      expect(AccessValidation.mobile('+999 1234 5678'), isNull);
      for (final value in [
        '',
        '1234567890',
        '+0123456789',
        '+123',
        '+1234567890123456',
        '+91hello',
      ]) {
        expect(AccessValidation.mobile(value), isNotNull);
      }
    },
  );
  test(
    'registration passphrases have length bounds; login allows existing passwords',
    () {
      expect(
        AccessValidation.password('a fictional passphrase', registering: true),
        isNull,
      );
      expect(AccessValidation.password('short', registering: true), isNotNull);
      expect(
        AccessValidation.password('x' * 129, registering: true),
        isNotNull,
      );
      expect(AccessValidation.password('short', registering: false), isNull);
      expect(AccessValidation.password('', registering: false), isNotNull);
    },
  );
  testWidgets(
    'registration validates and completes only a clearly labeled preview',
    (tester) async {
      await openPreview(tester);
      await reveal(tester, find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview registration'));
      await tester.tap(find.text('Preview registration'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Include the country code'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('access-mobile')),
        '+99912345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('access-password')),
        'a fictional passphrase',
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await reveal(tester, find.text('Preview registration'));
      await tester.tap(find.text('Preview registration'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No account was created'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await reveal(tester, find.text('Back to the design preview'));
      await tester.tap(find.text('Back to the design preview'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      final mobile = tester.widget<TextFormField>(
        find.byKey(const ValueKey('access-mobile')),
      );
      expect(mobile.controller!.text, isEmpty);
      final password = tester.widget<TextFormField>(
        find.byKey(const ValueKey('access-password')),
      );
      expect(password.controller!.text, isEmpty);
    },
  );
  testWidgets('login preview never requires an invitation or OTP', (
    tester,
  ) async {
    await openPreview(tester);
    await reveal(tester, find.text('Already here? Log in'));
    await tester.tap(find.text('Already here? Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('access-mobile')),
      '+99912345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('access-password')),
      'fictional password',
    );
    await reveal(tester, find.text('Preview log in'));
    await tester.tap(find.text('Preview log in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account was created'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('access layouts scale with keyboard at $size', (tester) async {
      await openPreview(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
        keyboard: 260,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview registration'));
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Have an account? Log in'));
      await tester.tap(find.text('Have an account? Log in'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview log in'));
      expect(tester.takeException(), isNull);
    });
  }
  for (final screen in ['welcome', 'register', 'login', 'register_dark']) {
    testWidgets('access golden $screen', (tester) async {
      await openPreview(
        tester,
        brightness: screen.endsWith('dark')
            ? Brightness.dark
            : Brightness.light,
      );
      if (screen != 'welcome') {
        final label = screen == 'login'
            ? 'Already here? Log in'
            : 'Create account';
        await reveal(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/access_$screen.png'),
      );
    });
  }
}
