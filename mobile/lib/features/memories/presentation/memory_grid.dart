import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import 'memory_photos.dart';

/// A profile's Memories as a three-column grid (like Instagram): the first
/// photo, or the words on a quiet tile. Each opens the Memory.
class MemoryGrid extends StatelessWidget {
  const MemoryGrid({super.key, required this.memories, required this.empty});
  final List<CircleMemory> memories;

  /// Shown when there is nothing to show yet.
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Text(
          empty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CircleAccents.of(context).caption,
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: Space.xs,
      crossAxisSpacing: Space.xs,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final memory in memories)
          _GridTile(
            memory: memory,
            onTap: () => context.push('/home/memory/${memory.id}'),
          ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.memory, required this.onTap});
  final CircleMemory memory;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = 'Memory from ${memory.author}';
    if (memory.photos.isNotEmpty) {
      return MemoryPhotoTile(
        photo: memory.photos.first,
        semanticsLabel: '$label, photo',
        onTap: onTap,
        more: memory.photos.length > 1 ? '+${memory.photos.length - 1}' : null,
      );
    }
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label: ${memory.text}',
      excludeSemantics: true,
      child: Material(
        color: CircleAccents.of(context).recessed,
        borderRadius: BorderRadius.circular(CircleRadius.small),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Text(
              memory.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
