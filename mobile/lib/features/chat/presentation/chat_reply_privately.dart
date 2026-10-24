import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/chat_providers.dart';

/// "Reply privately" on a Memory: opens (or creates) the 1:1 chat with its
/// author with the Memory ready to share, or calmly explains why not.
class ChatReplyPrivately extends ConsumerStatefulWidget {
  const ChatReplyPrivately({super.key, required this.memoryId});
  final String memoryId;
  @override
  ConsumerState<ChatReplyPrivately> createState() => _ChatReplyPrivatelyState();
}

class _ChatReplyPrivatelyState extends ConsumerState<ChatReplyPrivately> {
  String? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final router = GoRouter.of(context);
    final workspace = await ref.read(circleWorkspaceProvider.future);
    final memory = workspace.memories
        .where((item) => item.id == widget.memoryId)
        .firstOrNull;
    if (!mounted) return;
    if (memory == null) {
      setState(() => _problem = 'This Memory isn’t shared with you.');
      return;
    }
    if (memory.authorId == workspace.viewer) {
      setState(() => _problem = 'This is your own Memory.');
      return;
    }
    try {
      final id = await ref
          .read(chatControllerProvider.notifier)
          .openDirect(memory.authorId);
      ref
          .read(chatShareDraftsProvider.notifier)
          .attach(id, SharedContent.memory(memory.id));
      router.go('/chats/c/$id');
    } on CircleFailure catch (failure) {
      if (mounted) {
        setState(
          () => _problem =
              '${failure.message} You can comment on the Memory instead.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          if (problem == null)
            Semantics(
              label: 'Opening your chat',
              child: const LinearProgressIndicator(),
            )
          else
            CircleEmpty(
              title: 'You can’t reply privately here',
              message: problem,
              action: OutlinedButton(
                onPressed: () => context.go('/home/memory/${widget.memoryId}'),
                child: const Text('Back to the Memory'),
              ),
            ),
        ],
      ),
    );
  }
}
