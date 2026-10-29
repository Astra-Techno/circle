import 'dart:typed_data';
import '../../profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Keep the process-wide database compatible with saved notification aliases.
import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as zones;
import '../../../core/api/api_providers.dart';
import '../../../core/api/scoped_api.dart';
import '../../workspace/application/workspace_providers.dart';
export '../../../core/api/api_json.dart';
export '../../../core/circle_failure.dart';

bool _ready = false;
void _init() {
  if (!_ready) {
    database.initializeTimeZones();
    _ready = true;
  }
}

List<String> liveEventZones() {
  _init();
  return zones.timeZoneDatabase.locations.keys.toList()..sort();
}

DateTime liveEventWall(String value, String zone) {
  _init();
  return zones.TZDateTime.from(DateTime.parse(value), zones.getLocation(zone));
}

String liveEventInstant(DateTime wall, String zone) {
  _init();
  final d = zones.TZDateTime(
    zones.getLocation(zone),
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  if (d.year != wall.year ||
      d.month != wall.month ||
      d.day != wall.day ||
      d.hour != wall.hour ||
      d.minute != wall.minute) {
    throw const CircleFailure(
      'This local time does not exist because of daylight saving. Choose another time.',
    );
  }
  return d.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
}

String liveEventLabel(Map<String, Object?> e) {
  final d = liveEventWall(e['start_at'] as String, e['timezone'] as String);
  return '${formatDay(d, today: DateTime.now())} · ${formatTime(d)} · ${e['timezone']}';
}

final liveEventsApiProvider = Provider<LiveEventsApi>((ref) {
  final api = ref.watch(apiClientProvider),
      account = ref.watch(serverAccountProvider);
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to open events.');
  }
  return LiveEventsApi(
    ScopedApi(
      api,
      account.id,
      api.sessionRevision,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account.id,
    ),
  );
});

class LiveEventsApi {
  LiveEventsApi(this.scope);
  final ScopedApi scope;
  Future<void> cover(String id, int version, ProfilePhotoPicker picker) async {
    scope.check();
    final photo = await picker.pick();
    scope.check();
    if (photo == null) return;
    await scope.upload(
      '/events/$id/cover?version=$version',
      photo.bytes,
      photo.mimeType,
    );
  }

  Future<void> removeCover(String id, int version) =>
      scope.remove('/events/$id/cover?version=$version');
  Future<Map<String, Object?>> list(int offset, String? group) => scope.get(
    '/events',
    query: {'limit': 30, 'offset': offset, 'group_id': ?group},
  );
  Future<Map<String, Object?>> detail(String id) => scope.get('/events/$id');
  Future<Map<String, Object?>> attendees(String id, int offset) => scope.get(
    '/events/$id/attendees',
    query: {'limit': 30, 'offset': offset},
  );
  Future<Map<String, Object?>> create(
    String group,
    Map<String, Object?> fields,
  ) => scope.change('POST', '/groups/$group/events', fields);
  Future<void> update(String id, Map<String, Object?> fields) async {
    await scope.change('PATCH', '/events/$id', fields);
  }

  Future<void> rsvp(String id, String status, int guests, String note) async {
    await scope.change('PUT', '/events/$id/rsvp', {
      'status': status,
      'guest_count': guests,
      'note': note,
    });
  }
}

final liveEventsProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, ({int offset, String? group})>(
      (ref, p) => ref.watch(liveEventsApiProvider).list(p.offset, p.group),
      retry: (_, _) => null,
    );
final liveEventProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>(
      (ref, id) => ref.watch(liveEventsApiProvider).detail(id),
      retry: (_, _) => null,
    );
final liveAttendeesProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, ({String id, int offset})>(
      (ref, p) => ref.watch(liveEventsApiProvider).attendees(p.id, p.offset),
      retry: (_, _) => null,
    );

final liveEventCoverProvider = FutureProvider.autoDispose
    .family<Uint8List, ({String event, String cover})>(
      (ref, p) => ref
          .watch(liveEventsApiProvider)
          .scope
          .bytes('/events/${p.event}/cover'),
      retry: (_, _) => null,
    );
