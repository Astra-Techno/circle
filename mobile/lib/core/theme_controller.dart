import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Appearance preference for this session only.
final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;
  void change(ThemeMode mode) => state = mode;
}
