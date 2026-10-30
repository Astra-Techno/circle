import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/circle_experience.dart';
import 'core/notifications/first_launch_permission.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'features/notifications/application/background_push.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('CIRCLE_PUSH_ENABLED') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    runZonedGuarded(() {
      FirebaseMessaging.onBackgroundMessage(circleBackgroundPushHandler);
    }, (Object _, StackTrace _) {});
  }
  runApp(const ProviderScope(child: CircleExperience()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (const bool.fromEnvironment('CIRCLE_PUSH_ENABLED')) {
      unawaited(requestFirstLaunchNotifications());
    }
  });
}
