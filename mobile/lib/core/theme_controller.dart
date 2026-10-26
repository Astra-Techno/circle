import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_settings.dart';

/// Light is the first-run default; an intentional preference survives restarts.
final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'circle.local.appearance.v1';
  bool _changed = false;
  Future<void> _write = Future.value();
  @override
  ThemeMode build() {
    final storage = ref.watch(localSettingsStoreProvider);
    Future.microtask(() async {
      final saved = await readLocalSetting(() => storage.read(_key));
      if (!ref.mounted || _changed) return;
      state =
          ThemeMode.values.where((mode) => mode.name == saved).firstOrNull ??
          ThemeMode.light;
    });
    return ThemeMode.light;
  }

  void change(ThemeMode mode) {
    _changed = true;
    state = mode;
    final storage = ref.read(localSettingsStoreProvider);
    _write = _write.then((_) async {
      await readLocalSetting(() => storage.write(_key, mode.name));
    });
    unawaited(_write);
  }

  /// Used by tests/lifecycle integration when waiting for a preference flush.
  Future<void> get saved => _write;
}
