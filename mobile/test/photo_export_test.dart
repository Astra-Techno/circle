import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/scoped_api.dart';
import 'package:mobile/core/circle_failure.dart';
import 'package:mobile/features/memories/data/api_media_repository.dart';
import 'package:mobile/features/memories/data/photo_export.dart';
import 'package:mobile/features/memories/domain/memory_photo.dart';

import 'support/fake_api.dart';

const _bundled = MemoryPhoto(id: 'fictional-hill', scene: MemoryScene.hillTrip);
const _illustrated = MemoryPhoto(
  id: 'fictional-birthday',
  scene: MemoryScene.birthdayCake,
);
const _uploaded = MemoryPhoto(id: 'uploaded-photo', mediaId: '1');

Uint8List _jpeg() => Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
Uint8List _png() => Uint8List.fromList(const [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  1,
]);
Uint8List _webp() => Uint8List.fromList([
  ...'RIFF'.codeUnits,
  0,
  0,
  0,
  0,
  ...'WEBPVP8 '.codeUnits,
]);

class _FakeExportBridge implements PhotoExportBridge {
  @override
  bool supported = true;
  bool result = true;
  final calls = <(PhotoExportAction, PhotoExportPayload)>[];

  @override
  Future<bool> export(
    PhotoExportAction action,
    PhotoExportPayload photo,
  ) async {
    calls.add((action, photo));
    return result;
  }
}

class _BytesAssets extends AssetBundle {
  _BytesAssets(this.bytes);
  final Uint8List bytes;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled JPEG exports without a server session', () async {
    final bridge = _FakeExportBridge();
    final service = PhotoExportService(bridge, null, null);

    expect(
      await service.export(
        _bundled,
        PhotoExportAction.share,
        asset: 'assets/welcome/friends.jpg',
      ),
      isTrue,
    );
    expect(bridge.calls.single.$1, PhotoExportAction.share);
    expect(bridge.calls.single.$2.name, 'circle-photo.jpg');
    expect(bridge.calls.single.$2.mimeType, 'image/jpeg');
    expect(bridge.calls.single.$2.bytes, isNotEmpty);
  });

  test(
    'illustrations and invalid bytes are rejected before native export',
    () async {
      final bridge = _FakeExportBridge();
      final service = PhotoExportService(bridge, null, null);
      await expectLater(
        service.export(_illustrated, PhotoExportAction.share),
        throwsA(
          isA<CircleFailure>().having(
            (error) => error.message,
            'message',
            'Illustrated placeholders can’t be exported.',
          ),
        ),
      );
      await expectLater(
        PhotoExportService(
          bridge,
          null,
          null,
          assets: _BytesAssets(Uint8List.fromList('not an image'.codeUnits)),
        ).export(_illustrated, PhotoExportAction.share, asset: 'invalid'),
        throwsA(isA<CircleFailure>()),
      );
      expect(bridge.calls, isEmpty);

      for (final sample in [_png(), _webp()]) {
        await PhotoExportService(
          bridge,
          null,
          null,
          assets: _BytesAssets(sample),
        ).export(_illustrated, PhotoExportAction.share, asset: 'valid');
      }
      expect(bridge.calls.map((call) => call.$2.name), [
        'circle-photo.png',
        'circle-photo.webp',
      ]);
    },
  );

  test(
    'uploaded export uses full authorized bytes and rejects a changed session',
    () async {
      final adapter = FakeHttpAdapter((request) {
        if (request.path == '/media/1') {
          return FakeResponse.ok({
            'url': '/media/files/fictional.jpg?signature=fictional',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          });
        }
        if (request.path == '/media/files/fictional.jpg') {
          return FakeResponse(200, _jpeg());
        }
        return FakeResponse.error(404, 'not_found');
      });
      final api = ApiClient(
        config: ApiConfig.parse('https://fictional.test/api/v1')!,
        tokens: MemoryTokenStore(),
        adapter: adapter,
      );
      addTearDown(() => api.dio.close(force: true));
      await api.saveTokens(
        const TokenPair(
          accessToken: 'fictional-access',
          refreshToken: 'fictional-refresh',
          server: 'https://fictional.test/api/v1',
          account: StoredAccount(id: '1', displayName: 'Fictional A'),
        ),
      );
      var current = true;
      final scope = ScopedApi(api, '1', api.sessionRevision, () => current);
      final bridge = _FakeExportBridge();
      final service = PhotoExportService(
        bridge,
        ApiMediaRepository(api: api),
        scope,
      );

      expect(
        await service.export(_uploaded, PhotoExportAction.download),
        isTrue,
      );
      expect(adapter.count('GET', '/media/1'), 1);
      expect(adapter.count('GET', '/media/files/fictional.jpg'), 1);
      expect(adapter.requests[0].query['size'], 'full');
      expect(adapter.requests[1].bearer, 'fictional-access');
      expect(bridge.calls.single.$2.bytes, _jpeg());

      current = false;
      await expectLater(
        service.export(_uploaded, PhotoExportAction.share),
        throwsA(isA<ApiError>()),
      );
      expect(bridge.calls, hasLength(1));
    },
  );

  test('native export is offered only on Android and iOS', () {
    const bridge = DevicePhotoExportBridge();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(bridge.supported, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(bridge.supported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(bridge.supported, isTrue);
  });

  test(
    'method channel sends exact bytes and maps cancellation and busy errors',
    () async {
      const channel = MethodChannel('circle/photo_export');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return false;
      });
      final payload = PhotoExportPayload(
        bytes: _jpeg(),
        name: 'circle-photo.jpg',
        mimeType: 'image/jpeg',
      );
      expect(
        await const DevicePhotoExportBridge().export(
          PhotoExportAction.share,
          payload,
        ),
        isFalse,
      );
      expect(calls.single.method, 'export');
      expect(calls.single.arguments, {
        'action': 'share',
        'bytes': payload.bytes,
        'name': 'circle-photo.jpg',
        'mime_type': 'image/jpeg',
      });

      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'busy', message: 'Native busy');
      });
      await expectLater(
        PhotoExportService(
          const DevicePhotoExportBridge(),
          null,
          null,
          assets: _BytesAssets(_jpeg()),
        ).export(_illustrated, PhotoExportAction.share, asset: 'photo'),
        throwsA(
          isA<CircleFailure>().having(
            (error) => error.message,
            'message',
            'Finish the current photo action first.',
          ),
        ),
      );
    },
  );
}
