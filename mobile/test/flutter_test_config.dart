import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final text = FontLoader('CircleRoboto')
    ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/roboto-medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
  await text.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await testMain();
}
