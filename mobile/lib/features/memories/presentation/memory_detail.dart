import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'circle_memories.dart' show memoryTimeLabel;
import 'memory_card.dart';
import 'mention_text.dart';

/// B2: the full Memory, then comments in order with replies indented
/// under their parent, then the composer.
class CircleMemoryDetail extends ConsumerStatefulWidget {
  const CircleMemoryDetail({super.key, required this.id});
  final String id;
  @override
  ConsumerState<CircleMemoryDetail> createState() => _CircleMemoryDetailState();
}

class _CircleMemoryDetailState extends ConsumerState<CircleMemoryDetail> {
  final _focus = FocusNode();
  String? _replyTo;

  @override
  void initState() {
    super.initState();
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

  Future<void> _delete(MemoryComment comment) {
    final controller = ref.read(circleWorkspaceProvider.notifier);
    if (_replyTo == comment.id) setState(() => _replyTo = null);
    return runCalmly(
      context,
      () => controller.deleteComment(widget.id, comment.id),
      success: 'Comment deleted.',
      onUndo: undoDetached(
        context,
        () => controller.restoreComment(widget.id, comment.id),
      ),
    );
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
                  what: '${comment.authorName}’s comment',
                ),
        );
      }

      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
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
                  padding: const EdgeInsetsDirectional.only(start: Space.hero),
                  child: tile(reply),
                ),
            ],
            const SizedBox(height: Space.sm),
            CircleTextEditor(
              focusNode: _focus,
              label: replyTo == null ? 'Add a comment' : 'Write a reply',
              button: replyTo == null ? 'Send comment' : 'Send reply',
              busyLabel: savingLabel(ref),
              header: replyTo == null
                  ? null
                  : Row(
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
              mentionMembers: members,
              viewer: workspace.viewer,
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
          ],
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hiddenNotice != null) ...[
            hiddenNotice!,
            const SizedBox(height: Space.xs),
          ],
          CommentBubble(comment),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.xs,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Space.md),
                child: Text(
                  memoryTimeLabel(comment.createdAt, DateTime.now()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onReply != null)
                TextButton(
                  onPressed: onReply,
                  child: Text(
                    'Reply',
                    semanticsLabel: 'Reply to ${comment.authorName}',
                  ),
                ),
              if (own && onDelete != null)
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Delete',
                    semanticsLabel: 'Delete your comment',
                  ),
                ),
              if (onReport != null)
                TextButton(
                  onPressed: onReport,
                  child: Text(
                    'Report',
                    semanticsLabel: 'Report ${comment.authorName}’s comment',
                  ),
                ),
            ],
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
    this.busyLabel = 'Saving locally…',
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
