import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design.dart';
import '../core/circle_components.dart';
import '../features/groups/presentation/group_visuals.dart';
import '../features/groups/presentation/circle_groups.dart';
import 'workspace_providers.dart';
import 'workspace_view.dart';
import 'session.dart';

class CircleChats extends StatelessWidget {
  const CircleChats({super.key, this.groupId});
  final String? groupId;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.groups
          .where((group) => group.id == groupId)
          .firstOrNull;
      if (groupId != null) {
        return ReadingPane(
          child: ListView(
            padding: const EdgeInsets.all(Space.section),
            children: [
              CircleEmpty(
                title: group?.name ?? 'This conversation is private',
                message: group == null
                    ? 'You need membership in this exact group.'
                    : 'Chat design preview. No messages are sent or received yet. Messaging is coming later.',
              ),
            ],
          ),
        );
      }
      return ReadingPane(
        child: ListView(
          padding: const EdgeInsets.all(Space.section),
          children: [
            const CircleHeading(
              title: 'Pick up where\nyou left off.',
              subtitle: 'A conversation for each of your circles.',
            ),
            const Text(
              'LOCAL PREVIEW · Messaging and requests are coming later.',
            ),
            const SizedBox(height: Space.section),
            if (workspace.groups.isEmpty)
              const CircleEmpty(
                title: 'Your conversations start with your people',
                message:
                    'Create or join a group first. There is no stranger search or contact upload.',
              ),
            for (final group in workspace.groups)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(Space.lg),
                  leading: CircleAvatar(
                    child: Icon(circleTypeIcon(group.type)),
                  ),
                  title: Text(group.name),
                  subtitle: const Text('Group conversation · Preview only'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/chats/g/${group.id}'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class CircleEvents extends StatelessWidget {
  const CircleEvents({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) => ReadingPane(
      child: ListView(
        padding: const EdgeInsets.all(Space.section),
        children: [
          const CircleHeading(
            title: 'Make time\nfor each other.',
            subtitle:
                'Small plans. Good company. Something to look forward to.',
          ),
          if (workspace.events.isEmpty)
            const CircleEmpty(
              title: 'Your next get-together starts here',
              message:
                  'Events will appear from your groups. Creation, guest counts and calendar views are coming later.',
            ),
          for (final event in workspace.events)
            CircleEventCard(
              event: event,
              group: workspace.groups.firstWhere(
                (group) => group.id == event.groupId,
              ),
            ),
        ],
      ),
    ),
  );
}

class CircleYou extends ConsumerWidget {
  const CircleYou({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) => ReadingPane(
      child: ListView(
        padding: const EdgeInsets.all(Space.section),
        children: [
          const CircleHeading(
            title: 'A little space\nthat’s yours.',
            subtitle: 'Your circles. Your preferences. Your peace of mind.',
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text('You · Fictional preview'),
            subtitle: Text('No real account or phone number is saved.'),
          ),
          const SizedBox(height: Space.section),
          DropdownButtonFormField<ThemeMode>(
            initialValue: ref.watch(themeProvider),
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Use device setting'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (mode) {
              if (mode != null) ref.read(themeProvider.notifier).change(mode);
            },
          ),
          const SizedBox(height: Space.section),
          Text('Saved Memories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.lg),
          if (!workspace.memories.any((memory) => memory.saved))
            const Text('Save a Memory to keep it close.'),
          for (final memory in workspace.memories.where(
            (memory) => memory.saved,
          ))
            Card(
              child: ListTile(
                title: Text(
                  memory.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/memory/${memory.id}'),
              ),
            ),
          const SizedBox(height: Space.section),
          const CircleEmpty(
            title: 'Quiet by design',
            message:
                'No notifications, contact uploads or real accounts are used in this preview. All changes disappear when you end the session.',
          ),
          OutlinedButton(
            onPressed: () =>
                ref.read(circlePreviewSessionProvider.notifier).leave(),
            child: const Text('End preview and clear local changes'),
          ),
        ],
      ),
    ),
  );
}
