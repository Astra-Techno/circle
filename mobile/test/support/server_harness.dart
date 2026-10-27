import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/memories/application/media_providers.dart';
import 'fake_api.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';

final testServer = ApiConfig.parse('http://circle.test/api/v1')!;

/// Returns the photos a test chose, as if picked from the library.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.photos = const []]);
  List<PickedPhoto> photos;
  int calls = 0;
  @override
  Future<List<PickedPhoto>> pick({required int max}) async {
    calls++;
    return photos.take(max).toList();
  }
}

/// Pumps the real app in server mode against [server] (no network).
Future<ProviderContainer> openServerCircle(
  WidgetTester tester,
  FakeCircleServer server, {
  ApiConfig? config,
  TokenStore? tokens,
  PhotoPicker? picker,
  ProfilePhotoPicker? profilePicker,
  LocalSettingsStore? settings,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(
    overrides: [
      apiConfigProvider.overrideWithValue(config ?? testServer),
      localSettingsStoreProvider.overrideWithValue(
        settings ?? MemoryLocalSettingsStore(),
      ),
      tokenStoreProvider.overrideWithValue(tokens ?? MemoryTokenStore()),
      apiHttpAdapterProvider.overrideWithValue(server.adapter),
      photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      if (profilePicker != null)
        profilePhotoPickerProvider.overrideWithValue(profilePicker),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CircleExperience(),
    ),
  );
  await settle(tester);
  return container;
}

/// Lets fake HTTP round trips finish, then settles animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

/// A stored session for [server], as after an earlier log-in.
Future<MemoryTokenStore> storedSession(
  FakeCircleServer server,
  int user, {
  ApiConfig? config,
}) async {
  final login = await server.handle(
    FakeRequest(
      'POST',
      Uri.parse('http://circle.test/api/v1/auth/login'),
      const {},
      _json({
        'mobile': server.users[user]!['mobile'],
        'password': server.passwords[server.users[user]!['mobile']],
      }),
    ),
  );
  final data = (login.body! as Map)['data'] as Map;
  return MemoryTokenStore(
    TokenPair(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      server: (config ?? testServer).baseUrl.toString(),
    ),
  );
}

Uint8List _json(Map<String, Object?> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
