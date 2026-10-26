import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/circle_experience.dart';
import 'core/notifications/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Delivery stays opt-in until the cross-feature push acceptance batch passes.
  // An unavailable plugin/configuration must never prevent the core app opening.
  if (const bool.fromEnvironment('CIRCLE_PUSH_ENABLED')) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      // Core authentication and content remain available without push.
    }
  }
  runApp(const ProviderScope(child: CircleExperience()));
}
