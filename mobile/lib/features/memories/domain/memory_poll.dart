import '../../../core/rule_result.dart';

/// Who can see poll results, and when (README §3.4).
enum PollResultsVisibility {
  always('Everyone, any time'),
  afterVoting('People who have voted'),
  afterClosing('Everyone, after it closes');

  const PollResultsVisibility(this.label);
  final String label;
}

/// How long a new poll stays open.
enum PollDuration {
  never(null, 'No end date'),
  oneDay(Duration(days: 1), '1 day'),
  threeDays(Duration(days: 3), '3 days'),
  oneWeek(Duration(days: 7), '1 week');

  const PollDuration(this.length, this.label);
  final Duration? length;
  final String label;
}

class PollOption {
  const PollOption({required this.id, required this.label});
  final String id, label;
}

/// What the composer collects. Settings have calm defaults so a poll is
/// just a question and two options (README §4.0).
class PollDraft {
  const PollDraft({
    required this.question,
    required this.options,
    this.multipleChoice = false,
    this.anonymous = false,
    this.duration = PollDuration.never,
    this.resultsVisibility = PollResultsVisibility.afterVoting,
    this.allowChangeVote = true,
  });
  final String question;
  final List<String> options;
  final bool multipleChoice, anonymous, allowChangeVote;
  final PollDuration duration;
  final PollResultsVisibility resultsVisibility;
}

/// A poll as stored, including every person's votes.
class Poll {
  Poll({
    required this.id,
    required this.question,
    required List<PollOption> options,
    required this.createdBy,
    this.multipleChoice = false,
    this.anonymous = false,
    this.closesAt,
    this.resultsVisibility = PollResultsVisibility.afterVoting,
    this.allowChangeVote = true,
    this.closedAt,
    Map<String, Set<String>> votes = const {},
  }) : options = List.unmodifiable(options),
       votes = Map.unmodifiable({
         for (final entry in votes.entries)
           if (entry.value.isNotEmpty)
             entry.key: Set<String>.unmodifiable(entry.value),
       });
  final String id, question, createdBy;
  final List<PollOption> options;
  final bool multipleChoice, anonymous, allowChangeVote;
  final DateTime? closesAt, closedAt;
  final PollResultsVisibility resultsVisibility;

  /// Person → the option ids they chose.
  final Map<String, Set<String>> votes;

  bool isClosedAt(DateTime now) =>
      closedAt != null || (closesAt != null && !now.isBefore(closesAt!));

  Poll _copy({Map<String, Set<String>>? votes, DateTime? closedAt}) => Poll(
    id: id,
    question: question,
    options: options,
    createdBy: createdBy,
    multipleChoice: multipleChoice,
    anonymous: anonymous,
    closesAt: closesAt,
    resultsVisibility: resultsVisibility,
    allowChangeVote: allowChangeVote,
    closedAt: closedAt ?? this.closedAt,
    votes: votes ?? this.votes,
  );

  /// [choices] replaces the person's vote; an empty set removes it.
  Poll withVote(String person, Set<String> choices) =>
      _copy(votes: {...votes, person: choices});

  Poll closed(DateTime at) => _copy(closedAt: at);
}

/// One option as a particular viewer may see it. [count] and [percent] are
/// null while results are hidden; [voters] is empty for anonymous polls.
class PollOptionResult {
  const PollOptionResult({
    required this.id,
    required this.label,
    required this.chosen,
    this.count,
    this.percent,
    this.voters = const [],
  });
  final String id, label;
  final bool chosen;
  final int? count, percent;
  final List<String> voters;
}

/// A poll projected for one viewer: results already hidden according to
/// the poll's settings, and the actions this viewer may take.
class PollView {
  const PollView({
    required this.id,
    required this.question,
    required this.options,
    required this.multipleChoice,
    required this.anonymous,
    required this.resultsVisibility,
    required this.allowChangeVote,
    required this.closed,
    required this.totalVoters,
    required this.resultsVisible,
    required this.canVote,
    required this.canChangeVote,
    required this.canClose,
    required this.myChoices,
    this.closesAt,
  });
  final String id, question;
  final List<PollOptionResult> options;
  final bool multipleChoice, anonymous, allowChangeVote, closed;
  final PollResultsVisibility resultsVisibility;
  final DateTime? closesAt;

  /// How many people voted (each person counts once).
  final int totalVoters;
  final bool resultsVisible, canVote, canChangeVote, canClose;
  final Set<String> myChoices;

  bool get voted => myChoices.isNotEmpty;

  /// Whether "See who voted" has anything to show.
  bool get showsVoters => !anonymous && resultsVisible && totalVoters > 0;
}

/// Pure poll rules (README §3.4). The repository and the UI both use these;
/// membership is always of the exact group the poll was shared with.
abstract final class PollRules {
  static const maxQuestion = 200, minOptions = 2, maxOptions = 12;
  static const maxOption = 80;

  static const _notShared = RuleResult.denied(
    'This group is not shared with you.',
  );

  static List<String> _cleanOptions(List<String> options) => [
    for (final option in options) option.trim(),
  ];

  static RuleResult checkDraft(PollDraft draft) {
    final question = draft.question.trim();
    if (question.isEmpty || question.runes.length > maxQuestion) {
      return const RuleResult.denied('Ask a question with 1–200 characters.');
    }
    final options = _cleanOptions(draft.options);
    if (options.length < minOptions || options.length > maxOptions) {
      return const RuleResult.denied('Give 2–12 options.');
    }
    if (options.any((o) => o.isEmpty || o.runes.length > maxOption)) {
      return const RuleResult.denied('Each option needs 1–80 characters.');
    }
    final unique = options.map((o) => o.toLowerCase()).toSet();
    if (unique.length != options.length) {
      return const RuleResult.denied('Each option needs to be different.');
    }
    return const RuleResult.allowed();
  }

  /// Builds a poll from a draft that passed [checkDraft].
  static Poll create(
    PollDraft draft, {
    required String id,
    required String createdBy,
    required DateTime now,
  }) {
    final check = checkDraft(draft);
    if (!check.allowed) throw ArgumentError(check.reason);
    final length = draft.duration.length;
    return Poll(
      id: id,
      question: draft.question.trim(),
      options: [
        for (final (index, label) in _cleanOptions(draft.options).indexed)
          PollOption(id: '$id-option-${index + 1}', label: label),
      ],
      createdBy: createdBy,
      multipleChoice: draft.multipleChoice,
      anonymous: draft.anonymous,
      closesAt: length == null ? null : now.add(length),
      resultsVisibility: draft.resultsVisibility,
      allowChangeVote: draft.allowChangeVote,
    );
  }

  static RuleResult canSee({required bool isMember}) =>
      isMember ? const RuleResult.allowed() : _notShared;

  static RuleResult canVote(
    Poll poll, {
    required String voter,
    required bool isMember,
    required Set<String> choices,
    required DateTime now,
  }) {
    if (!isMember) return _notShared;
    if (poll.isClosedAt(now)) {
      return const RuleResult.denied('This poll has closed.');
    }
    if (choices.isEmpty) return const RuleResult.denied('Choose an option.');
    final ids = poll.options.map((o) => o.id).toSet();
    if (!ids.containsAll(choices)) {
      return const RuleResult.denied('That option isn’t in this poll.');
    }
    if (!poll.multipleChoice && choices.length > 1) {
      return const RuleResult.denied('Choose one option.');
    }
    if (poll.votes.containsKey(voter) && !poll.allowChangeVote) {
      return const RuleResult.denied('Votes can’t be changed in this poll.');
    }
    return const RuleResult.allowed();
  }

  /// Taking a vote back is a change of vote, so it follows the same rule.
  static RuleResult canRetract(
    Poll poll, {
    required String voter,
    required bool isMember,
    required DateTime now,
  }) {
    if (!isMember) return _notShared;
    if (poll.isClosedAt(now)) {
      return const RuleResult.denied('This poll has closed.');
    }
    if (!poll.votes.containsKey(voter)) {
      return const RuleResult.denied('You haven’t voted yet.');
    }
    if (!poll.allowChangeVote) {
      return const RuleResult.denied('Votes can’t be changed in this poll.');
    }
    return const RuleResult.allowed();
  }

  /// The creator, or an owner/admin of the exact group, may close early.
  static RuleResult canClose(
    Poll poll, {
    required String actor,
    required bool isMember,
    required bool isAdmin,
    required DateTime now,
  }) {
    if (!isMember) return _notShared;
    if (poll.isClosedAt(now)) {
      return const RuleResult.denied('This poll has already closed.');
    }
    if (poll.createdBy != actor && !isAdmin) {
      return const RuleResult.denied(
        'Only the person who asked or a group admin can close this poll.',
      );
    }
    return const RuleResult.allowed();
  }

  static bool resultsVisible(
    Poll poll, {
    required String viewer,
    required DateTime now,
  }) {
    final closed = poll.isClosedAt(now);
    return switch (poll.resultsVisibility) {
      PollResultsVisibility.always => true,
      PollResultsVisibility.afterVoting =>
        closed || poll.votes.containsKey(viewer),
      PollResultsVisibility.afterClosing => closed,
    };
  }

  /// Projects [poll] for [viewer]. Counts and names are left out whenever
  /// the settings say the viewer may not see them yet.
  static PollView view(
    Poll poll, {
    required String viewer,
    required bool isMember,
    required bool isAdmin,
    required DateTime now,
    required String Function(String person) nameOf,
  }) {
    final visible = isMember && resultsVisible(poll, viewer: viewer, now: now);
    final total = poll.votes.length;
    final mine = poll.votes[viewer] ?? const <String>{};
    final closed = poll.isClosedAt(now);
    return PollView(
      id: poll.id,
      question: poll.question,
      multipleChoice: poll.multipleChoice,
      anonymous: poll.anonymous,
      resultsVisibility: poll.resultsVisibility,
      allowChangeVote: poll.allowChangeVote,
      closesAt: poll.closesAt,
      closed: closed,
      totalVoters: total,
      resultsVisible: visible,
      myChoices: Set.unmodifiable(mine),
      canVote: isMember && !closed && (mine.isEmpty || poll.allowChangeVote),
      canChangeVote:
          isMember && !closed && mine.isNotEmpty && poll.allowChangeVote,
      canClose: canClose(
        poll,
        actor: viewer,
        isMember: isMember,
        isAdmin: isAdmin,
        now: now,
      ).allowed,
      options: [
        for (final option in poll.options)
          () {
            final people = [
              for (final entry in poll.votes.entries)
                if (entry.value.contains(option.id)) entry.key,
            ];
            return PollOptionResult(
              id: option.id,
              label: option.label,
              chosen: mine.contains(option.id),
              count: visible ? people.length : null,
              percent: !visible
                  ? null
                  : total == 0
                  ? 0
                  : (people.length * 100 / total).round(),
              voters: visible && !poll.anonymous
                  ? [for (final person in people) nameOf(person)]
                  : const [],
            );
          }(),
      ],
    );
  }

  /// "Closes in 2 days", "Closes in 3 hours", "Closed", or null when the
  /// poll has no end date.
  static String? timingLabel(PollView poll, DateTime now) {
    if (poll.closed) return 'Closed';
    final closesAt = poll.closesAt;
    if (closesAt == null) return null;
    final left = closesAt.difference(now);
    if (left.inDays >= 1) {
      return 'Closes in ${left.inDays} ${left.inDays == 1 ? 'day' : 'days'}';
    }
    if (left.inHours >= 1) {
      return 'Closes in ${left.inHours} '
          '${left.inHours == 1 ? 'hour' : 'hours'}';
    }
    return 'Closes soon';
  }
}
