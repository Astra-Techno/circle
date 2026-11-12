import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/scoped_api.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/albums/data/api_album_repository.dart';
import 'package:mobile/features/capsules/data/local_capsule_repository.dart';
import 'package:mobile/features/capsules/data/server_capsule_repository.dart';
import 'package:mobile/features/notifications/data/api/activity_api.dart';
import 'package:mobile/features/search/data/server_search.dart';
import 'support/fake_api.dart';

Future<ScopedApi> scoped(FakeHandler handler) async {
  final api = ApiClient(
    config: ApiConfig.parse('https://fictional.test/api/v1')!,
    tokens: MemoryTokenStore(),
    adapter: FakeHttpAdapter(handler),
  );
  await api.saveTokens(
    const TokenPair(
      accessToken: 'fictional-access',
      refreshToken: 'fictional-refresh',
      server: 'https://fictional.test/api/v1',
      account: StoredAccount(id: '1', displayName: 'Fictional A'),
    ),
  );
  addTearDown(() => api.dio.close(force: true));
  return ScopedApi(api, '1', api.sessionRevision, () => true);
}

void main() {
  test(
    'Capsule entries are fetched only after server unlock and retain text',
    () async {
      var unlocked = false;
      var entryReads = 0;
      final scope = await scoped((request) {
        if (request.path.endsWith('/entries')) {
          entryReads++;
          return FakeResponse.ok({
            'items': [
              {
                'id': 2,
                'author_id': 1,
                'author_name': 'Fictional A',
                'body': 'For the future',
                'added_at': '2026-11-12 00:00:00',
              },
            ],
            'has_more': false,
          });
        }
        return FakeResponse.ok({
          'id': 7,
          'group_id': 3,
          'creator_id': 1,
          'creator_name': 'Fictional A',
          'title': 'Later',
          'message': '',
          'created_at': '2026-11-12 00:00:00',
          'unlock_at': '2030-01-01 00:00:00',
          'sealed_at': null,
          'is_unlocked': unlocked,
          'entry_count': 1,
        });
      });
      final repo = ServerCapsuleRepository(
        scope: scope,
        groups: ['3'],
        legacy: LocalCapsuleRepository(
          viewer: '1',
          storage: MemoryLocalSettingsStore(),
        ),
      );
      expect((await repo.get('server:7'))!.entries, isEmpty);
      expect(entryReads, 0);
      unlocked = true;
      expect(
        (await repo.get('server:7'))!.entries.single.text,
        'For the future',
      );
      expect(entryReads, 1);
      await scope.api.clearTokens();
      await expectLater(repo.get('server:7'), throwsA(isA<ApiError>()));
    },
  );

  test(
    'Albums map private media IDs and preserve real server photo counts',
    () async {
      final scope = await scoped(
        (request) => FakeResponse.ok({
          'id': 8,
          'group_id': 3,
          'created_by': 1,
          'title': 'Fictional album',
          'description': '2026',
          'created_at': '2026-11-12 00:00:00',
          'photo_count': 1,
          'cover_media_id': 'fictional-media',
          'event_id': null,
          'photos': {
            'items': [
              {
                'id': 5,
                'media_id': 'fictional-media',
                'added_by': 1,
                'caption': 'A moment',
                'added_at': '2026-11-12 00:00:00',
              },
            ],
            'has_more': false,
          },
        }),
      );
      final album = await ApiAlbumRepository(scope).album('1', '8');
      expect(album.photos.single.photo.mediaId, 'fictional-media');
      expect(album.photos.single.photo.scene, isNull);
      expect(album.coverPhotoId, '5');
      expect(album.details, '1 photo · 2026');
    },
  );

  test('Search pages all categories and maps real detail routes', () async {
    final offsets = <String>[];
    final scope = await scoped((request) {
      offsets.add(request.query['offset']!);
      final first = request.query['offset'] == '0';
      return FakeResponse.ok({
        'groups': [],
        'people': [],
        'events': [],
        'memories': [],
        'polls': [
          {
            'id': first ? 7 : 8,
            'question': 'Fictional poll',
            'group_name': 'Fictional Circle',
          },
        ],
        'has_more': {'polls': first},
      });
    });
    final page = await ServerSearch(scope).find('fictional', 2);
    expect(offsets, ['0', '20']);
    expect(page.items.map((hit) => hit.location), ['/polls/p/7', '/polls/p/8']);
    expect(page.hasMore, isFalse);
  });

  test(
    'Activity handles optional IDs, real unread count and read action',
    () async {
      final requests = <FakeRequest>[];
      final scope = await scoped((request) {
        requests.add(request);
        return FakeResponse.ok(
          request.method == 'POST'
              ? null
              : {
                  'items': [
                    {
                      'id': 9,
                      'kind': 'comment.created',
                      'actor_name': 'Fictional B',
                      'group_name': 'Fictional Circle',
                      'group_id': 3,
                      'memory_id': 7,
                      'event_id': null,
                      'is_read': false,
                      'created_at': '2026-11-12 00:00:00',
                    },
                  ],
                  'has_more': false,
                  'unread_count': 4,
                },
        );
      });
      final api = ActivityApi(scope);
      final result = await api.load(1);
      expect(result.unread, 4);
      expect(result.entries.single.item.target.id, '7');
      await api.markRead('9');
      expect(requests.last.json, {
        'ids': [9],
      });
    },
  );
}
