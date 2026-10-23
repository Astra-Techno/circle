import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/workspace_providers.dart';
import '../../../app/workspace_view.dart';
import '../../../core/design.dart';
import '../../../core/circle_components.dart';
import '../../groups/domain/circle_repository.dart';
import '../../groups/presentation/group_visuals.dart';
import '../domain/circle_memory.dart';

class CircleHome extends ConsumerStatefulWidget {
  const CircleHome({super.key});
  @override
  ConsumerState<CircleHome> createState() => _CircleHomeState();
}

class _CircleHomeState extends ConsumerState<CircleHome> {
  String? _groupId;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final memories = workspace.memories
          .where((memory) => _groupId == null || memory.groupId == _groupId)
          .toList();
      return ReadingPane(
        child: ListView.builder(
          key: const PageStorageKey('circle-home'),
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.hero * 3,
          ),
          itemCount: memories.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleHeading(
                    eyebrow: 'YOUR PRIVATE WORLD',
                    title: 'Life is better\nin good company.',
                    subtitle: 'Little moments, shared with your people.',
                  ),
                  if (workspace.groups.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Space.sm,
                            ),
                            child: ChoiceChip(
                              label: const Text('All circles'),
                              selected: _groupId == null,
                              onSelected: (_) =>
                                  setState(() => _groupId = null),
                            ),
                          ),
                          for (final group in workspace.groups)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: Space.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(group.name),
                                selected: _groupId == group.id,
                                onSelected: (_) =>
                                    setState(() => _groupId = group.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.section),
                    Text(
                      'Memories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  if (memories.isEmpty)
                    CircleEmpty(
                      title: workspace.groups.isEmpty
                          ? 'A little space for your people'
                          : 'Every circle starts with a story',
                      message: workspace.groups.isEmpty
                          ? 'Create a group for family, friends or your team. Nothing is shared until you choose a group.'
                          : 'Share the first Memory with this group.',
                      action: FilledButton.icon(
                        onPressed: () => context.push(
                          workspace.groups.isEmpty ? '/groups/new' : '/compose',
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          workspace.groups.isEmpty
                              ? 'Create a group'
                              : 'Share a Memory',
                        ),
                      ),
                    ),
                ],
              );
            }
            final memory = memories[index - 1];
            final group = workspace.groups.firstWhere(
              (group) => group.id == memory.groupId,
            );
            return CircleMemoryCard(
              key: ValueKey(memory.id),
              memory: memory,
              group: group,
            );
          },
        ),
      );
    },
  );
}

class CircleMemoryCard extends ConsumerWidget {
  const CircleMemoryCard({
    super.key,
    required this.memory,
    required this.group,
    this.detail = false,
  });
  final CircleMemory memory;
  final CircleGroup group;
  final bool detail;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(memory.author.characters.first)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.author,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Shared with ${group.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: memory.saved ? 'Unsave Memory' : 'Save Memory',
                icon: Icon(
                  memory.saved ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () =>
                    ref.read(circleWorkspaceProvider.notifier).save(memory.id),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(memory.text, style: Theme.of(context).textTheme.bodyLarge),
          if (memory.illustration != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.lg),
              child: CircleCover(
                compact: true,
                title: memory.illustration!,
                icon: circleTypeIcon(group.type),
              ),
            ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(circleWorkspaceProvider.notifier).love(memory.id),
                icon: Icon(
                  memory.loved ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(memory.loved ? 'Loved' : 'Love'),
              ),
              if (!detail)
                TextButton.icon(
                  onPressed: () => context.push('/home/memory/${memory.id}'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    '${memory.comments.length} ${memory.comments.length == 1 ? 'comment' : 'comments'}',
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class CircleMemoryDetail extends ConsumerWidget {
  const CircleMemoryDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final memory = workspace.memories
          .where((memory) => memory.id == id)
          .firstOrNull;
      if (memory == null) {
        return const ReadingPane(
          child: CircleEmpty(
            title: 'Memory unavailable',
            message: 'This Memory is not shared with your current groups.',
          ),
        );
      }
      final group = workspace.groups.firstWhere(
        (group) => group.id == memory.groupId,
      );
      return ReadingPane(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            CircleMemoryCard(memory: memory, group: group, detail: true),
            Text(
              'Keep the conversation going',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.lg),
            for (final comment in memory.comments)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Text(comment),
                ),
              ),
            CircleTextEditor(
              label: 'Add a comment',
              button: 'Send comment',
              submit: (text) => ref
                  .read(circleWorkspaceProvider.notifier)
                  .comment(memory.id, text),
            ),
          ],
        ),
      );
    },
  );
}

class CircleTextEditor extends StatefulWidget {
  const CircleTextEditor({
    super.key,
    required this.label,
    required this.button,
    required this.submit,
  });
  final String label, button;
  final Future<void> Function(String) submit;
  @override
  State<CircleTextEditor> createState() => _CircleTextEditorState();
}

class _CircleTextEditorState extends State<CircleTextEditor> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_text.text);
      if (mounted) {
        _text.clear();
        FocusScope.of(context).unfocus();
      }
    } on CircleFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _text,
        minLines: 3,
        maxLines: 8,
        maxLength: 2000,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      const SizedBox(height: Space.md),
      FilledButton(
        onPressed: _busy ? null : _send,
        child: Text(_busy ? 'Saving locally…' : widget.button),
      ),
    ],
  );
}

class CircleCompose extends ConsumerStatefulWidget {
  const CircleCompose({super.key});
  @override
  ConsumerState<CircleCompose> createState() => _CircleComposeState();
}

class _CircleComposeState extends ConsumerState<CircleCompose> {
  String? _groupId;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      if (workspace.groups.isEmpty) {
        return ReadingPane(
          child: CircleEmpty(
            title: 'Choose your people first',
            message: 'Create a group before sharing a Memory.',
            action: FilledButton(
              onPressed: () => context.go('/groups/new'),
              child: const Text('Create a group'),
            ),
          ),
        );
      }
      final chosen = _groupId ?? workspace.groups.first.id;
      return ReadingPane(
        child: ListView(
          padding: const EdgeInsets.all(Space.section),
          children: [
            const CircleHeading(
              title: 'Something worth\nsharing.',
              subtitle: 'A small moment can mean a lot to your circle.',
            ),
            DropdownButtonFormField<String>(
              initialValue: chosen,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Share with'),
              items: [
                for (final group in workspace.groups)
                  DropdownMenuItem(value: group.id, child: Text(group.name)),
              ],
              onChanged: (id) => setState(() => _groupId = id),
            ),
            const SizedBox(height: Space.section),
            CircleTextEditor(
              label: 'Your Memory',
              button: 'Share Memory',
              submit: (text) async {
                await ref
                    .read(circleWorkspaceProvider.notifier)
                    .createMemory(chosen, text);
                if (context.mounted) context.go('/home');
              },
            ),
            const SizedBox(height: Space.lg),
            const Text(
              'Local text preview. Photo uploads and tagging arrive in a later phase.',
            ),
          ],
        ),
      );
    },
  );
}
