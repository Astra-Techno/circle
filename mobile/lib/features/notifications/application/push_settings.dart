import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as database;
import 'package:timezone/timezone.dart' as zones;
import '../../../core/api/api_providers.dart';
import '../../../core/circle_failure.dart';
import '../../../core/notifications/push_lifecycle.dart';
import '../../workspace/application/server_session.dart';
import '../data/push_preferences_api.dart';
import '../data/device_timezone.dart';
import 'push_session_coordinator.dart';
export '../domain/push_preferences.dart';

final deviceTimezoneProvider = Provider<DeviceTimezone>(
  (ref) => const DeviceTimezone(),
);
bool _timezonesReady = false;
void _ensureTimezones() {
  if (!_timezonesReady) {
    database.initializeTimeZones();
    _timezonesReady = true;
  }
}

final pushTimezonesProvider = Provider<List<String>>((ref) {
  _ensureTimezones();
  return zones.timeZoneDatabase.locations.keys.toList()..sort();
});
final pushSettingsProvider =
    AsyncNotifierProvider<PushSettings, PushPreferences>(PushSettings.new);

class PushSettings extends AsyncNotifier<PushPreferences> {
  int _generation = 0;
  Future<void> _tail = Future.value();
  @override
  Future<PushPreferences> build() async {
    _generation++;
    final account = ref.watch(serverAccountProvider.select((a) => a?.id));
    final api = ref.watch(apiClientProvider);
    final remove = ref.read(pushLifecycleProvider).listen(ref.invalidateSelf);
    ref.onDispose(remove);
    if (account == null || api == null) {
      throw const CircleFailure('Please sign in to change notifications.');
    }
    return PushPreferencesApi(api, accountId: account).load();
  }

  bool _current(int generation, ApiClient api, String account) =>
      ref.mounted &&
      generation == _generation &&
      identical(ref.read(apiClientProvider), api) &&
      ref.read(serverAccountProvider)?.id == account;

  Future<void> change({
    bool? enabled,
    Map<PushCategory, bool>? categories,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
    String? timezone,
    bool requestPermission = false,
  }) {
    final api = ref.read(apiClientProvider),
        account = ref.read(serverAccountProvider)?.id;
    final generation = _generation;
    if (api == null || account == null) {
      return Future.error(const CircleFailure('Please sign in again.'));
    }
    final operation = _tail.then((_) async {
      if (!_current(generation, api, account)) {
        throw const CircleFailure('Your session changed. Please try again.');
      }
      final previous = state.value;
      if (previous == null) {
        throw const CircleFailure('Load your choices before changing them.');
      }
      // Preserve saved choices during writes; Riverpod 3 has no public equivalent.
      // ignore: invalid_use_of_internal_member
      state = const AsyncLoading<PushPreferences>().copyWithPrevious(state);
      final coordinator = ref.read(pushSessionCoordinatorProvider);
      try {
        if (enabled == false) {
          unawaited(coordinator.stop());
        }
        if (requestPermission) {
          if (!previous.categories.values.any((enabled) => enabled)) {
            throw const CircleFailure(
              'Choose at least one type of update first.',
            );
          }
          final started = await coordinator.start(requestPermission: true);
          if (!_current(generation, api, account)) {
            throw const CircleFailure(
              'Your session changed. Please try again.',
            );
          }
          if (!started) {
            throw const CircleFailure(
              'Check notification permission in phone settings, then try again.',
            );
          }
          if (!_current(generation, api, account)) {
            throw const CircleFailure(
              'Your session changed. Please try again.',
            );
          }
        }
        final saved = await PushPreferencesApi(api, accountId: account).update(
          enabled: enabled,
          categories: categories,
          quietHours: quietHours,
          quietStart: quietStart,
          quietEnd: quietEnd,
          timezone: timezone,
        );
        if (!_current(generation, api, account)) return;
        state = AsyncData(saved);
      } catch (_) {
        if (_current(generation, api, account)) {
          state = AsyncData(previous);
          if (requestPermission) unawaited(coordinator.stop());
        }
        rethrow;
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}

bool pushQuietNow(PushPreferences preferences, DateTime now) {
  _ensureTimezones();
  if (!preferences.quietHours) return false;
  final local = zones.TZDateTime.from(
    now.toUtc(),
    zones.getLocation(preferences.timezone),
  );
  final minute = local.hour * 60 + local.minute;
  return preferences.quietStart < preferences.quietEnd
      ? minute >= preferences.quietStart && minute < preferences.quietEnd
      : minute >= preferences.quietStart || minute < preferences.quietEnd;
}
