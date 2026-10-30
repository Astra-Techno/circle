import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/signed_media_url.dart';
import 'package:mobile/core/circle_failure.dart';
import 'package:mobile/features/memories/application/photo_uploads.dart';
import 'package:mobile/features/memories/data/api_media_repository.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('http://circle.test/api/v1')!;

Uint8List jpeg([int size = 64]) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(size, 7)]);
Uint8List png() => Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  1,
  2,
  3,
  4,
]);
Uint8List webp() => Uint8List.fromList([
  ...'RIFF'.codeUnits,
  0,
  0,
  0,
  0,
  ...'WEBPVP8 '.codeUnits,
]);
Uint8List heic() =>
    Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0, 0, 0]);

ApiMediaRepository mediaFor(FakeHandler handler, {DateTime Function()? now}) =>
    ApiMediaRepository(
      api: ApiClient(
        config: config,
        tokens: MemoryTokenStore(
          TokenPair(
            accessToken: 'a',
            refreshToken: 'r',
            server: config.baseUrl.toString(),
          ),
        ),
        adapter: FakeHttpAdapter(handler),
      ),
      now: now,
    );

void main() {
  group('preparing a photo', () {
    test('the type comes from the bytes, not the name', () {
      expect(sniffImageType(jpeg()), 'image/jpeg');
      expect(sniffImageType(png()), 'image/png');
      expect(sniffImageType(webp()), 'image/webp');
      expect(sniffImageType(heic()), 'image/heic');
      expect(sniffImageType(Uint8List.fromList('GIF89a'.codeUnits)), isNull);
    });

    test('SHA-256 and a v4 upload id; retries keep the id', () {
      final bytes = jpeg();
      final photo = PreparedPhoto.prepare(bytes);
      expect(photo.sha256, crypto.sha256.convert(bytes).toString());
      expect(photo.size, bytes.length);
      expect(photo.mimeType, 'image/jpeg');
      expect(
        photo.clientUploadId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(
        photo.withNewUploadId().clientUploadId,
        isNot(photo.clientUploadId),
      );
    });

    test('HEIC, unknown and oversized photos get calm words', () {
      expect(
        () => PreparedPhoto.prepare(heic()),
        throwsA(
          isA<CircleFailure>().having(
            (e) => e.message,
            'message',
            contains('HEIC'),
          ),
        ),
      );
      expect(
        () => PreparedPhoto.prepare(Uint8List.fromList('GIF89a....'.codeUnits)),
        throwsA(
          isA<CircleFailure>().having(
            (e) => e.message,
            'message',
            contains('JPEG, PNG or WebP'),
          ),
        ),
      );
      expect(
        () => PreparedPhoto.prepare(jpeg(PreparedPhoto.maxBytes)),
        throwsA(
          isA<CircleFailure>().having(
            (e) => e.message,
            'message',
            contains('15 MB'),
          ),
        ),
      );
    });
  });

  group('upload pipeline', () {
    test('ticket → PUT bytes → ready media id', () async {
      final server = FakeCircleServer(mediaAvailable: true);
      final user = server.addUser('+15550000001', 'a' * 20, 'Asha');
      final group = server.addGroup('Family', user);
      final login =
          server.handle(
                FakeRequest(
                  'POST',
                  Uri.parse('http://circle.test/api/v1/auth/login'),
                  const {},
                  Uint8List.fromList(
                    '{"mobile":"+15550000001","password":"${'a' * 20}"}'
                        .codeUnits,
                  ),
                ),
              )
              as FakeResponse;
      final token =
          ((login.body! as Map)['data'] as Map)['access_token'] as String;
      final media = ApiMediaRepository(
        api: ApiClient(
          config: config,
          tokens: MemoryTokenStore(
            TokenPair(
              accessToken: token,
              refreshToken: 'x',
              server: config.baseUrl.toString(),
            ),
          ),
          adapter: server.adapter,
        ),
      );
      final photo = PreparedPhoto.prepare(jpeg(2000));
      final progress = <double>[];
      final id = await media.upload('$group', photo, onProgress: progress.add);
      expect(id, startsWith('a1b2c3d4-'));
      final ticket = server.adapter.requests.firstWhere(
        (r) => r.path.endsWith('/media/uploads'),
      );
      expect(ticket.json, {
        'client_upload_id': photo.clientUploadId,
        'mime_type': 'image/jpeg',
        'byte_size': photo.size,
        'sha256': photo.sha256,
      });
      final put = server.adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.path, '/media/uploads/$id/content');
      expect(put.bytes, photo.bytes);
      expect(put.headers['content-type'].toString(), contains('image/jpeg'));
      expect(progress.last, 1);
    });

    test('a retry reuses the same client_upload_id (idempotent)', () async {
      final tickets = <Object?>[];
      var puts = 0;
      final media = mediaFor((request) {
        if (request.path == '/groups/7/media/uploads') {
          tickets.add(request.json['client_upload_id']);
          return FakeResponse.ok({
            'upload_id': '11111111-2222-4333-8444-555555555555',
            'upload_path':
                '/media/uploads/11111111-2222-4333-8444-555555555555/content',
            'expires_at': '2026-10-23 10:15:00',
            'max_bytes': request.json['byte_size'],
          }, status: 201);
        }
        if (++puts == 1) {
          return const FakeResponse.network(DioExceptionType.connectionError);
        }
        return FakeResponse.ok({
          'id': '11111111-2222-4333-8444-555555555555',
          'status': 'ready',
        });
      });
      final photo = PreparedPhoto.prepare(jpeg());
      await expectLater(
        media.upload('7', photo),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'network_offline'),
        ),
      );
      expect(
        await media.upload('7', photo),
        '11111111-2222-4333-8444-555555555555',
      );
      expect(tickets, [photo.clientUploadId, photo.clientUploadId]);
    });

    test('503 (no image library) says photos can’t be processed', () async {
      final media = mediaFor(
        (_) => FakeResponse.error(
          503,
          'server_error',
          message: 'GD missing at /usr/lib',
        ),
      );
      await expectLater(
        media.upload('7', PreparedPhoto.prepare(jpeg())),
        throwsA(
          isA<ApiError>()
              .having(
                (e) => e.message,
                'message',
                'Photos can’t be processed on this server yet.',
              )
              .having((e) => e.status, 'status', 503),
        ),
      );
    });

    test('413 and 415 explain the limit and the types', () async {
      for (final (status, code, words) in [
        (413, 'media_too_large', '15 MB'),
        (415, 'media_type_not_allowed', 'JPEG, PNG or WebP'),
        (422, 'media_limit_reached', 'waiting to be shared'),
      ]) {
        final media = mediaFor((_) => FakeResponse.error(status, code));
        await expectLater(
          media.upload('7', PreparedPhoto.prepare(jpeg())),
          throwsA(
            isA<ApiError>().having(
              (e) => e.message,
              'message',
              contains(words),
            ),
          ),
        );
      }
    });
  });

  group('signed links', () {
    test('only same-server /media/files/ paths become image URLs', () {
      final expires = DateTime.utc(2026, 10, 23, 10, 5);
      final url = SignedMediaUrl.fromApi(
        config,
        '/media/files/abc/thumb?expires=1&sig=ff',
        expiresAt: expires,
      );
      expect(
        url.toString(),
        'http://circle.test/api/v1/media/files/abc/thumb?expires=1&sig=ff',
      );
      for (final bad in [
        'https://evil.test/media/files/abc/thumb',
        '//evil.test/media/files/abc/thumb',
        '/media/../groups/1',
        '/groups/1',
        '/media/files/../../x',
        '/media/files/a@evil.test/x',
      ]) {
        expect(
          SignedMediaUrl.fromApi(config, bad, expiresAt: expires),
          isNull,
          reason: bad,
        );
      }
    });

    test('explicit retry discards an otherwise valid cached link', () async {
      var fetches = 0;
      final media = mediaFor((_) {
        fetches++;
        return FakeResponse.ok({
          'url': '/media/files/m1/thumb?expires=$fetches&sig=${'a' * 64}',
          'expires_at': '2030-01-01T00:00:00Z',
        });
      }, now: () => DateTime.utc(2026));
      final old = await media.link('m1', MediaSize.thumb);
      expect(await media.link('m1', MediaSize.thumb), old);
      media.forget('m1', MediaSize.thumb);
      expect(await media.link('m1', MediaSize.thumb), isNot(old));
      expect(fetches, 2);
    });
    test('cached until ~30 seconds before expiry', () async {
      var now = DateTime.utc(2026, 10, 23, 10);
      var fetches = 0;
      final media = mediaFor((request) {
        fetches++;
        expect(request.query['size'], 'thumb');
        return FakeResponse.ok({
          'url': '/media/files/m1/thumb?expires=$fetches&sig=${'a' * 64}',
          'expires_at': '2026-10-23 10:05:00',
          'width': 320,
          'height': 240,
          'mime_type': 'image/webp',
        });
      }, now: () => now);
      final first = await media.link('m1', MediaSize.thumb);
      expect(await media.link('m1', MediaSize.thumb), first);
      expect(fetches, 1);
      now = DateTime.utc(2026, 10, 23, 10, 4, 20); // 40 s left
      expect(await media.link('m1', MediaSize.thumb), first);
      now = DateTime.utc(2026, 10, 23, 10, 4, 40); // 20 s left
      final fresh = await media.link('m1', MediaSize.thumb);
      expect(fresh, isNot(first));
      expect(fetches, 2);
      media.clear();
      await media.link('m1', MediaSize.thumb);
      expect(fetches, 3);
    });
  });

  group('composer uploads', () {
    PickedPhoto picked(Uint8List bytes) =>
        PickedPhoto(name: 'p.jpg', bytes: bytes);

    test('wait for a group, upload, then hand over ready ids', () async {
      final server = FakeCircleServer(mediaAvailable: true);
      final media = mediaFor(server.handle);
      final uploads = PhotoUploads(media);
      server.access['a'] = server.addUser('+1555', 'x' * 20, 'A');
      final group = server.addGroup('Family', server.access['a']!);
      uploads.add([picked(jpeg()), picked(heic())]);
      expect(uploads.items.first.status, UploadStatus.waiting);
      expect(uploads.items.last.status, UploadStatus.failed);
      expect(uploads.items.last.retryable, isFalse);
      expect(uploads.firstError, contains('HEIC'));
      uploads.remove(uploads.items.last);
      final completed = Completer<void>();
      void onUploadChanged() {
        if (!uploads.busy && !completed.isCompleted) completed.complete();
      }

      uploads.addListener(onUploadChanged);
      uploads.target('$group');
      try {
        await completed.future.timeout(const Duration(seconds: 5));
      } finally {
        uploads.removeListener(onUploadChanged);
      }
      expect(uploads.items.single.status, UploadStatus.ready);
      expect(uploads.readyIds, hasLength(1));
      expect(uploads.busy, isFalse);
      uploads.dispose();
    });

    test('503 fails calmly and Retry tries again with the same key', () async {
      final keys = <Object?>[];
      final media = mediaFor((request) {
        keys.add(request.json['client_upload_id']);
        return FakeResponse.error(503, 'server_error');
      });
      final uploads = PhotoUploads(media)..add([picked(jpeg())]);
      Future<void> waitUntilIdle(void Function() start) async {
        final completed = Completer<void>();
        void changed() {
          if (!uploads.busy && !completed.isCompleted) completed.complete();
        }

        uploads.addListener(changed);
        try {
          start();
          changed();
          await completed.future.timeout(const Duration(seconds: 5));
        } finally {
          uploads.removeListener(changed);
        }
      }

      await waitUntilIdle(() => uploads.target('7'));
      final item = uploads.items.single;
      expect(item.status, UploadStatus.failed);
      expect(
        uploads.firstError,
        'Photos can’t be processed on this server yet.',
      );
      expect(uploads.hasFailed, isTrue);
      await waitUntilIdle(() => uploads.retry(item));
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(1));
      uploads.dispose();
    });
  });
}
