import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/home_filter.dart';
import 'memory_card.dart';

export 'memory_card.dart';
export 'memory_compose.dart';
export 'memory_detail.dart';
export 'memory_photos.dart';

class CircleHome extends ConsumerWidget {
  const CircleHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final selected = ref.watch(homeGroupFilterProvider);
      final groupId = workspace.groupsById.containsKey(selected)
          ? selected
          : null;
      final memories = workspace.memories
          .where((memory) => groupId == null || memory.groupId == groupId)
          .toList();
      final ordered = buildGroupTree(workspace.groups);
      void select(String? id) =>
          ref.read(homeGroupFilterProvider.notifier).select(id);
      final more = workspace.hasMoreMemories;
      return ReadingPane(
        child: RefreshIndicator(
          onRefresh: () => runCalmly(
            context,
            () => ref.read(circleWorkspaceProvider.notifier).refresh(),
          ),
          child: ListView.builder(
            key: const PageStorageKey('circle-home'),
            padding: CircleInsets.page,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: memories.length + 1 + (more ? 1 : 0),
            itemBuilder: (context, index) {
              // Built only when scrolled near the end: loads older Memories.
              if (index == memories.length + 1) {
                return const _LoadOlderMemories();
              }
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (workspace.groups.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _GroupChip(
                              label: 'All',
                              selected: groupId == null,
                              onTap: () => select(null),
                            ),
                            for (final entry in ordered)
                              _GroupChip(
                                label: entry.group.name,
                                selected: groupId == entry.group.id,
                                onTap: () => select(
                                  groupId == entry.group.id
                                      ? null
                                      : entry.group.id,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                    ],
                    if (memories.isEmpty)
                      CircleEmpty(
                        title: workspace.groups.isEmpty
                            ? 'A little space for your people'
                            : 'Every circle starts with a story',
                        message: workspace.groups.isEmpty
                            ? 'Create a group for family, friends or your team, or open an invite link. Nothing is shared until you choose a group.'
                            : 'Share the first Memory with this group.',
                        action: FilledButton.icon(
                          // Group creation lives in the Groups branch.
                          onPressed: () => workspace.groups.isEmpty
                              ? context.go('/groups/new')
                              : context.push(composeLocation(groupId)),
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
              final group = workspace.group(memory.groupId)!;
              return CircleMemoryCard(
                key: ValueKey(memory.id),
                memory: memory,
                group: group,
                audience: audiencePath(group, workspace.groupsById),
              );
            },
          ),
        ),
      );
    },
  );
}

/// The end of a paginated list: fetches the next page as soon as it comes
/// into view, with a calm Try again if that fails.
class _LoadOlderMemories extends ConsumerStatefulWidget {
  const _LoadOlderMemories();
  @override
  ConsumerState<_LoadOlderMemories> createState() => _LoadOlderState();
}

class _LoadOlderState extends ConsumerState<_LoadOlderMemories> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      await Future<void>.microtask(
        () => ref.read(circleWorkspaceProvider.notifier).loadMoreMemories(),
      );
    } on CircleFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.lg),
    child: Center(
      child: _error == null
          ? Semantics(
              label: 'Loading older Memories',
              child: const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
    ),
  );
}

/// Compose location with the audience in view, if any.
String composeLocation(String? groupId) => groupId == null
    ? '/compose'
    : Uri(path: '/compose', queryParameters: {'group': groupId}).toString();

/// "Just now", "5m ago", "2h ago", "Yesterday", then "12 Oct".
String memoryTimeLabel(DateTime createdAt, DateTime now) {
  final age = now.difference(createdAt);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';
  if (age.inHours < 48) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = createdAt.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.sm),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
