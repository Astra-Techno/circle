import '../../moderation/domain/moderation.dart';
import 'chat_rules.dart';

export '../../../core/circle_failure.dart';
export '../../moderation/domain/moderation.dart'
    show ReportReason, ReportKind, ReportTarget, ModerationRules;
export 'chat_rules.dart';

/// Group and 1:1 chat (README §3.2, ADR 0003). Every method is
/// asynchronous so a real-time service can replace the local mock. Every
/// read and change re-checks the viewer's exact membership; failures are
/// [CircleFailure]s with calm copy.
abstract interface class ChatRepository {
  /// Chats, Requests and Archived for [viewer].
  Future<ChatInbox> inbox(String viewer);

  Future<ConversationView> conversation(String viewer, String conversationId);

  /// People who share a group with [viewer], grouped by group, with
  /// whether each can be messaged.
  Future<List<ChatContactGroup>> contacts(String viewer);

  /// Opens (or creates) the 1:1 conversation with [person]. Fails calmly
  /// when [person] can't be messaged. Returns the conversation id.
  Future<String> openDirect(String viewer, String person);

  /// Sends a message. A repeated [clientMessageId] returns the first
  /// message's id without sending again. [mentions] (group chats only)
  /// keeps members of the group whose "@Name" is in the text; [photos] are
  /// up to 10 fictional scenes. Returns the message id.
  Future<String> send(
    String viewer,
    String conversationId, {
    required String clientMessageId,
    String text = '',
    String? replyToId,
    SharedContent? shared,
    PollDraft? poll,
    Map<String, String> mentions = const {},
    List<MemoryScene> photos = const [],
  });

  /// Forwards a message the viewer can read to up to 5 chats (see
  /// [ForwardRules]). Targets the viewer can't post in, or where not
  /// everyone can see a shared card, are skipped with a calm reason.
  /// Retrying with the same [clientMessageId] never sends twice.
  Future<ForwardResult> forward(
    String viewer,
    String conversationId,
    String messageId, {
    required List<String> to,
    required String clientMessageId,
  });

  /// Author only, within 15 minutes. Marks the message "Edited".
  Future<void> edit(
    String viewer,
    String conversationId,
    String messageId,
    String text,
  );

  /// Author only. Removes the message for everyone; [restore] undoes it.
  Future<void> unsend(String viewer, String conversationId, String messageId);
  Future<void> restore(String viewer, String conversationId, String messageId);

  /// Sets the viewer's reaction; the same emoji again removes it.
  Future<void> react(
    String viewer,
    String conversationId,
    String messageId,
    String emoji,
  );

  /// Reports a message (group chats: to that group's admins) or, without
  /// [messageId], the other person of a 1:1 chat. Local preview: nothing
  /// leaves the device.
  Future<void> report(
    String viewer,
    String conversationId, {
    String? messageId,
    required ReportReason reason,
    String? note,
  });

  /// Every text message [viewer] can read right now: current chats,
  /// requests, archived chats, and the frozen history of groups they left.
  /// Used by search; nothing beyond what the viewer can open.
  Future<List<ReadableMessage>> readableMessages(String viewer);

  Future<void> markRead(String viewer, String conversationId);
  Future<void> setPinned(String viewer, String conversationId, bool pinned);

  /// Null unmutes.
  Future<void> mute(String viewer, String conversationId, ChatMute? mute);
  Future<void> setArchived(String viewer, String conversationId, bool archived);

  Future<void> acceptRequest(String viewer, String conversationId);

  /// Hides the request; [restoreRequest] undoes it.
  Future<void> deleteRequest(String viewer, String conversationId);
  Future<void> restoreRequest(String viewer, String conversationId);

  Future<void> block(String viewer, String person);
  Future<void> unblock(String viewer, String person);

  Future<ChatPrivacyView> privacy(String viewer);
  Future<void> setWhoCanMessage(String viewer, WhoCanMessage value);
  Future<void> setCloseGroup(String viewer, String groupId, bool close);

  /// "Show activity status". Reciprocal: off also hides others' from you.
  Future<void> setShowActivity(String viewer, bool show);

  Future<void> votePoll(
    String viewer,
    String conversationId,
    String messageId,
    Set<String> optionIds,
  );
  Future<void> retractPollVote(
    String viewer,
    String conversationId,
    String messageId,
  );
  Future<void> closePoll(
    String viewer,
    String conversationId,
    String messageId,
  );

  /// Local preview only: discards every conversation and setting.
  Future<void> reset({required bool showcase});
}
