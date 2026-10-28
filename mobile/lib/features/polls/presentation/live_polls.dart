import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/live_polls.dart';

void refreshPolls(WidgetRef ref) {
  ref.invalidate(livePollProvider);
  ref.invalidate(livePollsProvider);
  ref.invalidate(livePollVotersProvider);
}

class LivePollScreen extends ConsumerStatefulWidget {
  const LivePollScreen({super.key, this.id, this.group, this.event});
  final String? id, group, event;
  @override
  ConsumerState<LivePollScreen> createState() => _PollState();
}

class _PollState extends ConsumerState<LivePollScreen> {
  int _offset = 0;
  bool _busy = false;
  Set<int>? _chosen;
  String? _choiceScope;
  Future<void> _run(Future<Object?> Function(LivePollApi) action) async {
    final api = ref.read(livePollApiProvider);
    setState(() => _busy = true);
    await runCalmly(context, () => action(api));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _chosen = null;
    });
    refreshPolls(ref);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final load = id == null
        ? ref.watch(
            livePollsProvider((
              group: widget.group,
              event: widget.event,
              offset: _offset,
            )),
          )
        : ref.watch(livePollProvider(id));
    return ReadingPane(
      child: load.when(
        loading: () => const CircleSkeletonPage(
          shape: CircleSkeletonShape.cards,
          count: 3,
          label: 'Loading polls',
        ),
        error: (_, _) => CircleEmpty(
          title: 'Polls couldn’t load',
          message: 'Check your connection and group access.',
          action: TextButton(
            onPressed: () => refreshPolls(ref),
            child: const Text('Try again'),
          ),
        ),
        data: (p) {
          if (id == null) {
            final items = ApiJson.list(p['items']).map(ApiJson.map);
            return ListView(
              padding: CircleInsets.form,
              children: [
                const CircleHeading(
                  title: 'Polls',
                  subtitle: 'Decide together, in your circle.',
                ),
                FilledButton.icon(
                  onPressed: () => context.push(
                    Uri(
                      path: '/polls/new',
                      queryParameters: {
                        'group': ?widget.group,
                        'event': ?widget.event,
                      },
                    ).toString(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a poll'),
                ),
                TextButton.icon(
                  onPressed: () => refreshPolls(ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                if (items.isEmpty)
                  const CircleEmpty(
                    title: 'Ask your circle',
                    message: 'Start with a question and two options.',
                  ),
                for (final poll in items)
                  Card(
                    child: ListTile(
                      title: Text(poll['question'] as String),
                      subtitle: Text(
                        '${poll['group_name'] ?? 'Circle'} · ${poll['closed'] == true ? 'Closed' : 'Open'} · ${poll['anonymous'] == true ? 'Anonymous' : 'Named'} votes',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/polls/p/${poll['id']}'),
                    ),
                  ),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    if (_offset > 0)
                      TextButton(
                        onPressed: () => setState(() => _offset -= 30),
                        child: const Text('Previous'),
                      ),
                    if (p['has_more'] == true)
                      TextButton(
                        onPressed: () => setState(() => _offset += 30),
                        child: const Text('Next'),
                      ),
                  ],
                ),
              ],
            );
          }
          final api = ref.watch(livePollApiProvider),
              scope = '$id:${api.scope.account}:${api.scope.session}';
          if (_choiceScope != scope) {
            _choiceScope = scope;
            _chosen = null;
          }
          final mine = ApiJson.list(p['my_votes']).cast<int>().toSet(),
              chosen = _chosen ?? mine,
              closed = p['closed'] == true,
              multiple = p['poll_type'] == 'multiple',
              results = p['results_available'] == true;
          final locked =
                  closed || (p['allow_change_vote'] != true && mine.isNotEmpty),
              options = ApiJson.list(p['options']).map(ApiJson.map).toList();
          final total = p['voter_count'] as int? ?? 0;
          return ListView(
            padding: CircleInsets.form,
            children: [
              CircleHeading(
                title: p['question'] as String,
                subtitle:
                    '${closed ? 'Closed' : 'Choose ${multiple ? 'one or more options' : 'one option'}'} · ${p['anonymous'] == true ? 'Anonymous' : 'Named'} votes',
              ),
              Text(
                'Shared with ${p['group_name'] ?? 'this circle'}${p['event_id'] == null ? '' : ' · event poll'}',
              ),
              if (p['closes_at'] case final String end)
                Text('Closes ${DateTime.parse(end).toLocal()}'),
              TextButton.icon(
                onPressed: () => refreshPolls(ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh poll'),
              ),
              for (final option in options)
                Card(
                  margin: const EdgeInsets.only(bottom: Space.md),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: chosen.contains(option['id']),
                        onChanged: locked || _busy
                            ? null
                            : (value) => setState(() {
                                _chosen = multiple ? {...chosen} : <int>{};
                                if (value == true) {
                                  _chosen!.add(option['id'] as int);
                                } else {
                                  _chosen!.remove(option['id']);
                                }
                              }),
                        title: Text(option['label'] as String),
                        subtitle: results
                            ? Text(
                                '${option['votes']} vote(s) · ${total == 0 ? 0 : ((option['votes'] as int) * 100 / total).round()}%',
                              )
                            : null,
                      ),
                      if (results)
                        Padding(
                          padding: const EdgeInsets.all(Space.md),
                          child: LinearProgressIndicator(
                            value: total == 0
                                ? 0
                                : (option['votes'] as int) / total,
                          ),
                        ),
                    ],
                  ),
                ),
              if (results)
                Text(
                  '$total voter(s)${multiple ? ' · people may choose multiple options' : ''}',
                )
              else
                Text(
                  p['results_visibility'] == 'after_closing'
                      ? 'Results appear when this poll closes.'
                      : 'Vote to see the results.',
                ),
              if (!closed && locked)
                const Text(
                  'Your vote is saved. This poll does not allow vote changes.',
                ),
              if (!locked)
                FilledButton.icon(
                  onPressed: _busy || (chosen.isEmpty && mine.isEmpty)
                      ? null
                      : () => _run(
                          (api) => api.vote(id, chosen.toList()..sort()),
                        ),
                  icon: const Icon(Icons.how_to_vote_outlined),
                  label: Text(
                    _busy
                        ? 'Saving…'
                        : mine.isEmpty
                        ? 'Submit vote'
                        : chosen.isEmpty
                        ? 'Remove vote'
                        : 'Save vote',
                  ),
                ),
              if (!closed &&
                  p['allow_add_options'] == true &&
                  options.length < 12)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final api = ref.read(livePollApiProvider);
                          final label = await showDialog<String>(
                            context: context,
                            builder: (_) => const _OptionDialog(),
                          );
                          if (label != null && mounted) {
                            await _run((_) => api.option(id, label));
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Add an option'),
                ),
              if (results && p['anonymous'] != true)
                TextButton(
                  onPressed: () => context.push('/polls/p/$id/voters'),
                  child: const Text('See who voted'),
                ),
              if (!closed && p['can_manage'] == true)
                TextButton(
                  onPressed: _busy ? null : () => _run((api) => api.close(id)),
                  child: const Text('Close poll'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LivePollForm extends ConsumerStatefulWidget {
  const LivePollForm({super.key, this.group, this.event});
  final String? group, event;
  @override
  ConsumerState<LivePollForm> createState() => _FormState();
}

class _FormState extends ConsumerState<LivePollForm> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  String? _group, _key, _signature;
  bool _busy = false,
      _multiple = false,
      _anonymous = false,
      _add = false,
      _change = true;
  String _visibility = 'always';
  DateTime? _end;
  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(circleWorkspaceProvider).value,
        viewer = ref.watch(serverAccountProvider)?.id;
    final groups =
        workspace?.groups
            .where((g) => viewer != null && g.isMember(viewer))
            .toList() ??
        [];
    final selected = groups.any((g) => g.id == _group) ? _group : null;
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          const CircleHeading(
            title: 'Create a poll',
            subtitle: 'A question, a few choices, your circle.',
          ),
          DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Share with'),
            isExpanded: true,
            items: [
              for (final g in groups)
                DropdownMenuItem(value: g.id, child: Text(g.name)),
            ],
            onChanged: _busy || (widget.event != null && widget.group != null)
                ? null
                : (v) => setState(() => _group = v),
          ),
          TextField(
            controller: _question,
            enabled: !_busy,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Question'),
          ),
          for (final (i, c) in _options.indexed)
            TextField(
              controller: c,
              enabled: !_busy,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Option ${i + 1}',
                suffixIcon: _options.length <= 2
                    ? null
                    : IconButton(
                        tooltip: 'Remove option ${i + 1}',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _options.removeAt(i).dispose();
                              }),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          if (_options.length < 12)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _options.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Add option'),
            ),
          ExpansionTile(
            title: const Text('More options'),
            children: [
              SwitchListTile(
                title: const Text('Multiple choices'),
                value: _multiple,
                onChanged: _busy ? null : (v) => setState(() => _multiple = v),
              ),
              SwitchListTile(
                title: const Text('Anonymous votes'),
                subtitle: const Text(
                  'Nobody in the app can see who chose each option.',
                ),
                value: _anonymous,
                onChanged: _busy ? null : (v) => setState(() => _anonymous = v),
              ),
              SwitchListTile(
                title: const Text('Members can add options'),
                value: _add,
                onChanged: _busy ? null : (v) => setState(() => _add = v),
              ),
              SwitchListTile(
                title: const Text('Allow changing votes'),
                value: _change,
                onChanged: _busy ? null : (v) => setState(() => _change = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Show results'),
                items: const [
                  DropdownMenuItem(value: 'always', child: Text('Always')),
                  DropdownMenuItem(
                    value: 'after_voting',
                    child: Text('After voting'),
                  ),
                  DropdownMenuItem(
                    value: 'after_closing',
                    child: Text('After closing'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _visibility = v!),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2037, 12, 31),
                        );
                        if (d == null || !context.mounted) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 18, minute: 0),
                        );
                        if (t != null && mounted) {
                          setState(
                            () => _end = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            ),
                          );
                        }
                      },
                child: Text(
                  _end == null
                      ? 'Set an end time (optional)'
                      : 'Ends $_end · device time',
                ),
              ),
              if (_end != null)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _end = null),
                  child: const Text('Remove end time'),
                ),
            ],
          ),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final api = ref.read(livePollApiProvider), g = selected;
                    if (g == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Choose a group first.')),
                      );
                      return;
                    }
                    final eventId = widget.event == null
                        ? null
                        : int.tryParse(widget.event!);
                    if (widget.event != null &&
                        (eventId == null || eventId < 1)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This event link is invalid. Open the event again.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_end != null && !_end!.isAfter(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Choose a future end time.'),
                        ),
                      );
                      return;
                    }
                    final labels = _options.map((c) => c.text.trim()).toList();
                    if (_question.text.trim().isEmpty ||
                        labels.any((v) => v.isEmpty) ||
                        labels.map((v) => v.toLowerCase()).toSet().length !=
                            labels.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Add a question and at least two different, non-empty options.',
                          ),
                        ),
                      );
                      return;
                    }
                    final body = <String, Object?>{
                      'question': _question.text.trim(),
                      'options': _options.map((c) => c.text.trim()).toList(),
                      'poll_type': _multiple ? 'multiple' : 'single',
                      'anonymous': _anonymous,
                      'allow_add_options': _add,
                      'allow_change_vote': _change,
                      'results_visibility': _visibility,
                      'closes_at': _end?.toUtc().toIso8601String().replaceFirst(
                        '.000Z',
                        'Z',
                      ),
                      if (widget.event != null) 'event_id': eventId,
                    };
                    final signature = jsonEncode([g, body]);
                    if (signature != _signature) {
                      _signature = signature;
                      _key =
                          'circle-poll-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
                    }
                    setState(() => _busy = true);
                    final result = await runCalmly(
                      context,
                      () => api.create(g, {...body, 'client_id': _key}),
                    );
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (result != null) {
                      api.scope.check();
                      refreshPolls(ref);
                      if (context.mounted) {
                        context.go('/polls/p/${result['id']}');
                      }
                    }
                  },
            icon: const Icon(Icons.poll_outlined),
            label: Text(_busy ? 'Creating…' : 'Post poll'),
          ),
        ],
      ),
    );
  }
}

class _OptionDialog extends StatefulWidget {
  const _OptionDialog();
  @override
  State<_OptionDialog> createState() => _OptionState();
}

class _OptionState extends State<_OptionDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add an option'),
    content: TextField(
      controller: _text,
      maxLength: 200,
      decoration: const InputDecoration(labelText: 'Option'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text.trim()),
        child: const Text('Add'),
      ),
    ],
  );
}

class LivePollVoters extends ConsumerStatefulWidget {
  const LivePollVoters({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LivePollVoters> createState() => _VotersState();
}

class _VotersState extends ConsumerState<LivePollVoters> {
  int _offset = 0;
  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ref
        .watch(livePollVotersProvider((id: widget.id, offset: _offset)))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const CircleEmpty(
            title: 'Voters are private',
            message: 'Check poll settings and current group access.',
          ),
          data: (data) => ListView(
            padding: CircleInsets.form,
            children: [
              const CircleHeading(
                title: 'Who voted',
                subtitle: 'Visible only to this circle.',
              ),
              for (final row in ApiJson.list(data['items']).map(ApiJson.map))
                ListTile(
                  title: Text(row['display_name'] as String),
                  subtitle: Text(row['label'] as String),
                ),
              Wrap(
                children: [
                  if (_offset > 0)
                    TextButton(
                      onPressed: () => setState(() => _offset -= 30),
                      child: const Text('Previous'),
                    ),
                  if (data['has_more'] == true)
                    TextButton(
                      onPressed: () => setState(() => _offset += 30),
                      child: const Text('Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
  );
}
