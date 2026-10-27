import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../application/chat_providers.dart';

/// The one preview label of every chat screen (README §4.0).
const chatPreviewNote =
    'Preview: messages stay on this device. Nobody receives them.';

/// A group icon or a person's initial.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.title,
    this.groupType,
    this.person,
    this.size = CircleAvatarSize.medium,
    this.active = false,
  });
  final String? person;
  final String title;

  /// Set for group chats.
  final CircleType? groupType;
  final CircleAvatarSize size;

  /// 1:1 only: the other person is active now.
  final bool active;
  @override
  Widget build(BuildContext context) => groupType == null
      ? PersonAvatar(
          person: person ?? '',
          name: title,
          size: size,
          active: active,
        )
      : CircleInitialAvatar(
          icon: circleTypeIcon(groupType!),
          tone: circleTypeTone(groupType!),
          size: size,
        );
}

/// Loading and error states for chat reads, like `WorkspaceView`.
class ChatAsyncView<T> extends ConsumerWidget {
  const ChatAsyncView({
    super.key,
    required this.provider,
    required this.builder,
  });
  final ProviderListenable<AsyncValue<T>> provider;
  final Widget Function(T value) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(provider)
      .when(
        skipLoadingOnReload: true,
        data: builder,
        loading: () => const CircleSkeletonPage(label: 'Loading your chats'),
        error: (_, _) => ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleEmpty(
                title: 'Your chats couldn’t load',
                message: 'Try loading the local preview again.',
                action: FilledButton(
                  onPressed: () => ref.invalidate(chatControllerProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      );
}

/// "Muted until 18:30", "Muted for a week", "Muted".
String muteLabel({
  required bool forever,
  required DateTime? until,
  required DateTime now,
}) {
  if (forever) return 'Muted';
  if (until == null) return 'Not muted';
  final left = until.difference(now);
  if (left.inHours >= 24) {
    final days = (left.inHours / 24).ceil();
    return 'Muted for $days ${days == 1 ? 'day' : 'days'}';
  }
  final hours = left.inMinutes <= 60 ? 1 : (left.inMinutes / 60).ceil();
  return 'Muted for $hours ${hours == 1 ? 'hour' : 'hours'}';
}

/// One-tap mute choices (README §4.0). Returns the choice; `unmute` is
/// offered when the chat is already muted.
Future<({ChatMute? mute})?> showMuteSheet(
  BuildContext context, {
  required String title,
  required bool muted,
}) => showModalBottomSheet<({ChatMute? mute})>(
  context: context,
  // Above the shell's navigation bar, so nothing is hidden.
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: Space.section),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.section),
          child: Semantics(
            header: true,
            child: Text(
              'Mute $title',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        for (final option in ChatMute.values)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.section,
            ),
            leading: const Icon(Icons.notifications_paused_outlined),
            title: Text(option.label),
            onTap: () => Navigator.of(context).pop((mute: option)),
          ),
        if (muted)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.section,
            ),
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Unmute'),
            onTap: () => Navigator.of(context).pop((mute: null)),
          ),
      ],
    ),
  ),
);

/// A calm notice inside a conversation (left group, blocked, request).
class ChatNotice extends StatelessWidget {
  const ChatNotice({
    super.key,
    required this.icon,
    required this.message,
    this.actions = const [],
  });
  final IconData icon;
  final String message;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: CircleAccents.of(context).recessed,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: actions),
          ],
        ],
      ),
    );
  }
}
