/// Chat models (README §3.2, ADR 0003). Pure Dart; no Flutter imports.
library;

import '../../events/domain/circle_event.dart';
import '../../groups/domain/circle_group.dart';
import '../../memories/domain/circle_memory.dart';

export '../../../core/rule_result.dart';
export '../../events/domain/circle_event.dart';
export '../../groups/domain/circle_group.dart';
export '../../memories/domain/circle_memory.dart';

enum ConversationKind { group, direct }

/// "Who can message me" (README §3.2). Applies to 1:1 chats only; group
/// chats always follow group membership.
enum WhoCanMessage {
  everyoneInMyGroups(
    'Everyone in my groups',
    'Anyone who shares a group with you. First messages from outside your '
        'close groups wait in Requests.',
  ),
  onlyPeopleIChattedWith(
    'Only people I’ve chatted with',
    'New people can’t start a chat with you.',
  ),
  nobody('Nobody', 'No one can send you 1:1 messages.');

  const WhoCanMessage(this.label, this.description);
  final String label, description;
}

/// One-tap mute lengths (README §4.0).
enum ChatMute {
  eightHours(Duration(hours: 8), 'For 8 hours'),
  oneWeek(Duration(days: 7), 'For 1 week'),
  always(null, 'Until I turn it back on');

  const ChatMute(this.length, this.label);
  final Duration? length;
  final String label;
}

enum SharedKind { memory, event }

/// A Memory or event shared into a chat. Only the id travels: whoever
/// reads the message sees the item only if they already have access.
class SharedContent {
  const SharedContent.memory(this.id) : kind = SharedKind.memory;
  const SharedContent.event(this.id) : kind = SharedKind.event;
  final SharedKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is SharedContent && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// A message as stored, with everyone's reactions.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.clientMessageId,
    required this.createdAt,
    this.text = '',
    this.editedAt,
    this.unsentAt,
    this.replyToId,
    Map<String, String> reactions = const {},
    this.shared,
    this.poll,
    Map<String, String> mentions = const {},
    List<MemoryPhoto> photos = const [],
    this.forwarded = false,
  }) : reactions = Map.unmodifiable(reactions),
       mentions = Map.unmodifiable(mentions),
       photos = List.unmodifiable(photos);

  final String id, conversationId, authorId;

  /// Chosen by the sending device; a repeated send with the same id is
  /// ignored, so retries never create duplicates.
  final String clientMessageId;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt, unsentAt;
  final String? replyToId;

  /// Person → their one reaction from the 8-emoji allowlist.
  final Map<String, String> reactions;
  final SharedContent? shared;
  final Poll? poll;

  /// Group chats: people mentioned with "@Name" (person id → name as
  /// written), only members of the group when it was sent.
  final Map<String, String> mentions;

  /// Fictional illustrated photos (up to 10), shown as a grid.
  final List<MemoryPhoto> photos;

  /// Forwarded from another chat (shows a small "Forwarded" label).
  final bool forwarded;

  bool get unsent => unsentAt != null;

  ChatMessage copyWith({
    String? text,
    DateTime? editedAt,
    DateTime? unsentAt,
    bool restore = false,
    Map<String, String>? reactions,
    Poll? poll,
    Map<String, String>? mentions,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    authorId: authorId,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    text: text ?? this.text,
    editedAt: editedAt ?? this.editedAt,
    unsentAt: restore ? null : unsentAt ?? this.unsentAt,
    replyToId: replyToId,
    reactions: reactions ?? this.reactions,
    shared: shared,
    poll: poll ?? this.poll,
    mentions: mentions ?? this.mentions,
    photos: photos,
    forwarded: forwarded,
  );
}

/// One person's 1:1 privacy settings (README §3.2, H3 subset).
class ChatPrivacy {
  ChatPrivacy({
    this.whoCanMessage = WhoCanMessage.everyoneInMyGroups,
    Map<String, bool> closeGroups = const {},
    Set<String> blocked = const {},
    this.showActivity = true,
  }) : closeGroups = Map.unmodifiable(closeGroups),
       blocked = Set.unmodifiable(blocked);

  final WhoCanMessage whoCanMessage;

  /// Explicit choices per group id; groups without a choice use the size
  /// default (see `ChatRules.isCloseGroup`).
  final Map<String, bool> closeGroups;
  final Set<String> blocked;

  /// "Show activity status" (on by default). Reciprocal: when off, others
  /// can't see when this person was last active, and they can't see
  /// anyone's (see `ActivityRules.canSee`).
  final bool showActivity;

  ChatPrivacy copyWith({
    WhoCanMessage? whoCanMessage,
    Map<String, bool>? closeGroups,
    Set<String>? blocked,
    bool? showActivity,
  }) => ChatPrivacy(
    whoCanMessage: whoCanMessage ?? this.whoCanMessage,
    closeGroups: closeGroups ?? this.closeGroups,
    blocked: blocked ?? this.blocked,
    showActivity: showActivity ?? this.showActivity,
  );
}

/// Why a 1:1 chat can or can't be started.
enum DirectEligibility {
  allowed,
  self,
  noSharedGroup,
  blockedByYou,

  /// The other person blocked you, or accepts no messages. Shown the same
  /// way, so a block is never revealed.
  notAccepting,
  onlyChattedWith,
}

// ------------------------------------------------------------------ views

/// A row in the inbox, already projected for one viewer.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.preview,
    this.groupId,
    this.groupType,
    this.otherId,
    this.memberCount = 0,
    this.lastActivity,
    this.unread = false,
    this.pinned = false,
    this.mutedUntil,
    this.mutedForever = false,
    this.archived = false,
    this.request = false,
    this.readOnly = false,
    this.activity,
    this.activeNow = false,
    this.mutedByDefault = false,
    this.canPost = false,
  });
  final String id, title;
  final ConversationKind kind;

  /// Whether the viewer can send messages here right now (not left, not
  /// a pending request, not blocked either way).
  final bool canPost;

  /// Muted only because it is a big group (quiet by default), not by the
  /// person's own choice.
  final bool mutedByDefault;

  /// 1:1 only: the other person's activity ("Active now", "Active 2h
  /// ago") when the viewer may see it; null otherwise.
  final String? activity;

  /// 1:1 only: the other person is active now (the avatar's dot).
  final bool activeNow;

  /// "Mira: See you Sunday · 2h", "Seen", "Sent 2h", "No messages yet".
  final String preview;
  final String? groupId, otherId;
  final CircleType? groupType;
  final int memberCount;
  final DateTime? lastActivity;
  final bool unread, pinned, mutedForever, archived, request, readOnly;
  final DateTime? mutedUntil;

  bool get muted => mutedForever || mutedUntil != null;
  bool get isGroup => kind == ConversationKind.group;
}

class ChatInbox {
  ChatInbox({
    required List<ConversationSummary> chats,
    required List<ConversationSummary> requests,
    required List<ConversationSummary> archived,
  }) : chats = List.unmodifiable(chats),
       requests = List.unmodifiable(requests),
       archived = List.unmodifiable(archived);
  final List<ConversationSummary> chats, requests, archived;
}

/// The message a reply points to, as a short quote.
class ReplyPreview {
  const ReplyPreview({
    required this.messageId,
    required this.authorName,
    required this.text,
  });
  final String messageId, authorName, text;
}

/// A shared Memory or event as the viewer may see it. When [visible] is
/// false the viewer has no access and only the kind is known.
class SharedView {
  const SharedView({
    required this.content,
    required this.visible,
    this.memory,
    this.event,
    this.group,
    this.audience,
  });
  final SharedContent content;
  final bool visible;
  final CircleMemory? memory;
  final CircleEvent? event;
  final CircleGroup? group;

  /// "Root › Group" for the item's group.
  final String? audience;
}

class MessageView {
  const MessageView({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.mine,
    required this.reactions,
    this.edited = false,
    this.unsent = false,
    this.hidden = false,
    this.hiddenByAdmins = false,
    this.replyTo,
    this.shared,
    this.poll,
    this.editableUntil,
    this.canUnsend = false,
    this.mentions = const {},
    this.photos = const [],
    this.forwarded = false,
    this.canForward = false,
  });
  final String id, authorId, authorName, text;
  final DateTime createdAt;
  final bool mine, edited, unsent, canUnsend;

  /// "@Name" mentions in [text] (person id → name as written).
  final Map<String, String> mentions;

  /// Photos in this message (grid bubble).
  final List<MemoryPhoto> photos;

  /// Forwarded from another chat.
  final bool forwarded;

  /// Whether "Forward" is offered (text or a shared card; never polls,
  /// photos or unsent messages).
  final bool canForward;

  /// Set when the viewer may edit this message, until this time.
  final DateTime? editableUntil;

  /// Whether the viewer may still edit at [now] (the 15-minute window).
  bool canEditAt(DateTime now) =>
      editableUntil != null && !now.isAfter(editableUntil!);

  /// From someone the viewer blocked (group chats): content is not shown.
  final bool hidden;

  /// Hidden by the group's admins after a report. Only admins still get
  /// such messages (marked); everyone else no longer receives them.
  final bool hiddenByAdmins;
  final MemoryReactions reactions;
  final ReplyPreview? replyTo;
  final SharedView? shared;
  final PollView? poll;

  bool get interactive => !unsent && !hidden;

  /// One line for previews and quotes.
  String get summary {
    if (unsent) return 'Message unsent';
    if (hidden) return 'Message from someone you blocked';
    if (text.isNotEmpty) return text;
    if (poll != null) return 'Poll: ${poll!.question}';
    if (photos.isNotEmpty) return photoSummary(photos.length);
    if (shared != null) {
      return shared!.content.kind == SharedKind.memory
          ? 'Shared a Memory'
          : 'Shared an event';
    }
    return '';
  }
}

/// What the viewer may do in a conversation right now.
enum ConversationMode {
  /// Read and write.
  active,

  /// Someone's first message waiting for the viewer: Accept, Delete, Block.
  incomingRequest,

  /// The viewer left the group: earlier messages only, read-only.
  leftGroup,

  /// The viewer blocked the other person.
  blockedByYou,

  /// The other person can't receive messages (not shown why).
  cannotReply,
}

class ChatMember {
  const ChatMember({required this.id, required this.name, this.role});
  final String id, name;
  final CircleRole? role;
}

class ConversationView {
  ConversationView({
    required this.id,
    required this.kind,
    required this.title,
    required this.mode,
    required List<MessageView> messages,
    this.groupId,
    this.groupType,
    this.otherId,
    List<ChatMember> members = const [],
    List<String> sharedGroups = const [],
    List<String> participants = const [],
    this.activity,
    this.status,
    this.statusMessageId,
    this.statusSemantics,
    this.pinned = false,
    this.mutedUntil,
    this.mutedForever = false,
    this.archived = false,
    this.otherBlocked = false,
  }) : messages = List.unmodifiable(messages),
       members = List.unmodifiable(members),
       sharedGroups = List.unmodifiable(sharedGroups),
       participants = List.unmodifiable(participants);

  final String id, title;
  final ConversationKind kind;
  final ConversationMode mode;

  /// Everyone currently in the chat, including the viewer: both people of
  /// a 1:1, or the group's active members. Empty after leaving a group.
  final List<String> participants;

  /// 1:1 only: the other person's activity when the viewer may see it.
  final String? activity;

  /// Oldest first.
  final List<MessageView> messages;
  final String? groupId, otherId;
  final CircleType? groupType;

  /// Current group members (group chats).
  final List<ChatMember> members;

  /// Names of groups the viewer shares with the other person (1:1).
  final List<String> sharedGroups;

  /// "Sent", "Seen", "Seen by Mira, Dev +3" under [statusMessageId], the
  /// viewer's last message.
  final String? status, statusMessageId, statusSemantics;
  final bool pinned, mutedForever, archived;
  final DateTime? mutedUntil;

  /// Whether the viewer blocked the other person (1:1).
  final bool otherBlocked;

  bool get isGroup => kind == ConversationKind.group;
  bool get muted => mutedForever || mutedUntil != null;
  bool get canSend => mode == ConversationMode.active;

  /// Shared Memories and events, newest first, for chat details.
  List<SharedView> get sharedItems => [
    for (final message in messages.reversed)
      if (message.shared != null && message.interactive) message.shared!,
  ];
}

/// Someone the viewer could start a 1:1 chat with, in one shared group.
class ChatContact {
  const ChatContact({
    required this.personId,
    required this.name,
    required this.eligibility,
    this.activity,
  });
  final String personId, name;
  final DirectEligibility eligibility;

  /// "Active now", "Active 2h ago" when the viewer may see it.
  final String? activity;
  bool get canMessage => eligibility == DirectEligibility.allowed;
}

class ChatContactGroup {
  ChatContactGroup({required this.group, required List<ChatContact> contacts})
    : contacts = List.unmodifiable(contacts);
  final CircleGroup group;
  final List<ChatContact> contacts;
}

class BlockedPerson {
  const BlockedPerson({required this.id, required this.name});
  final String id, name;
}

/// The viewer's privacy screen: settings plus the groups they apply to.
class ChatPrivacyView {
  ChatPrivacyView({
    required this.settings,
    required List<CircleGroup> groups,
    required List<BlockedPerson> blocked,
  }) : groups = List.unmodifiable(groups),
       blocked = List.unmodifiable(blocked);
  final ChatPrivacy settings;
  final List<CircleGroup> groups;
  final List<BlockedPerson> blocked;
}

/// "Sent a photo" / "Sent 3 photos", for previews and quotes.
String photoSummary(int count) =>
    count == 1 ? 'Sent a photo' : 'Sent $count photos';

/// One readable text message, for search and Activity (mentions).
class ReadableMessage {
  const ReadableMessage({
    required this.conversationId,
    required this.conversationTitle,
    required this.messageId,
    required this.authorName,
    required this.text,
    required this.at,
    this.authorId = '',
    this.groupId,
    this.mentions = const {},
  });
  final String conversationId, conversationTitle, messageId, authorName, text;
  final DateTime at;
  final String authorId;

  /// The group of a group chat.
  final String? groupId;

  /// People mentioned in it (ids).
  final Set<String> mentions;
}

/// Why one chosen chat didn't get a forwarded message.
class ForwardSkip {
  const ForwardSkip({
    required this.conversationId,
    required this.title,
    required this.reason,
  });
  final String conversationId, title, reason;
}

/// What happened to a forward: chats it reached and calm notes for the
/// ones it skipped.
class ForwardResult {
  ForwardResult({
    required List<String> sentTo,
    required List<String> sentTitles,
    required List<ForwardSkip> skipped,
  }) : sentTo = List.unmodifiable(sentTo),
       sentTitles = List.unmodifiable(sentTitles),
       skipped = List.unmodifiable(skipped);
  final List<String> sentTo, sentTitles;
  final List<ForwardSkip> skipped;
}
