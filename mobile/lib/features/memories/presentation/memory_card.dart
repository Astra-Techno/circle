import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/api/api_providers.dart';
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
import '../../polls/presentation/live_polls.dart' show LivePollCard;
import '../../events/presentation/live_events.dart' show LiveEventCard;
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
    final colors = Theme.of(context).colorScheme;
    final about = 'Memory from ${memory.author} in ${group.name}';
    final features = ref.watch(circleFeaturesProvider);
    final comments = memory.commentTotal;
    void openDetail() => context.push('/home/memory/${memory.id}');
    final reactions = memory.reactions;
    final accents = CircleAccents.of(context);
    final caption = detail
        ? Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: accents.caption)
        : CircleTextStyles.metadata(accents.caption);
    final taken = memory.takenLabel;

    Future<void> react(String emoji) =>
        runCalmly(context, () => controller.react(memory.id, emoji));
    Future<void> pickReaction() async {
      final api = ref.read(apiClientProvider);
      final session = api?.sessionRevision;
      final repository = ref.read(circleRepositoryProvider);
      final emoji = await showReactionPicker(context, reactions);
      if (!context.mounted ||
          !identical(ref.read(apiClientProvider), api) ||
          api?.sessionRevision != session ||
          !identical(ref.read(circleRepositoryProvider), repository)) {
        return;
      }
      if (emoji != null) await react(emoji);
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
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: _MemoryCaption(
        key: ValueKey('caption-${memory.id}'),
        text: memory.text,
        expanded: detail,
        textOnly: !hasPhotos,
      ),
    );

    return DecoratedBox(
      key: ValueKey('memory-surface-${memory.id}'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: accents.hairline,
            width: CircleMemoryLayout.dividerThickness,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
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
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.md,
                Space.xs,
                Space.sm,
                Space.xs,
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
                          style: CircleTextStyles.homeAuthor(colors.onSurface),
                        ),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.lock_keyhole,
                              size: CircleSizes.iconInline,
                              color: accents.caption,
                            ),
                            const SizedBox(width: Space.xs),
                            Expanded(
                              child: Text(
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_MemoryAction>(
                    tooltip: 'More options for $about',
                    icon: Icon(CircleIcons.more, color: accents.caption),
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
            if (hasText &&
                !(memory.liveEvents.length == 1 &&
                    memory.liveEvents.first['title'] == memory.text) &&
                !(memory.livePolls.length == 1 &&
                    memory.livePolls.first['question'] == memory.text)) ...[
              text,
              const SizedBox(height: Space.sm),
            ],
            for (final event in memory.liveEvents)
              Padding(
                padding: CircleInsets.content,
                child: LiveEventCard(
                  key: ValueKey('event-${event['id']}'),
                  item: event,
                  onTap: () => context.push('/events/e/${event['id']}'),
                ),
              ),
            for (final poll in memory.livePolls)
              Padding(
                padding: CircleInsets.content,
                child: LivePollCard(
                  key: ValueKey('poll-${poll['id']}'),
                  poll: poll,
                  showAudience: false,
                ),
              ),
            if (hasPhotos)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CircleMemoryLayout.mediaInset,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    CircleMemoryLayout.mediaRadius,
                  ),
                  child: MemoryPhotoGrid(memory: memory),
                ),
              ),
            if (!hasText && memory.poll != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(
                  memory.summary,
                  style: CircleTextStyles.body(colors.onSurface),
                ),
              ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        _ActionPill(
                          children: [
                            _ActionButton(
                              icon: CircleIcons.react,
                              tooltip: 'Choose a reaction for $about',
                              selected: reactions.mine != null,
                              reaction: reactions.mine,
                              onTap: pickReaction,
                            ),
                            Tooltip(
                              message: 'Show reactions for $about',
                              child: TextButton(
                                onPressed: () =>
                                    showReactionSummary(context, reactions),
                                style: TextButton.styleFrom(
                                  foregroundColor: accents.caption,
                                  minimumSize: const Size(
                                    CircleSizes.minTouchTarget,
                                    CircleSizes.minTouchTarget,
                                  ),
                                ),
                                child: Text(
                                  CircleMemoryLayout.countLabel(
                                    reactions.total,
                                  ),
                                  semanticsLabel: reactions.describe(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _ActionPill(
                          children: [
                            _ActionButton(
                              icon: CircleIcons.comment,
                              tooltip: 'Comment on $about',
                              onTap: openDetail,
                            ),
                            Tooltip(
                              message: 'View $comments comments',
                              child: TextButton(
                                onPressed: openDetail,
                                style: TextButton.styleFrom(
                                  foregroundColor: accents.caption,
                                  minimumSize: const Size(
                                    CircleSizes.minTouchTarget,
                                    CircleSizes.minTouchTarget,
                                  ),
                                ),
                                child: Text(
                                  CircleMemoryLayout.countLabel(comments),
                                  semanticsLabel: '$comments comments',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  _ActionPill(
                    children: [
                      _ActionButton(
                        icon: memory.saved
                            ? CircleIcons.saved
                            : CircleIcons.bookmark,
                        selected: memory.saved,
                        tooltip: '${memory.saved ? 'Unsave' : 'Save'} $about',
                        onTap: () => runCalmly(
                          context,
                          () => controller.save(memory.id),
                        ),
                      ),
                    ],
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

/// Outlined visual pill inside full-height accessible hit areas.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        top: Space.xs,
        bottom: Space.xs,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(
                color: CircleAccents.of(context).hairline,
                width: CircleMemoryLayout.actionBorderWidth,
              ),
            ),
          ),
        ),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: children),
    ],
  );
}

/// Labeled,48px controls with restrained ink and explicit selected state.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.reaction,
    this.selected = false,
  });
  final IconData icon;
  final String? reaction;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final ink = selected
        ? Theme.of(context).colorScheme.primary
        : CircleAccents.of(context).caption;
    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CircleRadius.button),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CircleSizes.minTouchTarget,
              minWidth: CircleSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: reaction == null
                    ? Icon(
                        icon,
                        size: CircleMemoryLayout.actionIcon,
                        color: ink,
                      )
                    : SizedBox.square(
                        dimension: CircleMemoryLayout.actionIcon,
                        child: FittedBox(
                          child: Text(
                            reaction!,
                            textScaler: TextScaler.noScaling,
                            style: CircleTextStyles.reactionGlyph(ink),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Long captions expand in place without leaving the timeline or clipping
/// accessible text. Full Memory detail always starts expanded.
class _MemoryCaption extends StatefulWidget {
  const _MemoryCaption({
    super.key,
    required this.text,
    required this.expanded,
    required this.textOnly,
  });
  final String text;
  final bool expanded;
  final bool textOnly;
  @override
  State<_MemoryCaption> createState() => _MemoryCaptionState();
}

class _MemoryCaptionState extends State<_MemoryCaption> {
  bool _expanded = false;
  @override
  void didUpdateWidget(covariant _MemoryCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = CircleTextStyles.postBody(
        Theme.of(context).colorScheme.onSurface,
      );
      final paragraph = widget.text.indexOf('\n\n');
      // A short standalone text post or explicit opening paragraph acts as
      // its heading; never invent a title or duplicate caption content.
      final leadEnd = paragraph > 0 && paragraph <= 160
          ? paragraph
          : widget.textOnly && widget.text.length <= 160
          ? widget.text.length
          : 0;
      final content = TextSpan(
        style: style,
        children: [
          if (leadEnd > 0)
            TextSpan(
              text: widget.text.substring(0, leadEnd),
              style: CircleTextStyles.postHeading(
                Theme.of(context).colorScheme.onSurface,
              ),
            ),
          TextSpan(text: widget.text.substring(leadEnd)),
        ],
      );
      final painter = TextPainter(
        text: content,
        maxLines: CircleMemoryLayout.collapsedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final more = painter.didExceedMaxLines;
      painter.dispose();
      final expanded = widget.expanded || _expanded;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            content,
            maxLines: expanded ? null : CircleMemoryLayout.collapsedLines,
            overflow: expanded ? TextOverflow.clip : TextOverflow.ellipsis,
          ),
          if (more && !expanded)
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: const Text('See more'),
            ),
        ],
      );
    },
  );
}

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
