import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/group_visuals.dart';
import 'circle_memories.dart' show memoryTimeLabel;
import 'memory_photos.dart';
import 'memory_poll_card.dart';
import 'memory_reactions_sheet.dart';
import 'mention_text.dart';

enum _MemoryAction { save, replyPrivately, edit, delete, report }

class CircleMemoryCard extends ConsumerWidget {
  const CircleMemoryCard({
    super.key,
    required this.memory,
    required this.group,
    this.audience,
    this.detail = false,
  });
  final CircleMemory memory;
  final CircleGroup group;

  /// Where the group sits ("Root › Group"); defaults to the group name.
  final String? audience;
  final bool detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final viewer = ref.watch(circleViewerProvider);
    final mine = memory.authorId == viewer;
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final hidden = workspace?.isHidden(ReportKind.memory, memory.id) ?? false;
    final reported = workspace?.reported(ReportKind.memory, memory.id) ?? false;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final about = 'Memory from ${memory.author} in ${group.name}';
    final features = ref.watch(circleFeaturesProvider);
    final comments = memory.commentTotal;
    final commentLabel = '$comments ${comments == 1 ? 'comment' : 'comments'}';
    void openDetail() => context.push('/home/memory/${memory.id}');
    final latest = CommentRules.latest(memory.comments);
    final reactions = memory.reactions;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final taken = memory.takenLabel;

    Future<void> react(String emoji) =>
        runCalmly(context, () => controller.react(memory.id, emoji));
    Future<void> pickReaction() async {
      final emoji = await showReactionPicker(context, reactions);
      if (emoji != null && context.mounted) await react(emoji);
    }

    Future<void> onMenu(_MemoryAction action) async {
      switch (action) {
        case _MemoryAction.save:
          await runCalmly(context, () => controller.save(memory.id));
        case _MemoryAction.replyPrivately:
          // Opens the 1:1 chat with the author with this Memory attached.
          context.go('/chats/reply/${memory.id}');
        case _MemoryAction.edit:
          await showModalBottomSheet<void>(
            context: context,
            // Above the shell's navigation bar, so nothing is hidden.
            useRootNavigator: true,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _EditMemorySheet(memory: memory),
          );
        case _MemoryAction.report:
          await reportToAdmins(
            context,
            ref,
            target: ReportTarget.memory(memory.id, groupId: memory.groupId),
            what: 'this Memory',
          );
        case _MemoryAction.delete:
          final router = GoRouter.of(context);
          final deleted = await runCalmly(
            context,
            () async {
              await controller.deleteMemory(memory.id);
              return true;
            },
            success: 'Memory deleted.',
            onUndo: undoDetached(
              context,
              () => controller.restoreMemory(memory.id),
            ),
          );
          if (deleted == true && detail) {
            router.canPop() ? router.pop() : router.go('/home');
          }
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hidden)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                0,
              ),
              child: HiddenByAdminsNotice(
                groupId: memory.groupId,
                target: ReportTarget.memory(memory.id, groupId: memory.groupId),
                what: 'Memory',
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Space.lg,
              Space.lg,
              Space.xs,
              Space.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleInitialAvatar(
                  name: memory.author,
                  tone: circleTypeTone(group.type),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            memory.author,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            [
                              memoryTimeLabel(memory.createdAt, DateTime.now()),
                              if (memory.edited) 'Edited',
                            ].join(' · '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      CirclePill(
                        audience ?? group.name,
                        icon: Icons.lock_outline,
                        tone: circleTypeTone(group.type),
                        semanticsLabel:
                            'Shared with ${audience ?? group.name} only',
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_MemoryAction>(
                  tooltip: 'More options for $about',
                  icon: const Icon(Icons.more_vert),
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _MemoryAction.save,
                      child: Text(memory.saved ? 'Unsave' : 'Save'),
                    ),
                    if (!mine && features.has(CircleFeature.chat))
                      const PopupMenuItem(
                        value: _MemoryAction.replyPrivately,
                        child: Text('Reply privately'),
                      ),
                    if (!mine &&
                        !reported &&
                        !hidden &&
                        features.has(CircleFeature.moderation))
                      const PopupMenuItem(
                        value: _MemoryAction.report,
                        child: Text('Report'),
                      ),
                    if (mine) ...[
                      const PopupMenuItem(
                        value: _MemoryAction.edit,
                        child: Text('Edit text'),
                      ),
                      const PopupMenuItem(
                        value: _MemoryAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (memory.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(memory.text, style: theme.textTheme.bodyMedium),
            ),
          if (taken != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(taken, style: caption)),
                ],
              ),
            ),
          if (memory.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                0,
              ),
              child: MemoryPhotoGrid(memory: memory),
            ),
          if (memory.poll != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                0,
              ),
              child: MemoryPollCard(memoryId: memory.id, poll: memory.poll!),
            ),
          if (reactions.total > 0 || (!detail && comments > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.sm,
                Space.sm,
                0,
              ),
              child: Row(
                children: [
                  if (reactions.total > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurface,
                      ),
                      onPressed: () => showReactionSummary(context, reactions),
                      child: Text(
                        [
                          reactions.ranked.take(3).map((r) => r.emoji).join(),
                          '${reactions.total}',
                        ].where((part) => part.isNotEmpty).join(' '),
                        semanticsLabel:
                            '${reactions.describe()}. Show reactions',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  const Spacer(),
                  if (!detail && comments > 0)
                    TextButton(
                      onPressed: openDetail,
                      child: Text(
                        commentLabel,
                        semanticsLabel: '$commentLabel on $about',
                        style: caption,
                      ),
                    ),
                ],
              ),
            ),
          if (!detail && latest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                0,
              ),
              child: CommentBubble(latest, onTap: openDetail, maxLines: 2),
            ),
          const Padding(
            padding: EdgeInsets.only(top: Space.md),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            child: Row(
              children: [
                // Wraps onto two lines at very large text sizes.
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LoveButton(
                        reactions: reactions,
                        about: about,
                        onTap: () => react(reactions.mine ?? loveReaction),
                        onLongPress: pickReaction,
                      ),
                      IconButton(
                        tooltip: 'Choose a reaction for $about',
                        onPressed: pickReaction,
                        icon: const Icon(Icons.add_reaction_outlined),
                      ),
                      if (!detail)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onSurface,
                          ),
                          onPressed: openDetail,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            'Comment',
                            semanticsLabel: 'Comment on $about',
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: memory.saved ? 'Unsave $about' : 'Save $about',
                  icon: Icon(
                    memory.saved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: () =>
                      runCalmly(context, () => controller.save(memory.id)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tap toggles ❤️; when the viewer chose another emoji, it shows that
/// emoji and one tap removes it. Long-press opens the picker, which is
/// also reachable from the "Choose a reaction" button (README §4.0).
class _LoveButton extends StatelessWidget {
  const _LoveButton({
    required this.reactions,
    required this.about,
    required this.onTap,
    required this.onLongPress,
  });
  final MemoryReactions reactions;
  final String about;
  final VoidCallback onTap, onLongPress;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accents = CircleAccents.of(context);
    final mine = reactions.mine;
    if (mine != null && mine != loveReaction) {
      return TextButton(
        style: TextButton.styleFrom(foregroundColor: accents.heartText),
        onPressed: onTap,
        onLongPress: onLongPress,
        child: Text(
          '$mine Reacted',
          semanticsLabel:
              'Reacted with ${memoryReactionNames[mine]}. '
              'Remove reaction from $about',
        ),
      );
    }
    final loved = mine == loveReaction;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: loved ? accents.heartText : colors.onSurface,
      ),
      onPressed: onTap,
      onLongPress: onLongPress,
      icon: Icon(
        loved ? Icons.favorite : Icons.favorite_border,
        color: loved ? accents.heart : null,
      ),
      label: Text(
        loved ? 'Loved' : 'Love',
        semanticsLabel: loved
            ? 'Loved. Remove love from $about'
            : 'Love $about',
      ),
    );
  }
}

/// Author-only text edit. Text may be cleared when photos or a poll keep
/// the Memory meaningful; the domain rules decide.
class _EditMemorySheet extends ConsumerStatefulWidget {
  const _EditMemorySheet({required this.memory});
  final CircleMemory memory;
  @override
  ConsumerState<_EditMemorySheet> createState() => _EditMemorySheetState();
}

class _EditMemorySheetState extends ConsumerState<_EditMemorySheet> {
  late final _text = TextEditingController(text: widget.memory.text);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final memory = widget.memory;
    final check = MemoryRules.checkContent(
      text: _text.text,
      photoCount: memory.photos.length,
      hasPoll: memory.poll != null,
    );
    if (!check.allowed) {
      setState(() => _error = check.reason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final saved = await runCalmly(context, () async {
      await ref
          .read(circleWorkspaceProvider.notifier)
          .editMemory(memory.id, _text.text);
      return true;
    }, success: 'Memory updated.');
    if (!mounted) return;
    if (saved == true) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Edit your Memory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: MemoryRules.maxText,
            decoration: InputDecoration(
              labelText: 'Your Memory',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? savingLabel(ref) : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}

/// One comment as a recessed bubble: "**Name:** text".
class CommentBubble extends StatelessWidget {
  const CommentBubble(this.comment, {super.key, this.onTap, this.maxLines});
  final MemoryComment comment;
  final VoidCallback? onTap;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CircleRadius.tile);
    return Material(
      color: CircleAccents.of(context).recessed,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${comment.authorName}: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                ...mentionSpans(context, comment.text, comment.mentions.values),
              ],
            ),
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
