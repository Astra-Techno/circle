import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import '../../groups/domain/group_tree.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../profile/presentation/person_avatar.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'circle_memories.dart' show memoryTimeLabel;
import 'memory_card.dart';
import 'mention_text.dart';

/// B2: the full Memory, then comments in order with replies indented
/// under their parent, then the composer.
class CircleMemoryDetail extends ConsumerStatefulWidget {
  const CircleMemoryDetail({
    super.key,
    required this.id,
    this.focusComment = false,
  });
  final String id;
  final bool focusComment;
  @override
  ConsumerState<CircleMemoryDetail> createState() => _CircleMemoryDetailState();
}

class _CircleMemoryDetailState extends ConsumerState<CircleMemoryDetail> {
  final _focus = FocusNode();
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
    // On a server, opening a Memory loads its comments and every reaction.
    // Offline, the card keeps what the list already showed.
    unawaited(
      Future.microtask(
        () =>
            ref.read(circleWorkspaceProvider.notifier).refreshMemory(widget.id),
      ).then((_) {}, onError: (Object _) {}),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reply(MemoryComment comment) {
    setState(() => _replyTo = comment.id);
    _focus.requestFocus();
  }

  Future<void> _delete(MemoryComment comment) async {
    final confirmed = await confirmCircleAction(
      context,
      title: 'Delete this comment?',
      message: 'It will be removed for everyone.',
      confirm: 'Delete',
    );
    if (!confirmed || !mounted) return;
    final controller = ref.read(circleWorkspaceProvider.notifier);
    if (_replyTo == comment.id) setState(() => _replyTo = null);
    final undo = undoDetached(
      context,
      () => controller.restoreComment(widget.id, comment.id),
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await controller.deleteComment(widget.id, comment.id);
      if (mounted) {
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Comment deleted'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'Undo', onPressed: undo),
            ),
          );
      }
    } on CircleFailure catch (failure) {
      if (mounted) showCircleMessage(context, failure.message);
    } catch (_) {
      if (mounted) {
        showCircleMessage(context, 'That didn\u2019t work. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final memory = workspace.memories
          .where((memory) => memory.id == widget.id)
          .firstOrNull;
      if (memory == null) {
        return const ReadingPane(
          child: Padding(
            padding: CircleInsets.form,
            child: CircleEmpty(
              icon: LucideIcons.lock_keyhole,
              title: 'Memory unavailable',
              message: 'This Memory is not shared with your current groups.',
            ),
          ),
        );
      }
      final group = workspace.group(memory.groupId)!;
      final features = ref.watch(circleFeaturesProvider);
      // Only this exact group's members can be mentioned.
      final members = [
        for (final person in group.roles.keys)
          MentionCandidate(id: person, name: workspace.nameOf(person)),
      ];
      final threads = CommentRules.threads(memory.comments);
      final replyTo = memory.comments
          .where((comment) => comment.id == _replyTo && !comment.isReply)
          .firstOrNull;
      Widget tile(MemoryComment comment) {
        final hidden = workspace.isHidden(ReportKind.comment, comment.id);
        final target = ReportTarget.comment(
          comment.id,
          memoryId: memory.id,
          groupId: memory.groupId,
        );
        final own = comment.authorId == workspace.viewer;
        return _CommentTile(
          comment: comment,
          own: own,
          onReply: comment.isReply ? null : () => _reply(comment),
          onDelete: features.has(CircleFeature.commentDeletion)
              ? () => _delete(comment)
              : null,
          hiddenNotice: hidden
              ? HiddenByAdminsNotice(
                  groupId: memory.groupId,
                  target: target,
                  what: 'comment',
                )
              : null,
          onReport:
              own ||
                  hidden ||
                  !features.has(CircleFeature.moderation) ||
                  workspace.reported(ReportKind.comment, comment.id)
              ? null
              : () => reportToAdmins(
                  context,
                  ref,
                  target: target,
                  what: '${comment.authorName}\u2019s comment',
                ),
        );
      }

      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form.copyWith(left: 0, right: 0, top: 0),
          children:
              <Widget>[
                    CircleMemoryCard(
                      memory: memory,
                      group: group,
                      audience: audiencePath(group, workspace.groupsById),
                      detail: true,
                    ),
                    CircleSectionTitle(
                      memory.comments.isEmpty
                          ? 'Start the conversation'
                          : 'Comments (${memory.comments.length})',
                    ),
                    for (final thread in threads) ...[
                      tile(thread.comment),
                      for (final reply in thread.replies)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: Space.hero,
                          ),
                          child: tile(reply),
                        ),
                    ],
                    const Divider(height: Space.section),
                    if (replyTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${replyTo.authorName}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _replyTo = null),
                              child: Text(
                                'Cancel',
                                semanticsLabel:
                                    'Cancel reply to ${replyTo.authorName}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    _InlineCommentInput(
                      focusNode: _focus,
                      viewerId: workspace.viewer,
                      hint: replyTo == null
                          ? 'Write a comment...'
                          : 'Write a reply...',
                      mentionMembers: members,
                      submit: (text, mentions) async {
                        await ref
                            .read(circleWorkspaceProvider.notifier)
                            .comment(
                              memory.id,
                              text,
                              replyTo: replyTo?.id,
                              mentions: mentions,
                            );
                        if (mounted) setState(() => _replyTo = null);
                      },
                    ),
                  ]
                  .map(
                    (child) => child is CircleMemoryCard
                        ? child
                        : Padding(
                            key: child is _InlineCommentInput
                                ? ValueKey('memory-comment-input-${widget.id}')
                                : child.key,
                            padding: CircleInsets.content,
                            child: child,
                          ),
                  )
                  .toList(),
        ),
      );
    },
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.own,
    this.onDelete,
    this.onReply,
    this.onReport,
    this.hiddenNotice,
  });
  final MemoryComment comment;
  final bool own;
  final VoidCallback? onReply, onReport;

  /// Null where deleting comments isn't available.
  final VoidCallback? onDelete;

  /// "Hidden by admins" with Unhide, for the group's admins.
  final Widget? hiddenNotice;
  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hiddenNotice != null) ...[
            hiddenNotice!,
            const SizedBox(height: Space.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: CommentBubble(comment)),
              const SizedBox(width: Space.sm),
              // Heart icon + like count.
              Column(
                children: [
                  const SizedBox(height: Space.md),
                  Icon(
                    LucideIcons.heart,
                    size: Space.md,
                    color: accents.caption,
                  ),
                  Text('0', style: CircleTextStyles.caption(accents.caption)),
                ],
              ),
            ],
          ),
          // Time + Reply row.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Space.large,
              top: Space.xs,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.md,
              children: [
                Text(
                  memoryTimeLabel(comment.createdAt, DateTime.now()),
                  style: CircleTextStyles.metadata(accents.caption),
                ),
                if (onReply != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    onTap: onReply,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: CircleSizes.minTouchTarget,
                        minWidth: CircleSizes.minTouchTarget,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Reply',
                          semanticsLabel: 'Reply to ${comment.authorName}',
                          style: CircleTextStyles.label(accents.caption),
                        ),
                      ),
                    ),
                  ),
                if (own && onDelete != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    onTap: onDelete,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: CircleSizes.minTouchTarget,
                        minWidth: CircleSizes.minTouchTarget,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Delete',
                          semanticsLabel: 'Delete your comment',
                          style: CircleTextStyles.label(accents.caption),
                        ),
                      ),
                    ),
                  ),
                if (onReport != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    onTap: onReport,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: CircleSizes.minTouchTarget,
                        minWidth: CircleSizes.minTouchTarget,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Report',
                          semanticsLabel:
                              'Report ${comment.authorName}\u2019s comment',
                          style: CircleTextStyles.label(accents.caption),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CircleTextEditor extends StatefulWidget {
  const CircleTextEditor({
    super.key,
    required this.label,
    required this.button,
    required this.submit,
    this.validate,
    this.focusNode,
    this.header,
    this.busyLabel = 'Saving…',
    this.mentionMembers = const [],
    this.viewer = '',
    this.blocked = const {},
  });
  final String label, button;

  /// The button's text while sending.
  final String busyLabel;

  /// Sends the text and the people picked from @mention suggestions.
  final Future<void> Function(String text, Map<String, String> mentions) submit;

  /// Who "@" can suggest: the exact group's members (empty: no mentions).
  final List<MentionCandidate> mentionMembers;
  final String viewer;

  /// Never suggested (people the viewer blocked).
  final Set<String> blocked;

  /// Runs before [submit]; returning false cancels quietly.
  final bool Function()? validate;
  final FocusNode? focusNode;

  /// Shown above the field, e.g. "Replying to Mira · Cancel".
  final Widget? header;
  @override
  State<CircleTextEditor> createState() => _CircleTextEditorState();
}

class _CircleTextEditorState extends State<CircleTextEditor> {
  final _text = TextEditingController();
  final _mentions = MentionDraft();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (widget.validate != null && !widget.validate!()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(
        _text.text,
        _mentions.resolve(_text.text, {
          for (final member in widget.mentionMembers) member.id,
        }),
      );
      if (mounted) {
        _mentions.clear();
        _text.clear();
        FocusScope.of(context).unfocus();
      }
    } on CircleFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?widget.header,
      if (widget.mentionMembers.isNotEmpty)
        MentionSuggestions(
          controller: _text,
          draft: _mentions,
          members: widget.mentionMembers,
          viewer: widget.viewer,
          blocked: widget.blocked,
        ),
      TextField(
        controller: _text,
        focusNode: widget.focusNode,
        minLines: 3,
        maxLines: 8,
        maxLength: CommentRules.maxLength,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      const SizedBox(height: Space.md),
      FilledButton(
        onPressed: _busy ? null : _send,
        child: Text(_busy ? widget.busyLabel : widget.button),
      ),
    ],
  );
}

/// Inline comment row: avatar + rounded text field + send button.
class _InlineCommentInput extends StatefulWidget {
  const _InlineCommentInput({
    required this.viewerId,
    required this.hint,
    required this.submit,
    this.focusNode,
    this.mentionMembers = const [],
  });
  final String viewerId, hint;
  final FocusNode? focusNode;
  final List<MentionCandidate> mentionMembers;
  final Future<void> Function(String text, Map<String, String> mentions) submit;
  @override
  State<_InlineCommentInput> createState() => _InlineCommentInputState();
}

class _InlineCommentInputState extends State<_InlineCommentInput> {
  final _text = TextEditingController();
  final _mentions = MentionDraft();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.submit(
        _text.text,
        _mentions.resolve(_text.text, {
          for (final m in widget.mentionMembers) m.id,
        }),
      );
      if (mounted) {
        _mentions.clear();
        _text.clear();
        FocusScope.of(context).unfocus();
      }
    } on CircleFailure catch (_) {
      // Error handled upstream.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.mentionMembers.isNotEmpty)
          MentionSuggestions(
            controller: _text,
            draft: _mentions,
            members: widget.mentionMembers,
            viewer: widget.viewerId,
          ),
        Row(
          children: [
            PersonAvatar(
              person: widget.viewerId,
              name: '',
              size: CircleAvatarSize.small,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: widget.focusNode,
                maxLines: 1,
                maxLength: CommentRules.maxLength,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    borderSide: BorderSide(color: accents.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    borderSide: BorderSide(color: accents.hairline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Semantics(
              label: 'Send comment',
              button: true,
              child: SizedBox(
                width: CircleSizes.minTouchTarget,
                height: CircleSizes.minTouchTarget,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy ? null : _send,
                    child: Icon(
                      CircleIcons.send,
                      size: CircleSizes.iconAction,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
