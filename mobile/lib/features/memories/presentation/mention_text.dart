import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../domain/circle_memory.dart';

/// Text with its "@Name" mentions emphasised (bold, in the primary colour;
/// [onPrimary] for text on an indigo bubble, where the mention is bold and
/// underlined instead).
class MentionText extends StatelessWidget {
  const MentionText(
    this.text, {
    super.key,
    required this.names,
    this.style,
    this.onPrimary = false,
    this.maxLines,
  });
  final String text;
  final Iterable<String> names;
  final TextStyle? style;
  final bool onPrimary;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: mentionSpans(context, text, names, onPrimary: onPrimary),
    ),
    style: style,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
  );
}

/// [text] as spans, with each "@Name" of [names] emphasised.
List<InlineSpan> mentionSpans(
  BuildContext context,
  String text,
  Iterable<String> names, {
  bool onPrimary = false,
}) {
  final colors = Theme.of(context).colorScheme;
  final emphasis = TextStyle(
    fontWeight: FontWeight.w700,
    color: onPrimary ? colors.onPrimary : colors.primary,
    decoration: onPrimary ? TextDecoration.underline : null,
    decorationColor: onPrimary ? colors.onPrimary : null,
  );
  return [
    for (final segment in MentionRules.segments(text, names))
      TextSpan(text: segment.text, style: segment.mention ? emphasis : null),
  ];
}

/// Remembers who was picked from the suggestions for one composer, so the
/// mention can be sent with the text.
class MentionDraft {
  final Map<String, String> picked = {};

  /// The mentions to send: picked people still named in [text] and still
  /// in [members].
  Map<String, String> resolve(String text, Set<String> members) =>
      MentionRules.resolve(text: text, picked: picked, members: members);

  void clear() => picked.clear();
}

/// Suggestions while someone types "@" and a few letters in [controller]:
/// members of the exact group only (never the viewer or anyone they
/// blocked). Picking one writes "@Name " and records it in [draft].
class MentionSuggestions extends StatelessWidget {
  const MentionSuggestions({
    super.key,
    required this.controller,
    required this.draft,
    required this.members,
    required this.viewer,
    this.blocked = const {},
    this.onChanged,
  });
  final TextEditingController controller;
  final MentionDraft draft;
  final List<MentionCandidate> members;
  final String viewer;
  final Set<String> blocked;

  /// Called after a pick changes the text.
  final VoidCallback? onChanged;

  void _pick(MentionCandidate person) {
    final selection = controller.selection;
    final cursor = selection.isValid
        ? selection.baseOffset
        : controller.text.length;
    final active = MentionRules.activeQuery(controller.text, cursor);
    if (active == null) return;
    final next = MentionRules.insert(
      controller.text,
      start: active.start,
      cursor: cursor,
      name: person.name,
    );
    draft.picked[person.id] = person.name;
    controller.value = TextEditingValue(
      text: next.text,
      selection: TextSelection.collapsed(offset: next.cursor),
    );
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final selection = controller.selection;
      final cursor = selection.isValid && selection.isCollapsed
          ? selection.baseOffset
          : -1;
      final active = MentionRules.activeQuery(controller.text, cursor);
      if (active == null) return const SizedBox.shrink();
      final found = MentionRules.suggestions(
        query: active.query,
        members: members,
        viewer: viewer,
        blocked: blocked,
      );
      if (found.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Material(
          key: const ValueKey('mention-suggestions'),
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: CircleAccents.of(context).hairline),
            borderRadius: BorderRadius.circular(CircleRadius.tile),
          ),
          child: Semantics(
            container: true,
            label: 'People in this group',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final person in found)
                  ListTile(
                    key: ValueKey('mention-${person.id}'),
                    leading: CircleInitialAvatar(
                      name: person.name,
                      size: CircleAvatarSize.small,
                    ),
                    title: Text(
                      person.name,
                      semanticsLabel: 'Mention ${person.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _pick(person),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
