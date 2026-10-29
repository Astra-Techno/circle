import '../../groups/presentation/group_photos.dart';
import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../memories/presentation/scoped_memory_list.dart';
import '../application/search_providers.dart';

/// I2: one field; results grouped by kind, only from your own circles.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _set(String value) {
    _field.text = value;
    setState(() => _query = value);
  }

  void _open(String location) {
    ref.read(recentSearchesProvider.notifier).remember(_query);
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corpus = ref.watch(searchCorpusProvider);
    final recent = ref.watch(recentSearchesProvider);
    final ready = SearchRules.ready(_query);
    final server = ref.watch(serverAccountProvider) != null;
    final results = ready && corpus.hasValue
        ? SearchRules.search(_query, corpus.requireValue)
        : null;
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          TextField(
            key: const ValueKey('search-field'),
            controller: _field,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (value) =>
                ref.read(recentSearchesProvider.notifier).remember(value),
            decoration: InputDecoration(
              hintText: 'Search your circles',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => _set(''),
                    ),
            ),
          ),
          const SizedBox(height: Space.sm),
          const CircleNote(
            'Searches your groups, their members and all Memories you can access.',
          ),
          if (!ready) ...[
            Text(
              _query.trim().isEmpty
                  ? (server
                        ? 'Find groups, people and Memories in your circles.'
                        : 'Find groups, people, Memories, events and messages you can already see.')
                  : 'Type at least ${SearchRules.minLength} characters.',
              style: theme.textTheme.bodySmall,
            ),
            if (recent.isNotEmpty) ...[
              CircleSectionTitle(
                'Recent searches',
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
              ),
              for (final item in recent)
                CircleRow(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(item),
                    onTap: () => _set(item),
                  ),
                ),
            ],
          ] else if (results == null)
            const CircleSkeleton(count: 3, label: 'Searching')
          else if (results.isEmpty && !server)
            CircleEmpty(
              title: 'No results',
              message:
                  'Nothing in your circles matches “${_query.trim()}”. Search '
                  'only looks inside groups you’re in.',
            )
          else
            ..._results(results, includeMemories: !server),
          if (ready && server) ...[
            const CircleSectionTitle('Memories'),
            ScopedMemoryList(
              query: MemoryQuery(text: _query.trim()),
              empty: const CircleEmpty(
                title: 'No matching Memories',
                message: 'Try another word from the Memory or its place.',
              ),
              itemBuilder: (_, memory) => CircleRow(
                child: ListTile(
                  leading: PersonAvatar(
                    person: memory.authorId,
                    name: memory.author,
                  ),
                  title: Text(
                    memory.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(memory.author),
                  onTap: () => _open('/home/memory/${memory.id}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _results(SearchResults results, {bool includeMemories = true}) {
    final workspace = ref.read(searchCorpusProvider).requireValue.workspace;
    Widget row({
      required Widget leading,
      required String title,
      String? subtitle,
      required String location,
    }) => CircleRow(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: leading,
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => _open(location),
      ),
    );
    String groupName(String id) => workspace.group(id)?.name ?? '';
    return [
      if (results.groups.isNotEmpty) ...[
        CircleSectionTitle('Groups (${results.groups.length})'),
        for (final hit in results.groups)
          row(
            leading: GroupAvatar(groupId: hit.id, type: hit.type),
            title: hit.name,
            subtitle: [
              '${hit.memberCount} members',
              if (hit.where.isNotEmpty) hit.where,
              if (!hit.member) 'You can ask to join',
            ].join(' · '),
            location: hit.member
                ? '/groups/g/${hit.id}'
                : '/groups/g/${workspace.discoverable.firstWhere((p) => p.id == hit.id).parentId}',
          ),
      ],
      if (results.people.isNotEmpty) ...[
        CircleSectionTitle('People (${results.people.length})'),
        for (final hit in results.people)
          row(
            leading: PersonAvatar(person: hit.id, name: hit.name),
            title: hit.name,
            subtitle: 'In ${hit.groups.join(', ')}',
            location: '/people/${hit.id}',
          ),
      ],
      if (includeMemories && results.memories.isNotEmpty) ...[
        CircleSectionTitle('Memories (${results.memories.length})'),
        for (final memory in results.memories)
          row(
            leading: PersonAvatar(
              person: memory.authorId,
              name: memory.author,
              tone: CircleTone.neutral,
            ),
            title: memory.summary,
            subtitle: '${memory.author} · ${groupName(memory.groupId)}',
            location: '/home/memory/${memory.id}',
          ),
      ],
      if (results.events.isNotEmpty) ...[
        CircleSectionTitle('Events (${results.events.length})'),
        for (final event in results.events)
          row(
            leading: const CircleInitialAvatar(
              icon: Icons.event_outlined,
              tone: CircleTone.neutral,
            ),
            title: event.title,
            subtitle: groupName(event.groupId),
            location: '/events/e/${event.id}',
          ),
      ],
      if (results.messages.isNotEmpty) ...[
        CircleSectionTitle('Messages (${results.messages.length})'),
        for (final message in results.messages)
          row(
            leading: const CircleInitialAvatar(
              icon: Icons.chat_bubble_outline,
              tone: CircleTone.neutral,
            ),
            title: message.text,
            subtitle: '${message.authorName} · ${message.conversationTitle}',
            location: '/chats/c/${message.conversationId}',
          ),
      ],
    ];
  }
}

/// The shell's search button.
class SearchButton extends StatelessWidget {
  const SearchButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Search',
    onPressed: () => context.push('/search'),
    icon: const Icon(Icons.search),
  );
}
