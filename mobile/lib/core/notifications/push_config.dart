import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushClientEnabledProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('CIRCLE_PUSH_ENABLED') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android,
);
