import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionProvider = NotifierProvider<SessionController, bool>(
  SessionController.new,
);

class SessionController extends Notifier<bool> {
  @override
  bool build() => false;
  bool enter(String code) {
    if (code.trim().toUpperCase() != 'CIRCLE-DEMO') return false;
    state = true;
    return true;
  }

  void leave() => state = false;
}

final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void change(ThemeMode mode) => state = mode;
}
