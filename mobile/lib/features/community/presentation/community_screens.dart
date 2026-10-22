import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/session.dart';
import '../../../core/design.dart';
import '../../feed/data/mock_feed_repository.dart';
import '../../feed/presentation/feed_controller.dart';
import '../data/mock_community_repository.dart';
import '../domain/entry.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => MockCommunityRepository(),
);
final rsvpProvider = NotifierProvider<RsvpController, Set<String>>(
  RsvpController.new,
);

class RsvpController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void toggle(String id) => state = Set.unmodifiable(
    state.contains(id) ? (Set<String>.of(state)..remove(id)) : {...state, id},
  );
}

IconData entryIcon(EntryKind kind) => switch (kind) {
  EntryKind.group => Icons.groups_outlined,
  EntryKind.album => Icons.photo_album_outlined,
  EntryKind.friend => Icons.person_outline,
  EntryKind.event => Icons.event_outlined,
};
String entryTitle(EntryKind kind) => switch (kind) {
  EntryKind.group => 'Smaller circles',
  EntryKind.album => 'Our shared archive',
  EntryKind.friend => 'Familiar faces',
  EntryKind.event => 'Meet again',
};

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.kind, this.id});
  final EntryKind kind;
  final String? id;
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityState();
}

class _CommunityState extends ConsumerState<CommunityScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final entries = ref
        .watch(communityRepositoryProvider)
        .entries(demoCommunity, widget.kind);
    final entry = entries.where((entry) => entry.id == widget.id).firstOrNull;
    if (widget.id != null && entry == null) {
      return const Notice(
        title: 'Unavailable',
        message: 'This item is not shared with your demo membership.',
      );
    }
    return ReadingPane(
      child: ListView(
        padding: const EdgeInsets.all(Space.section),
        children: [
          Text(
            entry?.title ?? entryTitle(widget.kind),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: Space.md),
          Text(
            entry?.subtitle ??
                'Marigold College · Class of 2006 · Fictional demo',
          ),
          const SizedBox(height: Space.section),
          if (entry != null) ...[
            ArchiveArt(label: entry.title, icon: entryIcon(entry.kind)),
            const SizedBox(height: Space.section),
            Text(entry.description),
            if (entry.kind == EntryKind.event) ...[
              const SizedBox(height: Space.section),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(rsvpProvider.notifier).toggle(entry.id),
                icon: Icon(
                  ref.watch(rsvpProvider).contains(entry.id)
                      ? Icons.check
                      : Icons.event_available,
                ),
                label: Text(
                  ref.watch(rsvpProvider).contains(entry.id)
                      ? 'Going · Undo RSVP'
                      : 'Count me in',
                ),
              ),
            ],
          ] else ...[
            if (widget.kind == EntryKind.friend) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Find a friend',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase().trim()),
              ),
              const SizedBox(height: Space.section),
            ],
            if (!entries.any(
              (item) => '${item.title} ${item.subtitle}'.toLowerCase().contains(
                _query,
              ),
            ))
              const Notice(
                title: 'No familiar faces found',
                message: 'Try another name or city.',
              ),
            for (final item in entries.where(
              (item) => '${item.title} ${item.subtitle}'.toLowerCase().contains(
                _query,
              ),
            ))
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(Space.lg),
                  leading: Icon(entryIcon(item.kind)),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/${item.kind.name}/${item.id}'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ReadingPane(
    child: ListView(
      padding: const EdgeInsets.all(Space.section),
      children: [
        const CircleAvatar(
          radius: 36,
          child: Icon(Icons.person_outline, size: 36),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'Your demo space',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: Space.md),
        const Text(
          'Marigold College · Class of 2006\nAll people and stories here are fictional.',
        ),
        const SizedBox(height: Space.section),
        DropdownButtonFormField<ThemeMode>(
          initialValue: ref.watch(themeProvider),
          decoration: const InputDecoration(labelText: 'Appearance'),
          items: ThemeMode.values
              .map(
                (mode) => DropdownMenuItem(value: mode, child: Text(mode.name)),
              )
              .toList(),
          onChanged: (mode) {
            if (mode != null) ref.read(themeProvider.notifier).change(mode);
          },
        ),
        const SizedBox(height: Space.section),
        Text('Saved memories', style: Theme.of(context).textTheme.titleLarge),
        ...ref
            .watch(feedProvider)
            .when(
              data: (posts) => [
                if (!posts.any((post) => post.saved))
                  const Padding(
                    padding: EdgeInsets.all(Space.lg),
                    child: Text(
                      'Save a memory from your feed to revisit it here.',
                    ),
                  ),
                for (final post in posts.where((post) => post.saved))
                  ListTile(
                    title: Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/post/${post.id}'),
                  ),
              ],
              loading: () => [const LinearProgressIndicator()],
              error: (_, _) => [
                const Text('Saved memories are temporarily unavailable.'),
              ],
            ),
        const SizedBox(height: Space.section),
        const Text(
          'Prototype privacy\nNothing is uploaded. Posts, comments, saves and RSVPs are kept in memory. Ending the demo clears them. Production reporting, export and deletion are not yet available.',
        ),
        const SizedBox(height: Space.section),
        OutlinedButton(
          onPressed: () {
            ref.read(feedRepositoryProvider).reset();
            ref.invalidate(feedProvider);
            ref.invalidate(rsvpProvider);
            ref.read(sessionProvider.notifier).leave();
          },
          child: const Text('End demo and clear session'),
        ),
      ],
    ),
  );
}
