import 'chat_models.dart';

export 'activity_rules.dart';
export 'chat_models.dart';

const _ok = RuleResult.allowed();

/// Pure chat rules (README §3.2, ADR 0003) shared by the repository and
/// the UI. Membership is always the exact group; nothing is inherited.
abstract final class ChatRules {
  static const maxText = 4000;
  static const editWindow = Duration(minutes: 15);

  /// Groups this size or smaller skip Requests unless the person changes it.
  static const closeGroupMaxMembers = 50;

  /// Group chats above this size start muted ("big groups are quiet").
  static const quietGroupMinMembers = 51;

  /// Messages closer than this (same author, no time separator) form one
  /// visual run of bubbles.
  static const runGap = Duration(minutes: 5);

  /// A time separator appears before a message after this much silence.
  static const separatorGap = Duration(hours: 1);

  static String directId(String a, String b) {
    final pair = [a, b]..sort();
    return 'd-${pair.first}-${pair.last}';
  }

  static String groupConversationId(String groupId) => 'g-$groupId';

  // ------------------------------------------------------------- content

  /// Text is 1–4000 characters, or may be empty when the message carries
  /// a shared card, photos or a poll.
  static RuleResult checkText(String text, {bool hasAttachment = false}) {
    final value = text.trim();
    if (value.runes.length > maxText) {
      return const RuleResult.denied('Write up to 4000 characters.');
    }
    if (value.isEmpty && !hasAttachment) {
      return const RuleResult.denied('Write a message first.');
    }
    return _ok;
  }

  /// Returns the existing message when [clientMessageId] was already sent
  /// by [author], so a retried send is ignored.
  static ChatMessage? duplicateOf(
    Iterable<ChatMessage> messages,
    String author,
    String clientMessageId,
  ) => messages
      .where(
        (m) => m.authorId == author && m.clientMessageId == clientMessageId,
      )
      .firstOrNull;

  // -------------------------------------------------- groups and 1:1 access

  /// Close groups skip Requests. By default every group with at most 50
  /// members is close; the person can mark any group close or not.
  static bool isCloseGroup(CircleGroup group, ChatPrivacy privacy) =>
      privacy.closeGroups[group.id] ??
      group.roles.length <= closeGroupMaxMembers;

  /// Groups both people are active members of.
  static List<CircleGroup> sharedGroups(
    Iterable<CircleGroup> groups,
    String a,
    String b,
  ) => [
    for (final group in groups)
      if (group.isMember(a) && group.isMember(b)) group,
  ];

  /// Whether [sender] may send a 1:1 message to [recipient] (README §3.2):
  /// they share at least one group, neither blocked the other, and the
  /// recipient's "who can message me" setting allows it. [haveChatted]
  /// means the recipient already took part in a conversation with the
  /// sender (sent a message there or accepted the request).
  static DirectEligibility directEligibility({
    required String sender,
    required String recipient,
    required List<CircleGroup> shared,
    required ChatPrivacy senderPrivacy,
    required ChatPrivacy recipientPrivacy,
    required bool haveChatted,
  }) {
    if (sender == recipient) return DirectEligibility.self;
    if (senderPrivacy.blocked.contains(recipient)) {
      return DirectEligibility.blockedByYou;
    }
    if (recipientPrivacy.blocked.contains(sender)) {
      return DirectEligibility.notAccepting;
    }
    if (shared.isEmpty) return DirectEligibility.noSharedGroup;
    return switch (recipientPrivacy.whoCanMessage) {
      WhoCanMessage.everyoneInMyGroups => DirectEligibility.allowed,
      WhoCanMessage.onlyPeopleIChattedWith =>
        haveChatted
            ? DirectEligibility.allowed
            : DirectEligibility.onlyChattedWith,
      WhoCanMessage.nobody => DirectEligibility.notAccepting,
    };
  }

  /// The short reason shown on a disabled row in New chat.
  static String? eligibilityReason(DirectEligibility eligibility) =>
      switch (eligibility) {
        DirectEligibility.allowed => null,
        DirectEligibility.self => 'This is you',
        DirectEligibility.noSharedGroup => 'You no longer share a group',
        DirectEligibility.blockedByYou => 'You blocked them',
        DirectEligibility.notAccepting => 'Isn’t accepting messages',
        DirectEligibility.onlyChattedWith =>
          'Only accepts messages from people they’ve chatted with',
      };

  /// A calm sentence naming the person, for snackbars and empty states.
  static String eligibilityMessage(
    DirectEligibility eligibility,
    String name,
  ) => switch (eligibility) {
    DirectEligibility.allowed => '',
    DirectEligibility.self => 'You can’t message yourself.',
    DirectEligibility.noSharedGroup =>
      'You can message people who share a group with you.',
    DirectEligibility.blockedByYou =>
      'You blocked $name. Unblock them to send a message.',
    DirectEligibility.notAccepting =>
      '$name isn’t accepting messages right now.',
    DirectEligibility.onlyChattedWith =>
      '$name only accepts messages from people they’ve chatted with.',
  };

  /// A first message from someone the recipient has never chatted with
  /// waits in Requests, unless they share one of the recipient's close
  /// groups. Group chats never use Requests.
  static bool needsRequest({
    required List<CircleGroup> shared,
    required ChatPrivacy recipientPrivacy,
    required bool haveChatted,
  }) =>
      !haveChatted &&
      !shared.any((group) => isCloseGroup(group, recipientPrivacy));

  /// Group chats mirror the group: only active members post.
  static RuleResult canPostInGroup(CircleGroup? group, String person) =>
      group != null && group.isMember(person)
      ? _ok
      : const RuleResult.denied(
          'You left this group, so you can’t send messages here.',
        );

  // ------------------------------------------------------ message changes

  static RuleResult canEdit(ChatMessage message, String actor, DateTime now) {
    if (message.authorId != actor) {
      return const RuleResult.denied('You can only edit your own messages.');
    }
    if (message.unsent) {
      return const RuleResult.denied('This message was unsent.');
    }
    if (message.text.isEmpty) {
      return const RuleResult.denied('Only text can be edited.');
    }
    if (now.difference(message.createdAt) > editWindow) {
      return const RuleResult.denied(
        'Messages can be edited for 15 minutes after sending.',
      );
    }
    return _ok;
  }

  /// Unsend removes the message for everyone; the author may do it any
  /// time.
  static RuleResult canUnsend(ChatMessage message, String actor) {
    if (message.authorId != actor) {
      return const RuleResult.denied('You can only unsend your own messages.');
    }
    if (message.unsent) {
      return const RuleResult.denied('This message was already unsent.');
    }
    return _ok;
  }

  /// Undo of an unsend, by the author.
  static RuleResult canRestore(ChatMessage message, String actor) =>
      message.authorId == actor && message.unsent
      ? _ok
      : const RuleResult.denied('This message can’t be restored.');

  /// Reactions use the Memories allowlist; one per person, the same emoji
  /// again removes it.
  static RuleResult canReact(ChatMessage message, String emoji) {
    if (message.unsent) {
      return const RuleResult.denied('This message was unsent.');
    }
    return ReactionRules.check(emoji);
  }

  // ------------------------------------------------------- shared content

  /// Sharing never grants access: the reader sees the card only when they
  /// can already see the item.
  static RuleResult canSeeShared(
    SharedContent content, {
    required bool visible,
  }) => visible
      ? _ok
      : RuleResult.denied(
          content.kind == SharedKind.memory
              ? 'This Memory isn’t shared with you'
              : 'This event isn’t shared with you',
        );

  /// Whether everyone in a chat can already see an item of [itemGroup]:
  /// every current participant ([participants]: both people of a 1:1, or
  /// every member of a group chat's group) is an active member of the
  /// item's exact group. Only such items are offered for sharing.
  static bool everyoneCanSee(
    CircleGroup? itemGroup,
    Iterable<String> participants,
  ) =>
      itemGroup != null &&
      participants.isNotEmpty &&
      participants.every(itemGroup.isMember);

  /// The repository's check before a share is sent.
  static RuleResult canShareInto(
    CircleGroup? itemGroup,
    Iterable<String> participants,
  ) => everyoneCanSee(itemGroup, participants)
      ? _ok
      : const RuleResult.denied(
          'You can only share things everyone in this chat can see.',
        );

  // ---------------------------------------------------------------- status

  /// 1:1 status of the viewer's message. The sender of a request sees
  /// "Seen" only after it is accepted.
  static String directStatus({
    required DateTime sentAt,
    required DateTime? otherReadAt,
    required bool accepted,
  }) => accepted && otherReadAt != null && !otherReadAt.isBefore(sentAt)
      ? 'Seen'
      : 'Sent';

  /// "Sent", "Seen by Mira", "Seen by Mira, Dev", "Seen by Mira, Dev +3".
  /// [seenBy] lists names in the order they read the message.
  static String groupStatus(List<String> seenBy) {
    if (seenBy.isEmpty) return 'Sent';
    final shown = seenBy.take(2).join(', ');
    final more = seenBy.length - 2;
    return more > 0 ? 'Seen by $shown +$more' : 'Seen by $shown';
  }

  /// Spoken version of [groupStatus]: "Seen by 5 people: Mira, Dev and 3
  /// more".
  static String groupStatusSemantics(List<String> seenBy) {
    if (seenBy.isEmpty) return 'Sent, not seen yet';
    final count = seenBy.length;
    final people = count == 1 ? '1 person' : '$count people';
    final shown = seenBy.take(2).join(count == 2 ? ' and ' : ', ');
    final more = count - 2;
    return 'Seen by $people: $shown${more > 0 ? ' and $more more' : ''}';
  }

  /// Compact age for the inbox: "now", "5m", "2h", "3d", "2w".
  static String shortAge(DateTime at, DateTime now) {
    final age = now.difference(at);
    if (age.inMinutes < 1) return 'now';
    if (age.inHours < 1) return '${age.inMinutes}m';
    if (age.inDays < 1) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    return '${age.inDays ~/ 7}w';
  }

  /// The inbox line when the viewer sent the last message: "Seen" or
  /// "Sent 2h" (README §3.2).
  static String ownLastLine(String status, DateTime sentAt, DateTime now) =>
      status == 'Sent' ? 'Sent ${shortAge(sentAt, now)}' : status;

  /// Whether a mute is still in effect.
  static bool isMuted({
    required bool forever,
    required DateTime? until,
    required DateTime now,
  }) => forever || (until != null && now.isBefore(until));

  /// Large group chats start muted until the person decides otherwise.
  static bool quietByDefault(int memberCount) =>
      memberCount >= quietGroupMinMembers;

  /// Whether [next] starts a new bubble run after [previous].
  static bool continuesRun(MessageView previous, MessageView next) =>
      previous.authorId == next.authorId &&
      !needsSeparator(previous.createdAt, next.createdAt) &&
      next.createdAt.difference(previous.createdAt) < runGap;

  static bool needsSeparator(DateTime? previous, DateTime next) =>
      previous == null || next.difference(previous) >= separatorGap;

  /// "Today 14:05", "Yesterday 09:30", "12 Oct 18:00" in local time.
  static String separatorLabel(DateTime at, DateTime now) {
    final local = at.toLocal(), today = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    final day = DateTime(local.year, local.month, local.day);
    final current = DateTime(today.year, today.month, today.day);
    final days = current.difference(day).inDays;
    if (days == 0) return 'Today $time';
    if (days == 1) return 'Yesterday $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} $time';
  }
}

/// Photos in chat: fictional scenes in the preview, up to 10 a message.
abstract final class ChatPhotoRules {
  static const maxPhotos = MemoryRules.maxPhotos;

  static RuleResult check(int count) => count > maxPhotos
      ? const RuleResult.denied('Send up to 10 photos at once.')
      : _ok;
}

/// Forwarding a chat message (README §3.2): text and shared Memory or
/// event cards only, to up to 5 chats the viewer can post in. A shared
/// card goes only where everyone can already see the item.
abstract final class ForwardRules {
  static const maxTargets = 5;

  /// Whether [message] can be forwarded at all.
  static RuleResult canForward(ChatMessage message) {
    if (message.unsent) {
      return const RuleResult.denied('This message was unsent.');
    }
    if (message.poll != null) {
      return const RuleResult.denied('Polls can’t be forwarded.');
    }
    if (message.photos.isNotEmpty) {
      return const RuleResult.denied('Photos can’t be forwarded yet.');
    }
    if (message.text.trim().isEmpty && message.shared == null) {
      return const RuleResult.denied('There’s nothing to forward.');
    }
    return _ok;
  }

  /// 1 to 5 different chats.
  static RuleResult checkTargets(Iterable<String> targets) {
    final count = targets.toSet().length;
    if (count == 0) {
      return const RuleResult.denied('Choose a chat to forward to.');
    }
    if (count > maxTargets) {
      return const RuleResult.denied('Forward to up to 5 chats at once.');
    }
    return _ok;
  }

  /// Why one target is skipped, or null to send. [canPost] is whether the
  /// viewer can write there now (not left or frozen, DM eligibility,
  /// blocks); [everyoneCanSee] is the UI-5 share rule for a card.
  static String? skipReason({
    required bool canPost,
    required SharedContent? shared,
    required bool everyoneCanSee,
  }) {
    if (!canPost) return 'you can’t send messages there right now';
    if (shared != null && !everyoneCanSee) {
      return shared.kind == SharedKind.memory
          ? 'not everyone there can see this Memory'
          : 'not everyone there can see this event';
    }
    return null;
  }

  /// "Forwarded to Mira." / "Forwarded to 3 chats. Not sent to Studio
  /// North: not everyone there can see this Memory."
  static String summary(ForwardResult result) {
    final parts = <String>[
      if (result.sentTitles.length == 1)
        'Forwarded to ${result.sentTitles.single}.'
      else if (result.sentTitles.length > 1)
        'Forwarded to ${result.sentTitles.length} chats.',
      for (final skip in result.skipped)
        'Not sent to ${skip.title}: ${skip.reason}.',
    ];
    return parts.join(' ');
  }
}
