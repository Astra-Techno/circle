@Tags(['smoke'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/auth_api.dart';
import 'package:mobile/features/memories/data/api_media_repository.dart';
import 'package:mobile/features/workspace/data/api/api_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

/// End-to-end against a real CIRCLE API (development database only), using
/// the app's own client, repositories and mappers. Never part of the
/// default run. Example:
///
/// ```sh
/// flutter test test/smoke --run-skipped --tags smoke \
///   --dart-define=CIRCLE_SMOKE_API=http://127.0.0.1:8080/api/v1
/// ```
void main() {
  const url = String.fromEnvironment('CIRCLE_SMOKE_API');

  test(
    'register → log in → group → Memory → refresh → log out',
    () async {
      if (url.isEmpty) {
        markTestSkipped('Set --dart-define=CIRCLE_SMOKE_API=<base URL>.');
        return;
      }
      // flutter_test blocks real HTTP by default; this test is about it.
      HttpOverrides.global = null;
      final config = ApiConfig.parse(url)!;
      final tokens = MemoryTokenStore();
      final ended = <String>[];
      final api = ApiClient(config: config, tokens: tokens)
        ..onSessionEnded = ended.add;
      final auth = AuthApi(api);
      final log = <String>[];
      void step(String text) {
        log.add(text);
        // ignore: avoid_print
        print('smoke: $text');
      }

      // Fictional, random number on the development server.
      final mobile = '+1555${Random().nextInt(9000000) + 1000000}';
      const password = 'smoke test passphrase, 2026';
      await auth.register(
        mobile: mobile,
        password: password,
        displayName: 'Smoke Tester',
      );
      step('register → 202');
      final account = await auth.login(mobile: mobile, password: password);
      step('login → account ${account.id}');
      expect((await auth.me()).displayName, 'Smoke Tester');
      step('GET /me ok');

      final repo = ApiCircleRepository(
        api: api,
        viewer: account.id,
        viewerName: account.displayName,
      );
      expect((await repo.load(account.id)).groups, isEmpty);
      final group = await repo.createGroup(
        account.id,
        'Smoke Family',
        CircleType.family,
      );
      final sub = await repo.createGroup(
        account.id,
        'Smoke Cousins',
        CircleType.family,
        parentId: group.id,
      );
      step('created group ${group.id} and subgroup ${sub.id}');
      await repo.refresh(account.id);
      final workspace = await repo.load(account.id);
      expect(
        workspace.groups.map((g) => g.name),
        containsAll(['Smoke Family', 'Smoke Cousins']),
      );
      expect(workspace.group(group.id)!.ownerId, account.id);
      step('GET /groups → ${workspace.groups.length} groups, roles mapped');

      final memory = await repo.createMemory(
        account.id,
        group.id,
        'Smoke Memory',
        takenYear: 2007,
        place: 'Home',
      );
      await repo.react(account.id, memory, '🎉');
      final comment = await repo.comment(account.id, memory, 'First comment');
      await repo.comment(account.id, memory, 'A reply', replyTo: comment);
      await repo.saveMemory(account.id, memory);
      await repo.refresh(account.id);
      final shared = (await repo.load(
        account.id,
      )).memories.firstWhere((m) => m.id == memory);
      expect(shared.text, 'Smoke Memory');
      expect(shared.takenYear, 2007);
      expect(shared.reactions.mine, '🎉');
      expect(shared.saved, isTrue);
      expect(shared.commentTotal, 2);
      await repo.refreshMemory(account.id, memory);
      expect(
        (await repo.load(
          account.id,
        )).memories.firstWhere((m) => m.id == memory).comments.last.parentId,
        comment,
      );
      step(
        'Memory $memory shared, reacted, commented (with reply), saved, listed',
      );

      final link = await repo.createInviteLink(account.id, group.id);
      final preview = await repo.previewInvite(account.id, link.token);
      expect(preview.group?.name, 'Smoke Family');
      step('invite link created and previewed');

      final media = ApiMediaRepository(api: api);
      final jpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        ...List.filled(256, 1),
      ]);
      try {
        final id = await media.upload(group.id, PreparedPhoto.prepare(jpeg));
        step('photo upload → ready $id (server has an image library)');
      } on ApiError catch (error) {
        step('photo upload → ${error.status} "${error.message}"');
        expect(error.status, anyOf(503, 422));
      }

      // Force the access token to be rejected: the client refreshes once
      // (single-use rotation) and retries.
      final before = (await api.currentTokens())!;
      await api.saveTokens(
        TokenPair(
          accessToken: 'expired.invalid.token',
          refreshToken: before.refreshToken,
          server: before.server,
        ),
      );
      expect((await auth.me()).id, account.id);
      final after = (await api.currentTokens())!;
      expect(after.refreshToken, isNot(before.refreshToken));
      step('401 invalid_token → refresh → retried ok (refresh token rotated)');

      await auth.logout();
      expect(await tokens.read(), isNull);
      // The revoked session's tokens no longer work.
      await api.saveTokens(after);
      await expectLater(auth.me(), throwsA(isA<ApiError>()));
      expect(ended, isNotEmpty);
      step('logout → tokens cleared, old session refused');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
