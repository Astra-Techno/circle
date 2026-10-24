import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';

/// F2 poll card inside a Memory.
class MemoryPollCard extends ConsumerWidget {
  const MemoryPollCard({super.key, required this.memoryId, required this.poll});
  final String memoryId;
  final PollView poll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(circleWorkspaceProvider.notifier);
    return PollCard(
      poll: poll,
      onVote: (choices) => controller.vote(memoryId, choices),
      onRetract: () => controller.retractVote(memoryId),
      onClose: () => controller.closePoll(memoryId),
    );
  }
}

/// F2 poll card, shared by Memories and event date polls. Single choice
/// votes with one tap; multiple choice ticks options, then "Submit vote".
/// Results follow the poll's visibility setting, already applied by the
/// repository. The callbacks reach the poll's owner (a Memory or event).
class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.onVote,
    required this.onRetract,
    required this.onClose,
  });
  final PollView poll;
  final Future<void> Function(Set<String> choices) onVote;
  final Future<void> Function() onRetract, onClose;
  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _changing = false;
  final Set<String> _selection = {};

  Future<void> _vote(Set<String> choices) async {
    final poll = widget.poll;
    final previous = {...poll.myChoices};
    final vote = widget.onVote, retract = widget.onRetract;
    final saved = await runCalmly(
      context,
      () async {
        await vote(choices);
        return true;
      },
      success: poll.allowChangeVote
          ? 'Vote saved.'
          : 'Vote saved. Votes can’t be changed in this poll.',
      onUndo: poll.allowChangeVote
          ? undoWith(
              context,
              () => previous.isEmpty ? retract() : vote(previous),
            )
          : null,
    );
    if (saved == true && mounted) {
      setState(() {
        _changing = false;
        _selection.clear();
      });
    }
  }

  Future<void> _close() async {
    final confirmed = await confirmCircleAction(
      context,
      title: 'Close this poll?',
      message: 'No one can vote after it closes. This can’t be undone.',
      confirm: 'Close poll',
    );
    if (!confirmed || !mounted) return;
    await runCalmly(context, widget.onClose, success: 'Poll closed.');
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = CircleAccents.of(context);
    final voting = poll.canVote && (!poll.voted || _changing);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final votes =
        '${poll.totalVoters} ${poll.totalVoters == 1 ? 'vote' : 'votes'}';
    final timing = PollRules.timingLabel(poll, DateTime.now());
    final hiddenNote = poll.resultsVisible
        ? null
        : poll.resultsVisibility == PollResultsVisibility.afterClosing
        ? 'Results appear after the poll closes.'
        : 'Results appear after you vote.';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: accents.hairline),
        borderRadius: BorderRadius.circular(CircleRadius.inner),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CirclePill(
                  poll.closed ? 'Poll · Closed' : 'Poll',
                  icon: Icons.poll_outlined,
                  tone: poll.closed ? CircleTone.neutral : CircleTone.calm,
                ),
                if (poll.anonymous)
                  const CirclePill(
                    'Anonymous votes',
                    icon: Icons.visibility_off_outlined,
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Semantics(
              header: true,
              child: Text(poll.question, style: theme.textTheme.titleMedium),
            ),
            if (voting) ...[
              const SizedBox(height: Space.xs),
              Text(
                poll.multipleChoice ? 'Choose any that apply' : 'Choose one',
                style: caption,
              ),
            ],
            const SizedBox(height: Space.sm),
            if (voting)
              ..._votingRows(poll)
            else if (poll.resultsVisible)
              for (final option in poll.options) _ResultBar(option: option)
            else
              for (final option in poll.options) _PlainOption(option: option),
            if (hiddenNote != null) ...[
              const SizedBox(height: Space.xs),
              Text(hiddenNote, style: caption),
            ],
            const SizedBox(height: Space.sm),
            Text([votes, ?timing].join(' · '), style: caption),
            Wrap(
              spacing: Space.xs,
              children: [
                if (poll.canChangeVote && !_changing)
                  TextButton(
                    onPressed: () => setState(() {
                      _changing = true;
                      _selection
                        ..clear()
                        ..addAll(poll.myChoices);
                    }),
                    child: const Text('Change vote'),
                  ),
                if (_changing)
                  TextButton(
                    onPressed: () => setState(() => _changing = false),
                    child: const Text('Keep my vote'),
                  ),
                if (poll.showsVoters)
                  TextButton(
                    onPressed: () => _showVoters(context, poll),
                    child: const Text('See who voted'),
                  ),
                if (poll.canClose)
                  TextButton(
                    onPressed: _close,
                    child: const Text('Close poll'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _votingRows(PollView poll) {
    final colors = Theme.of(context).colorScheme;
    if (!poll.multipleChoice) {
      return [
        for (final option in poll.options)
          MergeSemantics(
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              checked: option.chosen,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  option.chosen
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: option.chosen ? colors.primary : null,
                ),
                title: Text(option.label),
                onTap: () => _vote({option.id}),
              ),
            ),
          ),
      ];
    }
    return [
      for (final option in poll.options)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _selection.contains(option.id),
          title: Text(option.label),
          onChanged: (checked) => setState(
            () => checked == true
                ? _selection.add(option.id)
                : _selection.remove(option.id),
          ),
        ),
      const SizedBox(height: Space.xs),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton(
          onPressed: _selection.isEmpty ? null : () => _vote({..._selection}),
          child: const Text('Submit vote'),
        ),
      ),
    ];
  }
}

/// An option while results are hidden; the viewer's choice is ticked.
class _PlainOption extends StatelessWidget {
  const _PlainOption({required this.option});
  final PollOptionResult option;
  @override
  Widget build(BuildContext context) => Semantics(
    label: option.chosen ? '${option.label}, your choice' : option.label,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Icon(
            option.chosen ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
            color: option.chosen
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(option.label)),
        ],
      ),
    ),
  );
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.option});
  final PollOptionResult option;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = option.count ?? 0;
    final percent = option.percent ?? 0;
    final words =
        '${option.label}: $count ${count == 1 ? 'vote' : 'votes'}, '
        '$percent percent${option.chosen ? ', your choice' : ''}';
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (option.chosen) ...[
                  Icon(Icons.check_circle, size: 20, color: colors.primary),
                  const SizedBox(width: Space.xs),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: option.chosen
                        ? theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text('$percent% · $count', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: Space.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(CircleRadius.pill),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: Space.sm,
                color: option.chosen ? colors.primary : colors.secondary,
                backgroundColor: CircleAccents.of(context).recessed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showVoters(BuildContext context, PollView poll) =>
    showModalBottomSheet<void>(
      context: context,
      // Above the shell's navigation bar, so nothing is hidden.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Who voted',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final option in poll.options) ...[
              CircleSectionTitle('${option.label} (${option.count ?? 0})'),
              if (option.voters.isEmpty)
                Text(
                  'No votes yet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final name in option.voters)
                CircleRow(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleInitialAvatar(
                      name: name,
                      size: CircleAvatarSize.small,
                    ),
                    title: Text(name),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
