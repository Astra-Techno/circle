import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/memories/domain/circle_memory.dart';

final now = DateTime.utc(2026, 10, 23, 12);

PollDraft draft({
  String question = 'Where should we meet?',
  List<String> options = const ['Lake', 'Hills'],
  bool multipleChoice = false,
  bool anonymous = false,
  PollDuration duration = PollDuration.never,
  PollResultsVisibility visibility = PollResultsVisibility.afterVoting,
  bool allowChangeVote = true,
}) => PollDraft(
  question: question,
  options: options,
  multipleChoice: multipleChoice,
  anonymous: anonymous,
  duration: duration,
  resultsVisibility: visibility,
  allowChangeVote: allowChangeVote,
);

Poll poll({
  bool multipleChoice = false,
  bool anonymous = false,
  PollDuration duration = PollDuration.never,
  PollResultsVisibility visibility = PollResultsVisibility.afterVoting,
  bool allowChangeVote = true,
  List<String> options = const ['Lake', 'Hills', 'Beach'],
}) => PollRules.create(
  draft(
    options: options,
    multipleChoice: multipleChoice,
    anonymous: anonymous,
    duration: duration,
    visibility: visibility,
    allowChangeVote: allowChangeVote,
  ),
  id: 'p',
  createdBy: 'mira',
  now: now,
);

String name(String person) => person.toUpperCase();

void main() {
  group('PollRules drafts', () {
    test('question needs 1–200 characters after trimming', () {
      expect(PollRules.checkDraft(draft(question: '   ')).allowed, isFalse);
      expect(PollRules.checkDraft(draft(question: 'x' * 201)).allowed, false);
      expect(PollRules.checkDraft(draft(question: 'x' * 200)).allowed, true);
    });

    test('2–12 options, each 1–80 characters', () {
      expect(PollRules.checkDraft(draft(options: ['Only'])).allowed, isFalse);
      final twelve = [for (var i = 1; i <= 12; i++) 'Option $i'];
      expect(PollRules.checkDraft(draft(options: twelve)).allowed, isTrue);
      expect(
        PollRules.checkDraft(draft(options: [...twelve, 'Thirteen'])).allowed,
        isFalse,
      );
      expect(PollRules.checkDraft(draft(options: ['A', '  '])).allowed, false);
      expect(
        PollRules.checkDraft(draft(options: ['A', 'x' * 81])).allowed,
        false,
      );
      expect(
        PollRules.checkDraft(draft(options: ['A', 'x' * 80])).allowed,
        true,
      );
    });

    test('options are trimmed and must be unique ignoring case', () {
      final result = PollRules.checkDraft(draft(options: ['Lake', ' lake ']));
      expect(result.reason, 'Each option needs to be different.');
      final created = PollRules.create(
        draft(question: '  Meet?  ', options: [' Lake ', 'Hills']),
        id: 'p',
        createdBy: 'mira',
        now: now,
      );
      expect(created.question, 'Meet?');
      expect(created.options.map((o) => o.label), ['Lake', 'Hills']);
      expect(created.options.map((o) => o.id).toSet(), hasLength(2));
    });

    test(
      'defaults: single choice, named, results after voting, changeable',
      () {
        final created = poll();
        expect(created.multipleChoice, isFalse);
        expect(created.anonymous, isFalse);
        expect(created.resultsVisibility, PollResultsVisibility.afterVoting);
        expect(created.allowChangeVote, isTrue);
        expect(created.closesAt, isNull);
        expect(
          poll(duration: PollDuration.threeDays).closesAt,
          now.add(const Duration(days: 3)),
        );
      },
    );

    test('create rejects an invalid draft', () {
      expect(
        () => PollRules.create(
          draft(options: ['One']),
          id: 'p',
          createdBy: 'mira',
          now: now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PollRules voting', () {
    test('single choice allows exactly one known option', () {
      final p = poll();
      final lake = p.options.first.id, hills = p.options[1].id;
      bool vote(Set<String> choices) => PollRules.canVote(
        p,
        voter: 'you',
        isMember: true,
        choices: choices,
        now: now,
      ).allowed;
      expect(vote({lake}), isTrue);
      expect(vote({lake, hills}), isFalse);
      expect(vote({}), isFalse);
      expect(vote({'other-poll-option'}), isFalse);
    });

    test('multiple choice allows several options', () {
      final p = poll(multipleChoice: true);
      expect(
        PollRules.canVote(
          p,
          voter: 'you',
          isMember: true,
          choices: {p.options[0].id, p.options[2].id},
          now: now,
        ).allowed,
        isTrue,
      );
    });

    test('only members of the exact group can vote or see', () {
      final p = poll();
      expect(
        PollRules.canVote(
          p,
          voter: 'stranger',
          isMember: false,
          choices: {p.options.first.id},
          now: now,
        ).reason,
        'This group is not shared with you.',
      );
      expect(PollRules.canSee(isMember: false).allowed, isFalse);
      expect(PollRules.canSee(isMember: true).allowed, isTrue);
    });

    test('no voting when closed early or past closesAt', () {
      final timed = poll(duration: PollDuration.oneDay);
      final choice = {timed.options.first.id};
      bool vote(Poll p, DateTime at) => PollRules.canVote(
        p,
        voter: 'you',
        isMember: true,
        choices: choice,
        now: at,
      ).allowed;
      expect(vote(timed, now.add(const Duration(hours: 23))), isTrue);
      expect(vote(timed, now.add(const Duration(days: 1))), isFalse);
      expect(vote(poll().closed(now), now), isFalse);
    });

    test('changing a vote only when the poll allows it', () {
      final fixed = poll(allowChangeVote: false);
      final voted = fixed.withVote('you', {fixed.options.first.id});
      expect(
        PollRules.canVote(
          voted,
          voter: 'you',
          isMember: true,
          choices: {fixed.options[1].id},
          now: now,
        ).allowed,
        isFalse,
      );
      expect(
        PollRules.canRetract(
          voted,
          voter: 'you',
          isMember: true,
          now: now,
        ).allowed,
        isFalse,
      );
      final open = poll();
      final changed = open.withVote('you', {open.options.first.id});
      expect(
        PollRules.canVote(
          changed,
          voter: 'you',
          isMember: true,
          choices: {open.options[1].id},
          now: now,
        ).allowed,
        isTrue,
      );
      expect(
        PollRules.canRetract(
          changed,
          voter: 'you',
          isMember: true,
          now: now,
        ).allowed,
        isTrue,
      );
      expect(
        PollRules.canRetract(
          open,
          voter: 'you',
          isMember: true,
          now: now,
        ).allowed,
        isFalse,
        reason: 'nothing to take back',
      );
    });

    test('creator or group admins/owner can close early', () {
      final p = poll();
      RuleResult close(
        String actor, {
        bool admin = false,
        bool member = true,
      }) => PollRules.canClose(
        p,
        actor: actor,
        isMember: member,
        isAdmin: admin,
        now: now,
      );
      expect(close('mira').allowed, isTrue, reason: 'creator');
      expect(close('you', admin: true).allowed, isTrue, reason: 'admin');
      expect(close('dev').allowed, isFalse, reason: 'member');
      expect(close('mira', member: false).allowed, isFalse);
      expect(
        PollRules.canClose(
          p.closed(now),
          actor: 'mira',
          isMember: true,
          isAdmin: false,
          now: now,
        ).allowed,
        isFalse,
      );
    });
  });

  group('PollRules results', () {
    PollView view(Poll p, {String viewer = 'you', DateTime? at}) =>
        PollRules.view(
          p,
          viewer: viewer,
          isMember: true,
          isAdmin: false,
          now: at ?? now,
          nameOf: name,
        );

    test('after voting: hidden until the viewer votes, then counts show', () {
      var p = poll();
      p = p.withVote('mira', {p.options.first.id});
      var shown = view(p);
      expect(shown.resultsVisible, isFalse);
      expect(shown.options.every((o) => o.count == null), isTrue);
      expect(shown.options.every((o) => o.voters.isEmpty), isTrue);
      expect(shown.totalVoters, 1);
      p = p.withVote('you', {p.options[1].id});
      shown = view(p);
      expect(shown.resultsVisible, isTrue);
      expect(shown.options.map((o) => o.count), [1, 1, 0]);
      expect(shown.options.map((o) => o.percent), [50, 50, 0]);
      expect(shown.options[1].chosen, isTrue);
      expect(shown.options.first.voters, ['MIRA']);
      expect(shown.canChangeVote, isTrue);
    });

    test('after closing: hidden even after voting until closed', () {
      var p = poll(visibility: PollResultsVisibility.afterClosing);
      p = p.withVote('you', {p.options.first.id});
      expect(view(p).resultsVisible, isFalse);
      expect(view(p.closed(now)).resultsVisible, isTrue);
      final timed = poll(
        visibility: PollResultsVisibility.afterClosing,
        duration: PollDuration.oneDay,
      );
      expect(
        view(timed, at: now.add(const Duration(days: 2))).resultsVisible,
        isTrue,
      );
    });

    test('always: visible before voting', () {
      expect(
        view(poll(visibility: PollResultsVisibility.always)).resultsVisible,
        isTrue,
      );
    });

    test('anonymous polls never reveal voter names', () {
      var p = poll(anonymous: true, visibility: PollResultsVisibility.always);
      p = p.withVote('mira', {p.options.first.id});
      final shown = view(p);
      expect(shown.options.first.count, 1);
      expect(shown.options.first.voters, isEmpty);
      expect(shown.showsVoters, isFalse);
    });

    test('multiple choice percentages are per voter', () {
      var p = poll(
        multipleChoice: true,
        visibility: PollResultsVisibility.always,
      );
      p = p.withVote('mira', {p.options[0].id, p.options[1].id}).withVote(
        'dev',
        {p.options[0].id},
      );
      expect(view(p).options.map((o) => o.percent), [100, 50, 0]);
      expect(view(p).totalVoters, 2);
    });

    test('closed polls offer no voting or closing', () {
      final shown = view(poll().closed(now));
      expect(shown.closed, isTrue);
      expect(shown.canVote, isFalse);
      expect(shown.canClose, isFalse);
      expect(PollRules.timingLabel(shown, now), 'Closed');
    });

    test('timing label counts down', () {
      final timed = poll(duration: PollDuration.threeDays);
      expect(
        PollRules.timingLabel(view(timed), now.add(const Duration(hours: 1))),
        'Closes in 2 days',
      );
      expect(
        PollRules.timingLabel(
          view(timed),
          now.add(const Duration(days: 2, hours: 20)),
        ),
        'Closes in 4 hours',
      );
      expect(PollRules.timingLabel(view(poll()), now), isNull);
    });
  });

  group('ReactionRules', () {
    test('only the 8-emoji allowlist is accepted', () {
      expect(memoryReactions, ['❤️', '😂', '😮', '😢', '🙏', '👍', '🎉', '🔥']);
      for (final emoji in memoryReactions) {
        expect(ReactionRules.check(emoji).allowed, isTrue, reason: emoji);
      }
      for (final emoji in ['💩', 'love', '', '❤']) {
        expect(ReactionRules.check(emoji).allowed, isFalse, reason: emoji);
      }
    });

    test('one per person: same emoji removes, another replaces', () {
      var byPerson = ReactionRules.toggle({}, 'you', '❤️');
      expect(byPerson, {'you': '❤️'});
      byPerson = ReactionRules.toggle(byPerson, 'you', '😂');
      expect(byPerson, {'you': '😂'});
      byPerson = ReactionRules.toggle(byPerson, 'mira', '😂');
      byPerson = ReactionRules.toggle(byPerson, 'you', '😂');
      expect(byPerson, {'mira': '😂'});
    });

    test('viewer projection separates mine from others and ranks', () {
      final view = ReactionRules.viewFor({
        'you': '🔥',
        'a': '❤️',
        'b': '❤️',
        'c': '😂',
        'd': '🔥',
      }, 'you');
      expect(view.mine, '🔥');
      expect(view.others, {'❤️': 2, '😂': 1, '🔥': 1});
      expect(view.total, 5);
      expect(view.countOf('🔥'), 2);
      expect(view.ranked.map((r) => r.emoji), ['❤️', '🔥', '😂']);
      expect(view.describe(), '5 reactions: 2 Love, 2 Fire, 1 Laugh');
      expect(MemoryReactions().describe(), 'No reactions yet');
    });
  });

  group('CommentRules', () {
    MemoryComment comment(
      String id, {
      String author = 'mira',
      String? parent,
      int minute = 0,
    }) => MemoryComment(
      id: id,
      authorId: author,
      authorName: author,
      text: 'Comment $id',
      createdAt: now.add(Duration(minutes: minute)),
      parentId: parent,
    );

    test('text needs 1–2000 characters', () {
      expect(CommentRules.checkText('  ').allowed, isFalse);
      expect(CommentRules.checkText('x' * 2001).allowed, isFalse);
      expect(CommentRules.checkText(' x ').allowed, isTrue);
    });

    test('replies only to a top-level comment that exists here', () {
      final comments = [comment('a'), comment('b', parent: 'a')];
      expect(CommentRules.canReply(comments, 'a').allowed, isTrue);
      expect(CommentRules.canReply(comments, 'b').allowed, isFalse);
      expect(CommentRules.canReply(comments, 'elsewhere').allowed, isFalse);
    });

    test('only the author deletes their own comment', () {
      expect(CommentRules.canDelete(comment('a'), 'mira').allowed, isTrue);
      expect(CommentRules.canDelete(comment('a'), 'you').allowed, isFalse);
    });

    test('threads keep order with replies under their parent', () {
      final threads = CommentRules.threads([
        comment('second', minute: 2),
        comment('reply-late', parent: 'first', minute: 5),
        comment('first', minute: 1),
        comment('reply-early', parent: 'first', minute: 3),
        comment('orphan', parent: 'gone', minute: 4),
      ]);
      expect(threads.map((t) => t.comment.id), ['first', 'second']);
      expect(threads.first.replies.map((c) => c.id), [
        'reply-early',
        'reply-late',
      ]);
      expect(threads.last.replies, isEmpty);
    });

    test('latest picks the newest visible comment or reply', () {
      expect(CommentRules.latest([]), isNull);
      expect(
        CommentRules.latest([
          comment('a', minute: 1),
          comment('b', parent: 'a', minute: 9),
          comment('c', minute: 5),
        ])!.id,
        'b',
      );
    });
  });

  group('MemoryRules', () {
    test('a Memory needs text, photos or a poll', () {
      expect(MemoryRules.checkContent(text: '  ').allowed, isFalse);
      expect(MemoryRules.checkContent(text: 'Hello').allowed, isTrue);
      expect(MemoryRules.checkContent(text: '', photoCount: 1).allowed, isTrue);
      expect(MemoryRules.checkContent(text: '', hasPoll: true).allowed, isTrue);
      expect(MemoryRules.checkContent(text: 'x' * 2001).allowed, isFalse);
      expect(
        MemoryRules.checkContent(text: 'x' * 2001, photoCount: 2).allowed,
        isFalse,
        reason: 'photos never excuse oversized text',
      );
      expect(
        MemoryRules.checkContent(text: '', photoCount: 11).allowed,
        isFalse,
      );
    });

    test('year taken is 1950 to the current year; blank is fine', () {
      expect(MemoryRules.checkYear(null, now).allowed, isTrue);
      expect(MemoryRules.checkYear(1950, now).allowed, isTrue);
      expect(MemoryRules.checkYear(2026, now).allowed, isTrue);
      expect(MemoryRules.checkYear(1949, now).allowed, isFalse);
      expect(MemoryRules.checkYear(2027, now).allowed, isFalse);
      expect(MemoryRules.parseYear(' ', now).year, isNull);
      expect(MemoryRules.parseYear(' ', now).result.allowed, isTrue);
      expect(MemoryRules.parseYear('2007', now).year, 2007);
      expect(MemoryRules.parseYear('07a', now).result.allowed, isFalse);
    });

    test('place is optional and at most 80 characters', () {
      expect(MemoryRules.checkPlace(null).allowed, isTrue);
      expect(MemoryRules.checkPlace('x' * 80).allowed, isTrue);
      expect(MemoryRules.checkPlace('x' * 81).allowed, isFalse);
      expect(MemoryRules.cleanPlace('  '), isNull);
      expect(MemoryRules.cleanPlace(' Kodaikanal '), 'Kodaikanal');
    });

    test('only the author edits or deletes', () {
      expect(MemoryRules.canChange('you', 'you').allowed, isTrue);
      expect(MemoryRules.canChange('mira', 'you').allowed, isFalse);
    });

    test('meta line and summary', () {
      CircleMemory memory({String text = '', int? year, String? place}) =>
          CircleMemory(
            id: 'm',
            groupId: 'g',
            authorId: 'you',
            author: 'You',
            text: text,
            createdAt: now,
            takenYear: year,
            place: place,
            photos: const [
              MemoryPhoto(id: 'p1', scene: MemoryScene.beachWalk),
              MemoryPhoto(id: 'p2', scene: MemoryScene.hillTrip),
            ],
          );
      expect(
        memory(year: 2007, place: 'Kodaikanal').takenLabel,
        'Taken in 2007 · Kodaikanal',
      );
      expect(memory(year: 2007).takenLabel, 'Taken in 2007');
      expect(memory().takenLabel, isNull);
      expect(memory().summary, '2 photos');
      expect(memory(text: 'Hi').summary, 'Hi');
    });
  });
}
