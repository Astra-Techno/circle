import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication invalidates optional push without depending on its providers
/// or awaiting SDK/network cleanup. Unused push creates no SDK objects.
class PushLifecycle {
  final _listeners = <void Function()>{};
  void Function() listen(void Function() callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  void invalidate() {
    for (final callback in List.of(_listeners)) {
      try {
        callback();
      } catch (_) {}
    }
  }
}

final pushLifecycleProvider = Provider<PushLifecycle>((ref) => PushLifecycle());
