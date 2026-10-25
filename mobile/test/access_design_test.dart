import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_brand.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

Future<void> fillAccess(WidgetTester tester, {required String password}) async {
  await tester.enterText(
    find.byKey(const ValueKey('access-mobile')),
    '9876543210',
  );
  await tester.enterText(
    find.byKey(const ValueKey('access-password')),
    password,
  );
}

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  testWidgets('welcome has accessible labels, contrast and touch targets', (
    tester,
  ) async {
    await openCircle(tester, entered: false);
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
    'registration validates, clears input and opens an empty workspace',
    (tester) async {
      final container = await openCircle(tester, entered: false);
      await tapText(tester, 'Create account');
      await tapText(tester, 'Preview registration');
      expect(find.text('Enter your mobile number.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(container.read(circlePreviewSessionProvider), isFalse);
      await fillAccess(tester, password: 'short');
      await tapText(tester, 'Preview registration');
      expect(find.textContaining('Use 6–128 characters'), findsOneWidget);
      await fillAccess(tester, password: 'a fictional passphrase');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tapText(tester, 'Preview registration');
      expect(container.read(circlePreviewSessionProvider), isTrue);
      expect(workspaceOf(container).groups, isEmpty);
      expect(find.text('A little space for your people'), findsOneWidget);
      // Ending the preview returns to welcome; the form starts empty again.
      await container.read(circlePreviewSessionProvider.notifier).leave();
      await tester.pumpAndSettle();
      await tapText(tester, 'Create account');
      // Mobile field resets to empty (dial code is in the dropdown).
      expect(fieldText(tester, 'access-mobile'), isEmpty);
      expect(fieldText(tester, 'access-password'), isEmpty);
    },
  );

  testWidgets('login never requires an invitation or OTP', (tester) async {
    final container = await openCircle(tester, entered: false);
    await tapText(tester, 'Log in');
    await reveal(tester, find.textContaining('OTP'));
    expect(find.textContaining('OTP'), findsOneWidget);
    await fillAccess(tester, password: 'fictional password');
    await tapText(tester, 'Preview log in');
    expect(container.read(circlePreviewSessionProvider), isTrue);
    // Logging in never joins the fictional groups: the workspace is empty.
    expect(find.text('A little space for your people'), findsOneWidget);
  });

  testWidgets('forms offer password-manager autofill hints', (tester) async {
    await openCircle(tester, entered: false);
    await tapText(tester, 'Create account');
    expect(find.byType(AutofillGroup), findsOneWidget);
    List<String>? hints(String key) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
          ),
        )
        .autofillHints
        ?.toList();
    expect(hints('access-mobile'), [AutofillHints.telephoneNumber]);
    expect(hints('access-password'), [AutofillHints.newPassword]);
    await tapText(tester, 'Have an account? Log in');
    expect(hints('access-password'), [AutofillHints.password]);
  });

  testWidgets('switching between login and register keeps the destination', (
    tester,
  ) async {
    final container = await openCircle(tester, entered: false);
    await go(tester, container, '/groups/g/club');
    expect(currentUri(container).queryParameters['next'], '/groups/g/club');
    await tapText(tester, 'New here? Create account');
    expect(
      currentUri(container).toString(),
      '/register?next=%2Fgroups%2Fg%2Fclub',
    );
    await tapText(tester, 'Have an account? Log in');
    await fillAccess(tester, password: 'fictional password');
    await tapText(tester, 'Preview log in');
    expect(currentUri(container).path, '/groups/g/club');
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('access layouts scale with keyboard at $size', (tester) async {
      await openCircle(
        tester,
        entered: false,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
        keyboard: 260,
      );
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Create account');
      await reveal(tester, find.text('Preview registration'));
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Have an account? Log in');
      await reveal(tester, find.text('Preview log in'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in ['welcome', 'register', 'login', 'register_dark']) {
    testWidgets('access golden $screen', (tester) async {
      await openCircle(
        tester,
        entered: false,
        brightness: screen.endsWith('dark')
            ? Brightness.dark
            : Brightness.light,
      );
      if (screen != 'welcome') {
        await tapText(tester, screen == 'login' ? 'Log in' : 'Create account');
      }
      // Asset decoding is asynchronous and pumpAndSettle alone may capture
      // an empty image before its first frame, especially on a cold cache.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(CircleIdentity.artwork),
          tester.element(find.byType(CircleBrand)),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/access_$screen.png'),
      );
    });
  }
}
