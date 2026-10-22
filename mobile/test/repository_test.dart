import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/feed/data/mock_feed_repository.dart';
import 'package:mobile/features/community/data/mock_community_repository.dart';
import 'package:mobile/features/community/domain/entry.dart';
import 'package:mobile/app/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('mock invitation denies invalid code', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(sessionProvider.notifier).enter('invalid'), false);
    expect(container.read(sessionProvider), false);
    expect(
      container.read(sessionProvider.notifier).enter(' CIRCLE-DEMO '),
      true,
    );
    expect(container.read(sessionProvider), true);
  });
  test('mutations persist, toggle, validate, and reset', () async {
    final repository = MockFeedRepository();
    final original = await repository.load(demoCommunity);
    expect(repository.react(demoCommunity, 'courtyard').first.liked, true);
    expect(repository.react(demoCommunity, 'courtyard').first.liked, false);
    expect(repository.save(demoCommunity, 'courtyard').first.saved, true);
    repository.comment(demoCommunity, 'courtyard', ' A wonderful afternoon ');
    expect(
      (await repository.load(demoCommunity)).first.comments.last,
      'You: A wonderful afternoon',
    );
    expect(() => repository.create(demoCommunity, '  '), throwsArgumentError);
    expect(
      () => repository.comment(demoCommunity, 'courtyard', 'x' * 2001),
      throwsArgumentError,
    );
    expect(
      repository.create(demoCommunity, 'A new story').first.body,
      'A new story',
    );
    repository.reset();
    expect((await repository.load(demoCommunity)).length, original.length);
    expect((await repository.load(demoCommunity)).first.saved, false);
  });
  test(
    'all repository operations deny other communities and unknown resources',
    () async {
      final repository = MockFeedRepository();
      await expectLater(repository.load('other'), throwsStateError);
      expect(() => repository.react('other', 'courtyard'), throwsStateError);
      expect(() => repository.save('other', 'courtyard'), throwsStateError);
      expect(
        () => repository.comment('other', 'courtyard', 'test'),
        throwsStateError,
      );
      expect(() => repository.create('other', 'test'), throwsStateError);
      expect(
        () => repository.react(demoCommunity, 'private-group-post'),
        throwsStateError,
      );
      expect(
        () => MockCommunityRepository().entries('other', EntryKind.group),
        throwsStateError,
      );
    },
  );
}
