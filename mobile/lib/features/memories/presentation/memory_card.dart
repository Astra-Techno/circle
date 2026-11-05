import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../../core/design/circle_icons.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/group_visuals.dart';
import 'circle_memories.dart' show memoryTimeLabel;
import 'memory_photos.dart';
import '../../chat/application/live_chat.dart';
import 'memory_reactions_sheet.dart';
import 'mention_text.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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
    void openDetail() => context.push('/home/memory/${memory.id}');
    final reactions = memory.reactions;
    final accents = CircleAccents.of(context);
    final caption = detail
        ? theme.textTheme.bodySmall?.copyWith(color: accents.caption)
        : CircleTextStyles.metadata(accents.caption);
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
    final text = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: detail ? Space.md : Space.md - Space.xs,
      ),
      child: Text(
        memory.text,
        style: detail
            ? CircleTextStyles.body(colors.onSurface)
            : CircleTextStyles.homeBody(colors.onSurface),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: detail ? 0 : Space.sm,
        vertical: detail ? 0 : Space.xs,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: detail ? Space.sm : Space.xs),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CircleRadius.card),
        ),
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
                  target: ReportTarget.memory(
                    memory.id,
                    groupId: memory.groupId,
                  ),
                  what: 'Memory',
                ),
              ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                detail ? Space.md : Space.md - Space.xs,
                0,
                Space.sm,
                detail ? Space.sm : 0,
              ),
              child: Row(
                children: [
                  PersonAvatar(
                    person: memory.authorId,
                    name: memory.author,
                    tone: circleTypeTone(group.type),
                    size: CircleAvatarSize.medium,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memory.author,
                          style: detail
                              ? theme.textTheme.titleMedium
                              : CircleTextStyles.homeAuthor(colors.onSurface),
                        ),
                        Text(
                          [
                            audience ?? group.name,
                            memoryTimeLabel(
                              memory.createdAt,
                              ref.watch(circleClockProvider)(),
                            ),
                            if (memory.edited) 'Edited',
                          ].join(' · '),
                          style: caption,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_MemoryAction>(
                    tooltip: 'More options for $about',
                    icon: Icon(LucideIcons.ellipsis, color: accents.caption),
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
            if (hasText && hasPhotos) ...[
              text,
              SizedBox(height: detail ? Space.sm : Space.xs),
            ],
            if (hasPhotos)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: detail ? Space.md : Space.md - Space.xs,
                ),
                child: MemoryPhotoGrid(
                  memory: memory,
                  mosaicAspect: detail ? null : CircleLayout.homeMosaicAspect,
                ),
              ),
            if (hasText && !hasPhotos) text,
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
                      LucideIcons.clock,
                      size: Space.lg,
                      color: accents.caption,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(child: Text(taken, style: caption)),
                  ],
                ),
              ),
            if (reactions.total > 0 || comments > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.section,
                  Space.sm,
                  Space.section,
                  0,
                ),
                child: Row(
                  children: [
                    if (reactions.total > 0)
                      Expanded(
                        child: Tooltip(
                          message: 'Show reactions for $about',
                          child: InkWell(
                            onTap: () =>
                                showReactionSummary(context, reactions),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: CircleSizes.minTouchTarget,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _ReactionSummaryRow(
                                  reactions: reactions,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (reactions.total == 0) const Spacer(),
                    if (comments > 0)
                      Tooltip(
                        message: 'View $comments comments',
                        child: InkWell(
                          onTap: openDetail,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: CircleSizes.minTouchTarget,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('$comments comments', style: caption),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Divider(
              height: detail ? Space.md : Space.xs,
              indent: Space.md,
              endIndent: Space.md,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.face_slightly_smiling,
                      label: 'React',
                      tooltip: 'Choose a reaction for $about',
                      onTap: pickReaction,
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.message_square,
                      label: 'Comment',
                      tooltip: 'Comment on $about',
                      onTap: openDetail,
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.bookmark,
                      label: 'Save',
                      tooltip: 'Save $about',
                      onTap: () =>
                          runCalmly(context, () => controller.save(memory.id)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action button with icon + label (React, Comment, Share).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String label, tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.button),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: CircleSizes.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: CircleSizes.iconAction,
                  color: accents.caption,
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    label,
                    style: CircleTextStyles.label(accents.caption),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact inline reaction summary: top emoji icons + total count.
class _ReactionSummaryRow extends StatelessWidget {
  const _ReactionSummaryRow({required this.reactions});
  final MemoryReactions reactions;
  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: CircleAccents.of(context).caption);
    // Show up to 3 distinct emoji, sorted by count descending.
    final sorted = reactions.others.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmoji = sorted.take(3).map((e) => e.key).toList();
    if (reactions.mine != null && !topEmoji.contains(reactions.mine)) {
      if (topEmoji.length >= 3) topEmoji.removeLast();
      topEmoji.insert(0, reactions.mine!);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final emoji in topEmoji)
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: Text(emoji, style: Theme.of(context).textTheme.bodyLarge),
          ),
        Flexible(
          child: Text(
            '${reactions.total} ${reactions.total == 1 ? 'reaction' : 'reactions'}',
            style: caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
