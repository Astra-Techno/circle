import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';

/// The 8-emoji picker. Returns the chosen emoji (choosing the current one
/// means "remove"), or null when dismissed.
Future<String?> showReactionPicker(
  BuildContext context,
  MemoryReactions reactions,
) => showModalBottomSheet<String>(
  context: context,
  // Above the shell's navigation bar, so nothing is hidden.
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'React to this Memory',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            reactions.mine == null
                ? 'Choose one reaction.'
                : 'Choose the same one again to remove it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final emoji in memoryReactions)
                ChoiceChip(
                  selected: reactions.mine == emoji,
                  showCheckmark: false,
                  onSelected: (_) => Navigator.of(context).pop(emoji),
                  label: Text(
                    emoji,
                    style: theme.textTheme.titleLarge,
                    semanticsLabel: reactions.mine == emoji
                        ? '${memoryReactionNames[emoji]}, your reaction. '
                              'Choose again to remove'
                        : 'React with ${memoryReactionNames[emoji]}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  },
);

/// Counts per emoji. The preview shows no names for reactions.
Future<void> showReactionSummary(
  BuildContext context,
  MemoryReactions reactions,
) => showModalBottomSheet<void>(
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
        CircleSectionTitle('Reactions (${reactions.total})'),
        for (final item in reactions.ranked)
          CircleRow(
            divider: item != reactions.ranked.last,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ExcludeSemantics(
                child: Text(
                  item.emoji,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              title: Text(memoryReactionNames[item.emoji]!),
              subtitle: reactions.mine == item.emoji
                  ? const Text('Includes you')
                  : null,
              trailing: Text(
                '${item.count}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
      ],
    ),
  ),
);
