import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/mock_chat_repository.dart';
import '../domain/chat_repository.dart';

export '../domain/chat_repository.dart';

/// The local mock chat. A new preview session (or ending one) starts from
/// a fresh repository, so every conversation and setting is cleared.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final entered = ref.watch(circlePreviewSessionProvider);
  final showcase =
      entered && ref.read(circlePreviewSessionProvider.notifier).showcase;
  final circle = ref.watch(previewOnlyRepositoryProvider);
  return MockChatRepository(
    groups: circle,
    moderation: circle,
    showcase: showcase,
    now: ref.watch(circleClockProvider),
  );
});

/// Runs chat changes for the current viewer. Its state is a revision
/// number that chat reads watch, so every change refreshes them.
final chatControllerProvider = NotifierProvider<ChatController, int>(
  ChatController.new,
);

/// The inbox. Watches the workspace too: leaving a group changes chats.
final chatInboxProvider = FutureProvider<ChatInbox>((ref) {
  ref.watch(chatControllerProvider);
  ref.watch(circleWorkspaceProvider);
  return ref
      .watch(chatRepositoryProvider)
      .inbox(ref.watch(circleViewerProvider));
});

/// A conversation, or the calm reason it can't be shown.
typedef ConversationLoad = ({ConversationView? view, String? unavailable});

final chatConversationProvider =
    FutureProvider.family<ConversationLoad, String>((ref, id) async {
      ref.watch(chatControllerProvider);
      ref.watch(circleWorkspaceProvider);
      final repository = ref.watch(chatRepositoryProvider);
      final viewer = ref.watch(circleViewerProvider);
      try {
        return (
          view: await repository.conversation(viewer, id),
          unavailable: null,
        );
      } on CircleFailure catch (failure) {
        return (view: null, unavailable: failure.message);
      }
    });

final chatContactsProvider = FutureProvider<List<ChatContactGroup>>((ref) {
  ref.watch(chatControllerProvider);
  ref.watch(circleWorkspaceProvider);
  return ref
      .watch(chatRepositoryProvider)
      .contacts(ref.watch(circleViewerProvider));
});

final chatPrivacyProvider = FutureProvider<ChatPrivacyView>((ref) {
  ref.watch(chatControllerProvider);
  ref.watch(circleWorkspaceProvider);
  return ref
      .watch(chatRepositoryProvider)
      .privacy(ref.watch(circleViewerProvider));
});

/// Something waiting to be shared in a conversation's composer, such as
/// the Memory from "Reply privately". Session-local.
final chatShareDraftsProvider =
    NotifierProvider<ChatShareDrafts, Map<String, SharedContent>>(
      ChatShareDrafts.new,
    );

class ChatShareDrafts extends Notifier<Map<String, SharedContent>> {
  @override
  Map<String, SharedContent> build() {
    ref.watch(chatRepositoryProvider);
    return const {};
  }

  void attach(String conversationId, SharedContent content) =>
      state = {...state, conversationId: content};

  void clear(String conversationId) =>
      state = {...state}..remove(conversationId);
}

class ChatController extends Notifier<int> {
  @override
  int build() {
    ref.watch(chatRepositoryProvider);
    return 0;
  }

  int _clientSequence = 0;

  /// A new idempotency key for one send. Retrying with the same key never
  /// sends twice.
  String newClientMessageId() =>
      'client-${DateTime.now().microsecondsSinceEpoch}-${++_clientSequence}';

  Future<T> _run<T>(Future<T> Function(ChatRepository, String) change) async {
    try {
      return await change(
        ref.read(chatRepositoryProvider),
        ref.read(circleViewerProvider),
      );
    } finally {
      // Refresh even after a failure: something else may have changed.
      if (ref.mounted) state++;
    }
  }

  Future<String> openDirect(String person) =>
      _run((repo, viewer) => repo.openDirect(viewer, person));
  Future<String> send(
    String conversationId, {
    required String clientMessageId,
    String text = '',
    String? replyToId,
    SharedContent? shared,
    PollDraft? poll,
    Map<String, String> mentions = const {},
    List<MemoryScene> photos = const [],
  }) => _run(
    (repo, viewer) => repo.send(
      viewer,
      conversationId,
      clientMessageId: clientMessageId,
      text: text,
      replyToId: replyToId,
      shared: shared,
      poll: poll,
      mentions: mentions,
      photos: photos,
    ),
  );
  Future<ForwardResult> forward(
    String conversationId,
    String messageId, {
    required List<String> to,
    required String clientMessageId,
  }) => _run(
    (repo, viewer) => repo.forward(
      viewer,
      conversationId,
      messageId,
      to: to,
      clientMessageId: clientMessageId,
    ),
  );
  Future<void> edit(String conversationId, String messageId, String text) =>
      _run(
        (repo, viewer) => repo.edit(viewer, conversationId, messageId, text),
      );
  Future<void> unsend(String conversationId, String messageId) =>
      _run((repo, viewer) => repo.unsend(viewer, conversationId, messageId));
  Future<void> restore(String conversationId, String messageId) =>
      _run((repo, viewer) => repo.restore(viewer, conversationId, messageId));
  Future<void> react(String conversationId, String messageId, String emoji) =>
      _run(
        (repo, viewer) => repo.react(viewer, conversationId, messageId, emoji),
      );
  Future<void> report(
    String conversationId, {
    String? messageId,
    required ReportReason reason,
    String? note,
  }) async {
    await _run(
      (repo, viewer) => repo.report(
        viewer,
        conversationId,
        messageId: messageId,
        reason: reason,
        note: note,
      ),
    );
    // The admins' queue lives with the groups; refresh what depends on it.
    ref.invalidate(circleWorkspaceProvider);
  }

  Future<void> markRead(String conversationId) =>
      _run((repo, viewer) => repo.markRead(viewer, conversationId));
  Future<void> setPinned(String conversationId, bool pinned) =>
      _run((repo, viewer) => repo.setPinned(viewer, conversationId, pinned));
  Future<void> mute(String conversationId, ChatMute? mute) =>
      _run((repo, viewer) => repo.mute(viewer, conversationId, mute));
  Future<void> setArchived(String conversationId, bool archived) => _run(
    (repo, viewer) => repo.setArchived(viewer, conversationId, archived),
  );
  Future<void> acceptRequest(String conversationId) =>
      _run((repo, viewer) => repo.acceptRequest(viewer, conversationId));
  Future<void> deleteRequest(String conversationId) =>
      _run((repo, viewer) => repo.deleteRequest(viewer, conversationId));
  Future<void> restoreRequest(String conversationId) =>
      _run((repo, viewer) => repo.restoreRequest(viewer, conversationId));
  Future<void> block(String person) =>
      _run((repo, viewer) => repo.block(viewer, person));
  Future<void> unblock(String person) =>
      _run((repo, viewer) => repo.unblock(viewer, person));
  Future<void> setWhoCanMessage(WhoCanMessage value) =>
      _run((repo, viewer) => repo.setWhoCanMessage(viewer, value));
  Future<void> setCloseGroup(String groupId, bool close) =>
      _run((repo, viewer) => repo.setCloseGroup(viewer, groupId, close));
  Future<void> setShowActivity(bool show) =>
      _run((repo, viewer) => repo.setShowActivity(viewer, show));
  Future<void> votePoll(
    String conversationId,
    String messageId,
    Set<String> optionIds,
  ) => _run(
    (repo, viewer) =>
        repo.votePoll(viewer, conversationId, messageId, optionIds),
  );
  Future<void> retractPollVote(String conversationId, String messageId) => _run(
    (repo, viewer) => repo.retractPollVote(viewer, conversationId, messageId),
  );
  Future<void> closePoll(String conversationId, String messageId) =>
      _run((repo, viewer) => repo.closePoll(viewer, conversationId, messageId));
}
