import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/api/auth_api.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('http://circle.test/api/v1')!;
final photo = ProfilePickedPhoto(
  bytes: Uint8List.fromList([255, 216, 255, 1]),
  mimeType: 'image/jpeg',
);

Future<ApiClient> signedIn(
  FakeCircleServer server,
  int user, {
  ApiConfig? configuration,
}) async {
  final client = ApiClient(
    config: configuration ?? config,
    tokens: MemoryTokenStore(),
    adapter: server.adapter,
  );
  await AuthApi(client).login(
    mobile: server.users[user]!['mobile'] as String,
    password: server.passwords[server.users[user]!['mobile']]!,
  );
  return client;
}

Future<void> settled(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    if (!container.read(serverSessionProvider).restoring) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Session restore did not settle');
}

ProviderContainer sessionFor(ApiClient client) {
  final container = ProviderContainer(
    overrides: [
      apiConfigProvider.overrideWithValue(client.config),
      apiClientProvider.overrideWithValue(client),
      localSettingsStoreProvider.overrideWithValue(MemoryLocalSettingsStore()),
    ],
  );
  container.listen(serverSessionProvider, (_, _) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profile fields persist independently and support clearing', () async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9995550000701',
      'fictional password',
      'Fictional Person',
    );
    final api = await signedIn(server, user);
    final auth = AuthApi(api);
    var account = await auth.updateProfile({
      'display_name': 'Updated Fictional Person',
      'about': 'Fictional bio',
      'current_city': 'Fictional city',
      'hometown': 'Fictional hometown',
      'work': 'Fictional work',
      'education': 'Fictional education',
    });
    expect(account.displayName, 'Updated Fictional Person');
    expect(account.about, 'Fictional bio');
    expect(account.mobile, '+9995550000701');
    expect(account.currentCity, 'Fictional city');
    expect(account.hometown, 'Fictional hometown');
    expect(account.work, 'Fictional work');
    expect(account.education, 'Fictional education');
    account = await auth.updateProfile({'current_city': ''});
    expect(account.currentCity, isEmpty);
    expect(account.work, 'Fictional work');
    expect(
      (await api.currentTokens())!.account!.displayName,
      'Updated Fictional Person',
    );
  });

  test(
    'profile photo bytes refresh bearer tokens and deletion removes version',
    () async {
      final server = FakeCircleServer(mediaAvailable: true);
      final user = server.addUser(
        '+9995550000702',
        'fictional password',
        'Fictional Person',
      );
      final api = await signedIn(server, user);
      final auth = AuthApi(api);
      final uploaded = await auth.uploadProfilePhoto(
        ProfilePhotoKind.avatar,
        photo,
      );
      expect(uploaded.avatarVersion, isNotNull);
      server.expireAccessTokens();
      expect(
        await api.getBytes('/me/photos/avatar', query: {'size': 'thumb'}),
        photo.bytes,
      );
      expect(server.adapter.count('POST', '/auth/refresh'), 1);
      expect(server.adapter.count('GET', '/me/photos/avatar'), 2);
      final deleted = await auth.deleteProfilePhoto(ProfilePhotoKind.avatar);
      expect(deleted.avatarVersion, isNull);
      await expectLater(
        api.getBytes('/me/photos/avatar'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_found')),
      );
    },
  );

  test(
    'a failed save keeps the previous account and input-independent data',
    () async {
      final server = FakeCircleServer();
      final user = server.addUser(
        '+9995550000703',
        'fictional password',
        'Fictional Person',
      );
      final api = await signedIn(server, user);
      final container = sessionFor(api);
      addTearDown(container.dispose);
      await settled(container);
      final session = container.read(serverSessionProvider.notifier);
      expect(await session.updateProfile({'work': 'Fictional work'}), isNull);
      expect(await session.updateProfile({'education': 'x' * 151}), isNotNull);
      expect(container.read(serverAccountProvider)!.work, 'Fictional work');
      expect(container.read(serverAccountProvider)!.education, isEmpty);
    },
  );

  test('an older profile read cannot replace a newer save', () async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9995550000704',
      'fictional password',
      'Fictional Person',
    );
    final api = await signedIn(server, user);
    final container = sessionFor(api);
    addTearDown(container.dispose);
    await settled(container);
    final started = Completer<void>(), release = Completer<void>();
    server.adapter.handler = (request) async {
      if (request.path == '/me' && request.method == 'GET') {
        final old = FakeResponse.ok(
          Map<String, Object?>.of(server.users[user]!),
        );
        started.complete();
        await release.future;
        return old;
      }
      return server.handle(request);
    };
    final session = container.read(serverSessionProvider.notifier);
    final oldRead = session.refreshProfile();
    await started.future;
    expect(await session.updateProfile({'work': 'New fictional work'}), isNull);
    release.complete();
    await oldRead;
    expect(container.read(serverAccountProvider)!.work, 'New fictional work');
  });

  test(
    'concurrent photo and details changes are serialized and both survive',
    () async {
      final server = FakeCircleServer(mediaAvailable: true);
      final user = server.addUser(
        '+9995550000705',
        'fictional password',
        'Fictional Person',
      );
      final api = await signedIn(server, user);
      final container = sessionFor(api);
      addTearDown(container.dispose);
      await settled(container);
      final started = Completer<void>(), release = Completer<void>();
      server.adapter.handler = (request) async {
        if (request.path == '/me/photos/avatar' && request.method == 'PUT') {
          started.complete();
          await release.future;
        }
        return server.handle(request);
      };
      final session = container.read(serverSessionProvider.notifier);
      final upload = session.uploadProfilePhoto(ProfilePhotoKind.avatar, photo);
      await started.future;
      final save = session.updateProfile({
        'education': 'New fictional education',
      });
      await Future<void>.delayed(Duration.zero);
      expect(server.adapter.count('PATCH', '/me'), 0);
      release.complete();
      expect(await upload, isNull);
      expect(await save, isNull);
      final account = container.read(serverAccountProvider)!;
      expect(account.avatarVersion, isNotNull);
      expect(account.education, 'New fictional education');
    },
  );

  test('an old photo family cannot load another account photo', () async {
    final server = FakeCircleServer(mediaAvailable: true);
    final first = server.addUser(
      '+9995550000706',
      'fictional password',
      'Fictional One',
    );
    final second = server.addUser(
      '+9995550000707',
      'fictional password',
      'Fictional Two',
    );
    final api = await signedIn(server, first);
    final uploaded = await AuthApi(
      api,
    ).uploadProfilePhoto(ProfilePhotoKind.avatar, photo);
    final firstAccount = uploaded;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        serverAccountProvider.overrideWithValue(firstAccount),
      ],
    );
    addTearDown(container.dispose);
    final query = (
      kind: ProfilePhotoKind.avatar,
      version: uploaded.avatarVersion!,
    );
    final listener = container.listen(
      profilePhotoBytesProvider(query),
      (_, _) {},
    );
    addTearDown(listener.close);
    expect(
      await container.read(profilePhotoBytesProvider(query).future),
      photo.bytes,
    );
    final previousReads = server.adapter.count('GET', '/me/photos/avatar');
    container.updateOverrides([
      apiClientProvider.overrideWithValue(api),
      serverAccountProvider.overrideWithValue(
        ApiAccount(
          id: '$second',
          displayName: 'Fictional Two',
          avatarVersion: 'different-version',
        ),
      ),
    ]);
    await expectLater(
      container.read(profilePhotoBytesProvider(query).future),
      throwsA(isA<Exception>()),
    );
    expect(server.adapter.count('GET', '/me/photos/avatar'), previousReads);
  });

  test(
    'an old-server save cannot replace a new server account with the same id',
    () async {
      final a = FakeCircleServer(), b = FakeCircleServer();
      final first = a.addUser(
        '+9995550000708',
        'fictional password',
        'Fictional Server One',
      );
      final second = b.addUser(
        '+9995550000709',
        'fictional password',
        'Fictional Server Two',
      );
      expect(first, second);
      final apiA = await signedIn(a, first);
      final apiB = await signedIn(
        b,
        second,
        configuration: ApiConfig.parse('http://other.test/api/v1')!,
      );
      final container = sessionFor(apiA);
      addTearDown(container.dispose);
      await settled(container);
      final started = Completer<void>(), release = Completer<void>();
      a.adapter.handler = (request) async {
        final response = await a.handle(request);
        if (request.path == '/me' && request.method == 'PATCH') {
          started.complete();
          await release.future;
        }
        return response;
      };
      final save = container.read(serverSessionProvider.notifier).updateProfile(
        {'display_name': 'Stale fictional name'},
      );
      await started.future;
      container.updateOverrides([
        apiConfigProvider.overrideWithValue(apiB.config),
        apiClientProvider.overrideWithValue(apiB),
        localSettingsStoreProvider.overrideWithValue(
          MemoryLocalSettingsStore(),
        ),
      ]);
      await settled(container);
      release.complete();
      await save;
      expect(
        container.read(serverAccountProvider)!.displayName,
        'Fictional Server Two',
      );
      expect(
        (await apiB.currentTokens())!.account!.displayName,
        'Fictional Server Two',
      );
    },
  );
}
