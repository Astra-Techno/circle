import '../../../core/api/api_json.dart';
import '../../../core/api/scoped_api.dart';

class ServerSearchHit {
  const ServerSearchHit(
    this.category,
    this.title,
    this.subtitle,
    this.location,
  );
  final String category, title, subtitle, location;
}

class ServerSearchPage {
  const ServerSearchPage(this.items, this.hasMore);
  final List<ServerSearchHit> items;
  final bool hasMore;
}

class ServerSearch {
  ServerSearch(this.scope);
  final ScopedApi scope;
  Future<ServerSearchPage> find(String query, int pages) async {
    final hits = <ServerSearchHit>[];
    var more = false;
    for (var page = 0; page < pages; page++) {
      final response = await scope.get(
        '/search',
        query: {'q': query, 'limit': 20, 'offset': page * 20},
      );
      more = ApiJson.map(response['has_more']).values.any(ApiJson.boolean);
      for (final category in [
        'groups',
        'people',
        'memories',
        'events',
        'polls',
      ]) {
        for (final value in ApiJson.list(response[category])) {
          final row = ApiJson.map(value);
          final id = ApiJson.id(row['id']);
          final title = switch (category) {
            'groups' => ApiJson.string(row['name']),
            'people' => ApiJson.string(row['display_name']),
            'memories' => ApiJson.string(row['body']),
            'events' => ApiJson.string(row['title']),
            _ => ApiJson.string(row['question']),
          };
          final location = switch (category) {
            'groups' => '/groups/g/$id',
            'people' => '/people/$id',
            'memories' => '/home/memory/$id',
            'events' => '/events/e/$id',
            _ => '/polls/p/$id',
          };
          hits.add(
            ServerSearchHit(
              category,
              title,
              ApiJson.string(row['group_name'], ApiJson.string(row['about'])),
              location,
            ),
          );
        }
      }
      if (!more) break;
    }
    return ServerSearchPage(hits, more);
  }
}
