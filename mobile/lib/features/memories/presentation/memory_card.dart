import '../../profile/presentation/person_avatar.dart';
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
import '../../chat/application/live_chat.dart';
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
    final accents = CircleAccents.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(color: accents.caption);
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
          // Opens (or starts) the direct chat with the author.
          final api = ref.read(liveChatApiProvider);
          final chat = await runCalmly(
            context,
            () => api.direct(memory.authorId),
          );
          if (chat != null && context.mounted) context.go('/chats/c/$chat');
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

    final hasPhotos = memory.photos.isNotEmpty;
    final hasText = memory.text.isNotEmpty;
    // A short words-only Memory reads as a quote.
    final quote =
        hasText &&
        !hasPhotos &&
        memory.poll == null &&
        memory.text.length <= _quoteMaxLength;
    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.section),
      child: Text(memory.text, style: theme.textTheme.bodyLarge),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: detail ? 0 : Space.hero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hidden)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.section,
                0,
                Space.section,
                Space.sm,
              ),
              child: HiddenByAdminsNotice(
                groupId: memory.groupId,
                target: ReportTarget.memory(memory.id, groupId: memory.groupId),
                what: 'Memory',
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Space.section,
              0,
              Space.sm,
              Space.sm,
            ),
            child: Row(
              children: [
                PersonAvatar(
                  person: memory.authorId,
                  name: memory.author,
                  tone: circleTypeTone(group.type),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memory.author, style: theme.textTheme.titleMedium),
                      // Who can see it, always visible (privacy first).
                      Semantics(
                        container: true,
                        label: 'Shared with ${audience ?? group.name} only',
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.lock_outline,
                                  size: Space.lg,
                                  color: accents.caption,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${[audience ?? group.name, memoryTimeLabel(memory.createdAt, DateTime.now()), if (memory.edited) 'Edited'].join(' · ')}',
                              ),
                            ],
                          ),
                          style: caption,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_MemoryAction>(
                  tooltip: 'More options for $about',
                  icon: Icon(Icons.more_horiz, color: accents.caption),
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _MemoryAction.save,
                      child: Text(memory.saved ? 'Unsave' : 'Save'),
                    ),
                    if (!mine && features.has(CircleFeature.liveChat))
                      const PopupMenuItem(
                        value: _MemoryAction.replyPrivately,
                        child: Text('Message privately'),
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
          if (hasPhotos) MemoryPhotoGrid(memory: memory),
          if (quote)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accents.recessed,
                  borderRadius: BorderRadius.circular(CircleRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.section),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.format_quote_rounded,
                          color: accents.caption,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(memory.text, style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
              ),
            )
          else if (hasText && !hasPhotos)
            text,
          if (taken != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.section,
                Space.sm,
                Space.section,
                0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: Space.lg,
                    color: accents.caption,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(taken, style: caption)),
                ],
              ),
            ),
          // Actions: vector heart + count, comments, reaction picker, save.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
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
                      if (reactions.total > 0)
                        Tooltip(
                          message: 'Show reactions for $about',
                          excludeFromSemantics: true,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(Space.large, Space.large),
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.xs,
                              ),
                              foregroundColor: colors.onSurface,
                            ),
                            onPressed: () =>
                                showReactionSummary(context, reactions),
                            child: Text(
                              '${reactions.total}',
                              semanticsLabel:
                                  '${reactions.describe()}. Show reactions',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                      if (!detail)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onSurface,
                          ),
                          onPressed: openDetail,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(
                            comments > 0 ? '$comments' : 'Comment',
                            semanticsLabel: comments > 0
                                ? '$commentLabel on $about'
                                : 'Comment on $about',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Choose a reaction for $about',
                        onPressed: pickReaction,
                        icon: const Icon(Icons.add_reaction_outlined),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: memory.saved ? 'Unsave $about' : 'Save $about',
                  icon: Icon(
                    memory.saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: memory.saved ? colors.primary : null,
                  ),
                  onPressed: () =>
                      runCalmly(context, () => controller.save(memory.id)),
                ),
              ],
            ),
          ),
          if (hasText && hasPhotos) text,
          if (!detail && latest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.section,
                Space.sm,
                Space.section,
                0,
              ),
              child: CommentBubble(latest, onTap: openDetail, maxLines: 2),
            ),
        ],
      ),
    );
  }
}

/// Words-only Memories up to this length are shown as a quote.
const _quoteMaxLength = 160;

/// A vector heart: one tap toggles love; when the viewer chose another
/// reaction, it shows that one and one tap removes it. Long-press opens the
/// picker, which is also reachable from "Choose a reaction" (README §4.0).
/// Emoji appear only for a chosen non-love reaction and in the sheets.
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
    final accents = CircleAccents.of(context);
    final mine = reactions.mine;
    if (mine != null && mine != loveReaction) {
      return TextButton(
        style: TextButton.styleFrom(foregroundColor: accents.heartText),
        onPressed: onTap,
        onLongPress: onLongPress,
        child: Text(
          mine,
          semanticsLabel:
              'Reacted with ${memoryReactionNames[mine]}. '
              'Remove reaction from $about',
        ),
      );
    }
    final loved = mine == loveReaction;
    return Semantics(
      button: true,
      toggled: loved,
      label: loved ? 'Loved. Remove love from $about' : 'Love $about',
      onLongPressHint: 'Choose a reaction',
      excludeSemantics: true,
      // Long-press belongs to the reaction picker, not the tooltip.
      child: Tooltip(
        message: loved ? 'Remove love from $about' : 'Love $about',
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: IconButton(
            isSelected: loved,
            onPressed: onTap,
            icon: const Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: accents.heart),
          ),
        ),
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
class CommentBubble extends ConsumerWidget {
  const CommentBubble(this.comment, {super.key, this.onTap, this.maxLines});
  final MemoryComment comment;
  final VoidCallback? onTap;
  final int? maxLines;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(CircleRadius.tile);
    final bubble = Material(
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonAvatar(
          person: comment.authorId,
          name: comment.authorName,
          size: CircleAvatarSize.small,
        ),
        const SizedBox(width: Space.sm),
        Expanded(child: bubble),
      ],
    );
  }
}
