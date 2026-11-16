import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf')))
      .load();
  await (FontLoader('Plus Jakarta Sans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('packages/flutter_lucide/lucide')..addFont(
        rootBundle.load('packages/flutter_lucide/lib/fonts/lucide.ttf'),
      ))
      .load();
  await testMain();
}
