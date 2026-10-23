import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/workspace_providers.dart';
import '../../../app/workspace_view.dart';
import '../../../core/design.dart';
import '../../../core/circle_components.dart';
import '../../memories/presentation/circle_memories.dart';
import '../domain/circle_repository.dart';
import 'group_visuals.dart';

class CircleGroups extends StatefulWidget {
  const CircleGroups({super.key});
  @override
  State<CircleGroups> createState() => _CircleGroupsState();
}

class _CircleGroupsState extends State<CircleGroups> {
  String _query = '';
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final visible = workspace.groups
          .where((group) => group.name.toLowerCase().contains(_query))
          .toList();
      return ReadingPane(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.section,
            Space.section,
            Space.section,
            Space.hero * 3,
          ),
          children: [
            const CircleHeading(
              title: 'Your kind\nof company.',
              subtitle: 'Every circle has a place here.',
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Find one of your groups',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: Space.section),
            if (visible.isEmpty)
              CircleEmpty(
                title: workspace.groups.isEmpty
                    ? 'Start with someone you know'
                    : 'No groups found',
                message: workspace.groups.isEmpty
                    ? 'Create your first private group. Joining by link and inviting people are coming later.'
                    : 'Try a different group name.',
                action: workspace.groups.isEmpty
                    ? FilledButton(
                        onPressed: () => context.push('/groups/new'),
                        child: const Text('Create a group'),
                      )
                    : null,
              ),
            for (final group in visible)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: _query.isEmpty
                      ? ((group.depth - 1) * Space.sm).clamp(0, Space.hero)
                      : 0,
                ),
                child: CircleGroupTile(group: group),
              ),
          ],
        ),
      );
    },
  );
}

class CircleGroupTile extends StatelessWidget {
  const CircleGroupTile({super.key, required this.group});
  final CircleGroup group;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(Space.lg),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          circleTypeIcon(group.type),
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(group.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        '${group.roles.length} members · ${circleRoleLabel(group.roles[previewViewer]!)}${group.depth > 1 ? ' · Level ${group.depth}' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/groups/g/${group.id}'),
    ),
  );
}

class CircleGroupDetail extends StatefulWidget {
  const CircleGroupDetail({super.key, required this.id});
  final String id;
  @override
  State<CircleGroupDetail> createState() => _CircleGroupDetailState();
}

class _CircleGroupDetailState extends State<CircleGroupDetail> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.groups
          .where((group) => group.id == widget.id)
          .firstOrNull;
      if (group == null) {
        return const ReadingPane(
          child: CircleEmpty(
            title: 'This circle is private',
            message:
                'You need membership in this exact group to see what is shared here.',
          ),
        );
      }
      final ancestors = <CircleGroup>[group];
      var parentId = group.parentId;
      while (parentId != null && ancestors.length < 10) {
        final parent = workspace.groups
            .where((item) => item.id == parentId)
            .firstOrNull;
        if (parent == null) break;
        ancestors.insert(0, parent);
        parentId = parent.parentId;
      }
      final children = workspace.groups
          .where((item) => item.parentId == group.id)
          .toList();
      final memories = workspace.memories
          .where((memory) => memory.groupId == group.id)
          .toList();
      return ReadingPane(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Wrap(
              children: [
                for (final ancestor in ancestors)
                  TextButton(
                    onPressed: ancestor.id == group.id
                        ? null
                        : () => context.push('/groups/g/${ancestor.id}'),
                    child: Text(ancestor.name),
                  ),
              ],
            ),
            CircleCover(
              title: group.name,
              icon: circleTypeIcon(group.type),
              compact: true,
            ),
            const SizedBox(height: Space.lg),
            Text(
              '${group.roles.length} members · ${circleRoleLabel(group.roles[previewViewer]!)} · Private group',
            ),
            const SizedBox(height: Space.lg),
            DefaultTabController(
              length: 6,
              initialIndex: _tab,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (index) => setState(() => _tab = index),
                tabs: [
                  for (final label in const [
                    'Memories',
                    'Chat',
                    'Events',
                    'Albums',
                    'Subgroups',
                    'Members',
                  ])
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                        ),
                        child: Text(label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.section),
            if (_tab == 0) ...[
              if (memories.isEmpty)
                const CircleEmpty(
                  title: 'The first Memory is yours to make',
                  message: 'Share a little moment with this exact group.',
                ),
              for (final memory in memories)
                CircleMemoryCard(memory: memory, group: group),
            ],
            if (_tab == 1)
              CircleEmpty(
                title: 'A conversation for this circle',
                message:
                    'This is a local design preview. Group conversations and message delivery are coming later.',
                action: OutlinedButton(
                  onPressed: () => context.push('/chats/g/${group.id}'),
                  child: const Text('Open chat preview'),
                ),
              ),
            if (_tab == 2) ...[
              for (final event in workspace.events.where(
                (event) => event.groupId == group.id,
              ))
                CircleEventCard(event: event, group: group),
              if (!workspace.events.any((event) => event.groupId == group.id))
                const CircleEmpty(
                  title: 'Make time for each other',
                  message:
                      'Event creation and guest lists are coming later. No event is published from this screen.',
                ),
            ],
            if (_tab == 3)
              const CircleEmpty(
                title: 'A home for your shared photos',
                message:
                    'Private albums and photo uploads are coming later. No photos are uploaded in this preview.',
              ),
            if (_tab == 4) ...[
              for (final child in children) CircleGroupTile(group: child),
              if (children.isEmpty)
                const CircleEmpty(
                  title: 'A smaller circle, when you need one',
                  message:
                      'Subgroups have their own members. Access is never inherited.',
                ),
              FilledButton.icon(
                onPressed: () => context.push('/groups/new?parent=${group.id}'),
                icon: const Icon(Icons.add),
                label: const Text('Create subgroup'),
              ),
            ],
            if (_tab == 5) ...[
              for (final member in group.roles.entries)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      member.key == previewViewer
                          ? 'You'
                          : '${member.key[0].toUpperCase()}${member.key.substring(1)}',
                    ),
                    subtitle: Text(circleRoleLabel(member.value)),
                  ),
                ),
              const Text(
                'Fictional members only. Approval, invitations and role management are coming later.',
              ),
            ],
          ],
        ),
      );
    },
  );
}

class CircleCreateGroup extends ConsumerStatefulWidget {
  const CircleCreateGroup({super.key, this.parentId});
  final String? parentId;
  @override
  ConsumerState<CircleCreateGroup> createState() => _CircleCreateGroupState();
}

class _CircleCreateGroupState extends ConsumerState<CircleCreateGroup> {
  final _name = TextEditingController();
  CircleType _type = CircleType.friends;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(circleWorkspaceProvider.notifier)
          .createGroup(_name.text, _type, parentId: widget.parentId);
      if (mounted) context.go('/groups/g/${group.id}');
    } on CircleFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: const EdgeInsets.all(Space.section),
      children: [
        CircleHeading(
          title: widget.parentId == null
              ? 'Bring your\npeople together.'
              : 'Make a little\nroom within.',
          subtitle:
              'A private group, with you as its owner. Created only in this local session.',
        ),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: 'Group name',
            hintText: 'Something your people will recognise',
            errorText: _error,
            errorMaxLines: 4,
          ),
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Space.section),
        DropdownButtonFormField<CircleType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Kind of group'),
          items: [
            for (final type in CircleType.values)
              DropdownMenuItem(
                value: type,
                child: Text(
                  '${type.name[0].toUpperCase()}${type.name.substring(1)}',
                ),
              ),
          ],
          onChanged: (type) {
            if (type != null) setState(() => _type = type);
          },
        ),
        const SizedBox(height: Space.section),
        const Text(
          'Only you are added. Other people will need to accept an invitation. Sharing and approval settings are coming later.',
        ),
        const SizedBox(height: Space.section),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating locally…' : 'Create private group'),
        ),
      ],
    ),
  );
}

class CircleEventCard extends ConsumerWidget {
  const CircleEventCard({super.key, required this.event, required this.group});
  final CircleEvent event;
  final CircleGroup group;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.name, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Space.md),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          Text(event.when),
          const SizedBox(height: Space.sm),
          Text(event.where),
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final choice in Attendance.values)
                ChoiceChip(
                  label: Text(switch (choice) {
                    Attendance.going => 'Going',
                    Attendance.maybe => 'Maybe',
                    Attendance.notGoing => 'Not going',
                  }),
                  selected: event.attendance == choice,
                  onSelected: (_) => ref
                      .read(circleWorkspaceProvider.notifier)
                      .rsvp(event.id, choice),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          const Text(
            'Local RSVP preview · no invitations or reminders are sent.',
          ),
        ],
      ),
    ),
  );
}
