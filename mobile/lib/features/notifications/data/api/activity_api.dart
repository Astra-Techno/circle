import '../../../../core/api/api_json.dart';
import '../../../../core/api/scoped_api.dart';
import '../../domain/notification_repository.dart';

class ActivityApi {
  ActivityApi(this.scope);
  final ScopedApi scope;

  Future<ActivityFeed> load(int pages) async {
    final entries = <ActivityEntry>[];
    var more = false;
    var unread = 0;
    for (var page = 0; page < pages; page++) {
      final data = await scope.get(
        '/me/activity',
        query: {'limit': 30, 'offset': page * 30},
      );
      unread = ApiJson.integer(data['unread_count']) ?? 0;
      more = ApiJson.boolean(data['has_more']);
      for (final raw in ApiJson.list(data['items'])) {
        final row = ApiJson.map(raw);
        final memory = ApiJson.optionalId(row['memory_id']) ?? '';
        final group = ApiJson.optionalId(row['group_id']) ?? '';
        final event = ApiJson.optionalId(row['event_id']) ?? '';
        final actor = row['actor_name'] as String? ?? 'Someone';
        final circle = row['group_name'] as String? ?? 'your Circle';
        final kind = row['kind'] as String;
        final reply = kind.startsWith('comment.');
        entries.add(
          ActivityEntry(
            item: ActivityItem(
              id: ApiJson.id(row['id']),
              kind: reply ? ActivityKind.reply : ActivityKind.newMemory,
              at: DateTime.parse(
                '${(row['created_at'] as String).replaceAll(' ', 'T')}Z',
              ),
              text: reply
                  ? '$actor commented in $circle.'
                  : '$actor shared a Memory in $circle.',
              groupId: group,
              target: memory.isNotEmpty
                  ? ActivityTarget(ActivityTargetKind.memory, memory)
                  : event.isNotEmpty
                  ? ActivityTarget(ActivityTargetKind.event, event)
                  : ActivityTarget(ActivityTargetKind.group, group),
            ),
            read: ApiJson.boolean(row['is_read']),
            delivery: Delivery.inbox,
          ),
        );
      }
      if (!more) break;
    }
    return ActivityFeed(entries: entries, hasMore: more, serverUnread: unread);
  }

  Future<void> markRead(String? id) =>
      scope.change('POST', '/me/activity/read', {
        if (id != null) 'ids': [int.parse(id)],
      });
}
