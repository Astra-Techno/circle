import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_settings.dart';
import '../../workspace/application/workspace_providers.dart';

/// When this person last looked at each circle on Home, kept on the phone
/// per account. A circle has new Memories when someone else shared after
/// that moment. Circles never opened count from the first time this was
/// recorded, so a fresh install doesn't light up every ring.
class CircleSeen {
  const CircleSeen({required this.since, required this.groups});
  final DateTime since;
  final Map<String, DateTime> groups;

  DateTime seenAt(String groupId) => groups[groupId] ?? since;
}

final circleSeenProvider =
    AsyncNotifierProvider<CircleSeenController, CircleSeen>(
      CircleSeenController.new,
    );

class CircleSeenController extends AsyncNotifier<CircleSeen> {
  String get _key => 'circle.seen.${ref.read(circleViewerProvider)}';

  @override
  Future<CircleSeen> build() async {
    ref.watch(circleViewerProvider);
    final now = ref.read(circleClockProvider)().toUtc();
    final raw = await readLocalSetting(
      () => ref.read(localSettingsStoreProvider).read(_key),
    );
    final stored = _decode(raw);
    if (stored != null) return stored;
    final fresh = CircleSeen(since: now, groups: const {});
    await _save(fresh);
    return fresh;
  }

  /// Marks [groupId] as seen up to [at] (its newest Memory).
  Future<void> markSeen(String groupId, DateTime at) async {
    final current = state.value;
    if (current == null || !at.isAfter(current.seenAt(groupId))) return;
    final next = CircleSeen(
      since: current.since,
      groups: {...current.groups, groupId: at.toUtc()},
    );
    state = AsyncData(next);
    await _save(next);
  }

  Future<void> _save(CircleSeen seen) => readLocalSetting(
    () => ref
        .read(localSettingsStoreProvider)
        .write(
          _key,
          jsonEncode({
            'since': seen.since.toIso8601String(),
            'groups': {
              for (final entry in seen.groups.entries)
                entry.key: entry.value.toIso8601String(),
            },
          }),
        ),
  );

  static CircleSeen? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final since = DateTime.parse(json['since'] as String);
      final groups = (json['groups'] as Map<String, Object?>? ?? const {}).map(
        (id, at) => MapEntry(id, DateTime.parse(at as String)),
      );
      return CircleSeen(since: since, groups: groups);
    } on Object {
      return null;
    }
  }
}
