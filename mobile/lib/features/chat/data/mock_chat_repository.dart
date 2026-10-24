import '../../groups/domain/group_tree.dart';
import '../../workspace/domain/circle_repository.dart';
import '../domain/chat_repository.dart';

/// Session-local, fictional chat. Nothing is sent, received or persisted,
/// and nothing arrives on its own: the only "replies" from other people
/// are the pre-seeded ones. Group membership always comes from
/// [WorkspaceReader], so every read and change re-checks exact membership.
class MockChatRepository implements ChatRepository {
  MockChatRepository({
    required WorkspaceReader groups,
    ModerationRepository? moderation,
    bool showcase = false,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _workspace = groups,
       _reportsTo = moderation {
    _seed(showcase: showcase);
  }

  final WorkspaceReader _workspace;

  /// Where reports go (the group's admins, or the platform for 1:1).
  final ModerationRepository? _reportsTo;
  final DateTime Function() _now;
  final Map<String, _Conversation> _conversations = {};
  final Map<String, ChatPrivacy> _privacy = {};
  final Map<String, String> _names = {};

  /// When each person was last active. Fictional and static: seeded once,
  /// except that the viewer is active "now" whenever they use the preview.
  /// Nothing changes on a timer.
  final Map<String, DateTime> _lastActive = {};

  /// Local reports (README §3.8); a real backend would queue them for the
  /// group's admins.
  final List<
    ({
      String reporter,
      String conversationId,
      String? messageId,
      ReportReason reason,
    })
  >
  reports = [];
  int _sequence = 0;

  @override
  Future<void> reset({required bool showcase}) async =>
      _seed(showcase: showcase);

  // ---------------------------------------------------------------- helpers

  DateTime get _time => _now().toUtc();

  ChatPrivacy _settings(String person) => _privacy[person] ?? ChatPrivacy();

  String _nameOf(String person, String viewer, [CircleWorkspace? workspace]) {
    if (person == viewer) return 'You';
    return workspace?.people[person] ?? _names[person] ?? 'Someone';
  }

  Future<CircleWorkspace> _load(String viewer) async {
    final workspace = await _workspace.load(viewer);
    _names.addAll(workspace.people);
    _lastActive[viewer] = _time;
    return workspace;
  }

  /// [person]'s activity label as [viewer] may see it, or null.
  String? _activity(CircleWorkspace workspace, String viewer, String person) =>
      ActivityRules.visibleLabel(
        viewer: viewer,
        person: person,
        viewerPrivacy: _settings(viewer),
        personPrivacy: _settings(person),
        shared: ChatRules.sharedGroups(workspace.groups, viewer, person),
        lastActiveAt: _lastActive[person],
        now: _time,
        pendingRequest:
            _conversations[ChatRules.directId(viewer, person)]?.pendingFor !=
            null,
      );

  /// Everyone currently in the conversation, including [viewer] (empty
  /// after leaving a group).
  List<String> _participants(_Access access) => access.conversation.isGroup
      ? [...?access.group?.roles.keys]
      : [...access.conversation.participants];

  void _check(RuleResult result) {
    if (!result.allowed) throw CircleFailure(result.reason!);
  }

  static const _notShared = CircleFailure(
    'This conversation isn’t shared with you.',
  );

  /// Resolves [id] for [viewer] with their current memberships. Group
  /// chats mirror the group; a viewer who left keeps a read-only copy of
  /// what was said before they left.
  Future<_Access> _access(String viewer, String id) async {
    final workspace = await _load(viewer);
    if (id.startsWith('g-')) {
      final groupId = id.substring(2);
      final group = workspace.group(groupId);
      var conversation = _conversations[id];
      if (group != null) {
        conversation ??= _conversations[id] = _Conversation.group(
          id,
          groupId,
          createdAt: _time,
        );
        conversation
          ..title = group.name
          ..groupType = group.type
          ..knownMembers.add(viewer)
          ..leftAt.remove(viewer);
        return _Access(workspace, conversation, group: group);
      }
      if (conversation == null || !conversation.knownMembers.contains(viewer)) {
        throw _notShared;
      }
      conversation.leftAt.putIfAbsent(viewer, () => _time);
      return _Access(workspace, conversation);
    }
    final conversation = _conversations[id];
    if (conversation == null || !conversation.participants.contains(viewer)) {
      throw _notShared;
    }
    return _Access(workspace, conversation);
  }

  String _otherOf(_Conversation conversation, String viewer) =>
      conversation.participants.firstWhere((p) => p != viewer);

  /// Whether [person] took part in [conversation]: sent a message there or
  /// accepted its request.
  bool _tookPart(_Conversation? conversation, String person) =>
      conversation != null &&
      (conversation.acceptedBy.contains(person) ||
          conversation.messages.any((m) => m.authorId == person));

  DirectEligibility _eligibility(
    CircleWorkspace workspace,
    String sender,
    String recipient,
  ) => ChatRules.directEligibility(
    sender: sender,
    recipient: recipient,
    shared: ChatRules.sharedGroups(workspace.groups, sender, recipient),
    senderPrivacy: _settings(sender),
    recipientPrivacy: _settings(recipient),
    haveChatted: _tookPart(
      _conversations[ChatRules.directId(sender, recipient)],
      recipient,
    ),
  );

  ConversationMode _mode(_Access access, String viewer) {
    final conversation = access.conversation;
    if (conversation.isGroup) {
      return access.group == null
          ? ConversationMode.leftGroup
          : ConversationMode.active;
    }
    final other = _otherOf(conversation, viewer);
    if (conversation.pendingFor == viewer) {
      return ConversationMode.incomingRequest;
    }
    if (_settings(viewer).blocked.contains(other)) {
      return ConversationMode.blockedByYou;
    }
    return _eligibility(access.workspace, viewer, other) ==
            DirectEligibility.allowed
        ? ConversationMode.active
        : ConversationMode.cannotReply;
  }

  /// Fails calmly unless [viewer] may write in the conversation now.
  void _requireActive(_Access access, String viewer) {
    final mode = _mode(access, viewer);
    final conversation = access.conversation;
    switch (mode) {
      case ConversationMode.active:
        return;
      case ConversationMode.leftGroup:
        _check(ChatRules.canPostInGroup(null, viewer));
      case ConversationMode.incomingRequest:
        throw const CircleFailure('Accept the request to reply.');
      case ConversationMode.blockedByYou:
      case ConversationMode.cannotReply:
        final other = _otherOf(conversation, viewer);
        throw CircleFailure(
          ChatRules.eligibilityMessage(
            _eligibility(access.workspace, viewer, other),
            _nameOf(other, viewer, access.workspace),
          ),
        );
    }
  }

  /// Messages [viewer] may see: everything, or (after leaving a group)
  /// what was said before they left. Messages admins hid are gone for
  /// everyone except that group's admins.
  List<ChatMessage> _visible(_Access access, String viewer) {
    final conversation = access.conversation;
    final left = conversation.leftAt[viewer];
    final admin = access.group?.roles[viewer]?.isAdmin ?? false;
    return [
      for (final message in conversation.messages)
        if ((left == null || !message.createdAt.isAfter(left)) &&
            (admin || !_hiddenByAdmins(access, message)))
          message,
    ];
  }

  bool _hiddenByAdmins(_Access access, ChatMessage message) =>
      access.conversation.isGroup &&
      access.workspace.isHidden(ReportKind.message, message.id);

  ChatMessage _message(_Conversation conversation, String id) {
    final message = conversation.messages.where((m) => m.id == id).firstOrNull;
    if (message == null) {
      throw const CircleFailure('This message is no longer available.');
    }
    return message;
  }

  void _replace(_Conversation conversation, ChatMessage message) {
    final index = conversation.messages.indexWhere((m) => m.id == message.id);
    conversation.messages[index] = message;
  }

  _Prefs _prefs(_Conversation conversation, String viewer) =>
      conversation.prefs.putIfAbsent(viewer, _Prefs.new);

  ({bool forever, DateTime? until}) _mute(
    _Conversation conversation,
    String viewer,
    int memberCount,
  ) {
    final prefs = conversation.prefs[viewer];
    if (prefs == null || !prefs.muteChosen) {
      return (
        forever: conversation.isGroup && ChatRules.quietByDefault(memberCount),
        until: null,
      );
    }
    final until = prefs.mutedUntil;
    return (
      forever: prefs.mutedForever,
      until: until != null && _time.isBefore(until) ? until : null,
    );
  }

  /// "Sent" / "Seen" / "Seen by …" for [message], the viewer's own.
  ({String label, String semantics}) _status(
    _Access access,
    ChatMessage message,
    String viewer,
  ) {
    final conversation = access.conversation;
    if (!conversation.isGroup) {
      final other = _otherOf(conversation, viewer);
      final label = ChatRules.directStatus(
        sentAt: message.createdAt,
        otherReadAt: conversation.readAt[other],
        accepted: conversation.pendingFor == null,
      );
      return (
        label: label,
        semantics: label == 'Seen'
            ? 'Seen by ${_nameOf(other, viewer, access.workspace)}'
            : 'Sent, not seen yet',
      );
    }
    final members = access.group?.roles.keys ?? const <String>[];
    final readers =
        [
          for (final person in members)
            if (person != viewer &&
                !(conversation.readAt[person]?.isBefore(message.createdAt) ??
                    true))
              person,
        ]..sort(
          (a, b) => conversation.readAt[a]!.compareTo(conversation.readAt[b]!),
        );
    final names = [
      for (final person in readers) _nameOf(person, viewer, access.workspace),
    ];
    return (
      label: ChatRules.groupStatus(names),
      semantics: ChatRules.groupStatusSemantics(names),
    );
  }

  SharedView? _sharedView(SharedContent? content, CircleWorkspace workspace) {
    if (content == null) return null;
    switch (content.kind) {
      case SharedKind.memory:
        final memory = workspace.memories
            .where((m) => m.id == content.id)
            .firstOrNull;
        final group = memory == null ? null : workspace.group(memory.groupId);
        return SharedView(
          content: content,
          visible: memory != null && group != null,
          memory: memory,
          group: group,
          audience: group == null
              ? null
              : audiencePath(group, workspace.groupsById),
        );
      case SharedKind.event:
        final event = workspace.event(content.id);
        final group = event == null ? null : workspace.group(event.groupId);
        return SharedView(
          content: content,
          visible: event != null && group != null,
          event: event,
          group: group,
          audience: group == null
              ? null
              : audiencePath(group, workspace.groupsById),
        );
    }
  }

  MessageView _view(
    _Access access,
    ChatMessage message,
    String viewer,
    ConversationMode mode,
  ) {
    final conversation = access.conversation;
    final workspace = access.workspace;
    final now = _time;
    final active = mode == ConversationMode.active;
    final hidden =
        conversation.isGroup &&
        _settings(viewer).blocked.contains(message.authorId);
    final quoted = message.replyToId == null
        ? null
        : conversation.messages
              .where((m) => m.id == message.replyToId)
              .firstOrNull;
    final poll = message.poll;
    String name(String person) => _nameOf(person, viewer, workspace);
    return MessageView(
      id: message.id,
      authorId: message.authorId,
      authorName: name(message.authorId),
      text: message.unsent || hidden ? '' : message.text,
      createdAt: message.createdAt,
      mine: message.authorId == viewer,
      edited: message.editedAt != null,
      unsent: message.unsent,
      hidden: hidden,
      hiddenByAdmins: _hiddenByAdmins(access, message),
      reactions: message.unsent || hidden
          ? MemoryReactions()
          : ReactionRules.viewFor(message.reactions, viewer),
      replyTo: quoted == null || message.unsent || hidden
          ? null
          : ReplyPreview(
              messageId: quoted.id,
              authorName: name(quoted.authorId),
              text: quoted.unsent
                  ? 'Message unsent'
                  : quoted.text.isNotEmpty
                  ? quoted.text
                  : quoted.poll != null
                  ? 'Poll: ${quoted.poll!.question}'
                  : quoted.photos.isNotEmpty
                  ? photoSummary(quoted.photos.length)
                  : 'Shared content',
            ),
      shared: message.unsent || hidden
          ? null
          : _sharedView(message.shared, workspace),
      poll: poll == null || message.unsent || hidden
          ? null
          : PollRules.view(
              poll,
              viewer: viewer,
              isMember: active,
              isAdmin: access.group?.roles[viewer]?.isAdmin ?? false,
              now: now,
              nameOf: name,
            ),
      editableUntil: active && ChatRules.canEdit(message, viewer, now).allowed
          ? message.createdAt.add(ChatRules.editWindow)
          : null,
      canUnsend: active && ChatRules.canUnsend(message, viewer).allowed,
      mentions: message.unsent || hidden ? const {} : message.mentions,
      photos: message.unsent || hidden ? const [] : message.photos,
      forwarded: message.forwarded && !message.unsent && !hidden,
      canForward:
          !hidden &&
          !_hiddenByAdmins(access, message) &&
          ForwardRules.canForward(message).allowed,
    );
  }

  String _summaryOf(ChatMessage message) {
    if (message.unsent) return 'Message unsent';
    if (message.text.isNotEmpty) return message.text;
    if (message.poll != null) return 'Poll: ${message.poll!.question}';
    if (message.photos.isNotEmpty) return photoSummary(message.photos.length);
    return message.shared?.kind == SharedKind.event
        ? 'Shared an event'
        : 'Shared a Memory';
  }

  /// Whether a deleted request stays hidden (nothing newer arrived).
  bool _hiddenFor(_Conversation conversation, String viewer) {
    final at = conversation.hiddenAt[viewer];
    return at != null &&
        !conversation.messages.any((m) => m.createdAt.isAfter(at));
  }

  ConversationSummary _summary(_Access access, String viewer) {
    final conversation = access.conversation;
    final workspace = access.workspace;
    final now = _time;
    final mode = _mode(access, viewer);
    final visible = _visible(access, viewer);
    final blocked = _settings(viewer).blocked;
    final last = visible.lastOrNull;
    final other = conversation.isGroup ? null : _otherOf(conversation, viewer);
    final memberCount =
        access.group?.roles.length ?? conversation.participants.length;
    final readAt = conversation.readAt[viewer];
    final unread = visible.any(
      (m) =>
          m.authorId != viewer &&
          !(conversation.isGroup && blocked.contains(m.authorId)) &&
          (readAt == null || m.createdAt.isAfter(readAt)),
    );
    String preview;
    if (mode == ConversationMode.leftGroup) {
      preview = 'You left this group';
    } else if (last == null) {
      preview = 'No messages yet';
    } else if (last.authorId == viewer) {
      preview = last.unsent
          ? 'Message unsent'
          : ChatRules.ownLastLine(
              _status(access, last, viewer).label,
              last.createdAt,
              now,
            );
    } else if (conversation.isGroup && blocked.contains(last.authorId)) {
      preview = 'Message from someone you blocked';
    } else {
      final text = _summaryOf(last);
      final age = ChatRules.shortAge(last.createdAt, now);
      preview = conversation.isGroup
          ? '${_nameOf(last.authorId, viewer, workspace)}: $text · $age'
          : '$text · $age';
    }
    final prefs = conversation.prefs[viewer];
    final mute = _mute(conversation, viewer, memberCount);
    final activity = other == null ? null : _activity(workspace, viewer, other);
    return ConversationSummary(
      id: conversation.id,
      kind: conversation.kind,
      title: conversation.isGroup
          ? conversation.title
          : _nameOf(other!, viewer, workspace),
      preview: preview,
      groupId: conversation.groupId,
      groupType: conversation.groupType,
      otherId: other,
      memberCount: memberCount,
      lastActivity: last?.createdAt,
      unread: unread,
      pinned: prefs?.pinned ?? false,
      mutedForever: mute.forever,
      mutedUntil: mute.until,
      mutedByDefault: prefs == null || !prefs.muteChosen,
      archived: prefs?.archived ?? false,
      request: mode == ConversationMode.incomingRequest,
      readOnly: mode == ConversationMode.leftGroup,
      activity: activity,
      activeNow: activity == ActivityRules.activeNow,
      canPost: mode == ConversationMode.active,
    );
  }

  static int _byActivity(ConversationSummary a, ConversationSummary b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final at = a.lastActivity, bt = b.lastActivity;
    if (at != null && bt != null && at != bt) return bt.compareTo(at);
    if (at != null && bt == null) return -1;
    if (at == null && bt != null) return 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  // ------------------------------------------------------------------ reads

  @override
  Future<ChatInbox> inbox(String viewer) async {
    final workspace = await _load(viewer);
    final accesses = <_Access>[];
    for (final group in workspace.groups) {
      accesses.add(
        await _access(viewer, ChatRules.groupConversationId(group.id)),
      );
    }
    final blocked = _settings(viewer).blocked;
    for (final conversation in [..._conversations.values]) {
      if (conversation.isGroup) {
        if (workspace.group(conversation.groupId!) == null &&
            conversation.knownMembers.contains(viewer)) {
          accesses.add(await _access(viewer, conversation.id));
        }
        continue;
      }
      if (!conversation.participants.contains(viewer) ||
          conversation.messages.isEmpty ||
          _hiddenFor(conversation, viewer)) {
        continue;
      }
      // Requests from people the viewer blocked vanish.
      if (conversation.pendingFor == viewer &&
          blocked.contains(_otherOf(conversation, viewer))) {
        continue;
      }
      accesses.add(_Access(workspace, conversation));
    }
    final summaries = [for (final access in accesses) _summary(access, viewer)]
      ..sort(_byActivity);
    return ChatInbox(
      chats: [
        for (final s in summaries)
          if (!s.request && !s.archived) s,
      ],
      requests: [
        for (final s in summaries)
          if (s.request) s,
      ],
      archived: [
        for (final s in summaries)
          if (!s.request && s.archived) s,
      ],
    );
  }

  @override
  Future<ConversationView> conversation(
    String viewer,
    String conversationId,
  ) async {
    final access = await _access(viewer, conversationId);
    final conversation = access.conversation;
    final workspace = access.workspace;
    final mode = _mode(access, viewer);
    final visible = _visible(access, viewer);
    final messages = [
      for (final message in visible) _view(access, message, viewer, mode),
    ];
    final own = visible
        .where((m) => m.authorId == viewer && !m.unsent)
        .lastOrNull;
    final status = own == null || mode == ConversationMode.incomingRequest
        ? null
        : _status(access, own, viewer);
    final other = conversation.isGroup ? null : _otherOf(conversation, viewer);
    final memberCount = access.group?.roles.length ?? 2;
    final mute = _mute(conversation, viewer, memberCount);
    final prefs = conversation.prefs[viewer];
    return ConversationView(
      id: conversation.id,
      kind: conversation.kind,
      title: conversation.isGroup
          ? conversation.title
          : _nameOf(other!, viewer, workspace),
      mode: mode,
      messages: messages,
      groupId: conversation.groupId,
      groupType: conversation.groupType,
      otherId: other,
      members: [
        for (final entry
            in access.group?.roles.entries ??
                const <MapEntry<String, CircleRole>>[])
          ChatMember(
            id: entry.key,
            name: _nameOf(entry.key, viewer, workspace),
            role: entry.value,
          ),
      ],
      sharedGroups: other == null
          ? const []
          : [
              for (final group in ChatRules.sharedGroups(
                workspace.groups,
                viewer,
                other,
              ))
                group.name,
            ],
      participants: _participants(access),
      activity: other == null ? null : _activity(workspace, viewer, other),
      status: status?.label,
      statusSemantics: status?.semantics,
      statusMessageId: status == null ? null : own!.id,
      pinned: prefs?.pinned ?? false,
      mutedForever: mute.forever,
      mutedUntil: mute.until,
      archived: prefs?.archived ?? false,
      otherBlocked: other != null && _settings(viewer).blocked.contains(other),
    );
  }

  @override
  Future<List<ChatContactGroup>> contacts(String viewer) async {
    final workspace = await _load(viewer);
    return [
      for (final entry in buildGroupTree(workspace.groups))
        if (entry.group.roles.length > 1)
          ChatContactGroup(
            group: entry.group,
            contacts: [
              for (final person in entry.group.roles.keys)
                if (person != viewer)
                  ChatContact(
                    personId: person,
                    name: _nameOf(person, viewer, workspace),
                    eligibility: _eligibility(workspace, viewer, person),
                    activity: _activity(workspace, viewer, person),
                  ),
            ]..sort((a, b) => a.name.compareTo(b.name)),
          ),
    ];
  }

  @override
  Future<ChatPrivacyView> privacy(String viewer) async {
    final workspace = await _load(viewer);
    final settings = _settings(viewer);
    return ChatPrivacyView(
      settings: settings,
      groups: [
        for (final entry in buildGroupTree(workspace.groups)) entry.group,
      ],
      blocked: [
        for (final person in settings.blocked)
          BlockedPerson(id: person, name: _nameOf(person, viewer, workspace)),
      ]..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  // ---------------------------------------------------------------- changes

  @override
  Future<String> openDirect(String viewer, String person) async {
    final workspace = await _load(viewer);
    final eligibility = _eligibility(workspace, viewer, person);
    if (eligibility != DirectEligibility.allowed) {
      throw CircleFailure(
        ChatRules.eligibilityMessage(
          eligibility,
          _nameOf(person, viewer, workspace),
        ),
      );
    }
    final id = ChatRules.directId(viewer, person);
    _conversations.putIfAbsent(
      id,
      () => _Conversation.direct(id, {viewer, person}, createdAt: _time),
    );
    return id;
  }

  @override
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
  }) async {
    final access = await _access(viewer, conversationId);
    final conversation = access.conversation;
    final duplicate = ChatRules.duplicateOf(
      conversation.messages,
      viewer,
      clientMessageId,
    );
    if (duplicate != null) return duplicate.id;
    _requireActive(access, viewer);
    _check(
      ChatRules.checkText(
        text,
        hasAttachment: shared != null || poll != null || photos.isNotEmpty,
      ),
    );
    _check(ChatPhotoRules.check(photos.length));
    if (replyToId != null && _message(conversation, replyToId).unsent) {
      throw const CircleFailure('That message was unsent.');
    }
    if (shared != null) {
      final view = _sharedView(shared, access.workspace)!;
      if (!view.visible) {
        throw const CircleFailure('You can only share things you can see.');
      }
      _check(ChatRules.canShareInto(view.group, _participants(access)));
    }
    if (poll != null) _check(PollRules.checkDraft(poll));
    final now = _time;
    final id = 'message-${++_sequence}';
    if (!conversation.isGroup &&
        conversation.messages.isEmpty &&
        conversation.pendingFor == null) {
      final other = _otherOf(conversation, viewer);
      if (ChatRules.needsRequest(
        shared: ChatRules.sharedGroups(access.workspace.groups, viewer, other),
        recipientPrivacy: _settings(other),
        haveChatted: _tookPart(conversation, other),
      )) {
        conversation.pendingFor = other;
      }
    }
    conversation.messages.add(
      ChatMessage(
        id: id,
        conversationId: conversation.id,
        authorId: viewer,
        clientMessageId: clientMessageId,
        createdAt: now,
        text: text.trim(),
        replyToId: replyToId,
        shared: shared,
        // Group chats only, and only members of this exact group.
        mentions: access.group == null
            ? const {}
            : MentionRules.resolve(
                text: text.trim(),
                picked: mentions,
                members: access.group!.roles.keys.toSet(),
              ),
        photos: [
          for (final (index, scene) in photos.indexed)
            MemoryPhoto(id: '$id-photo-${index + 1}', scene: scene),
        ],
        poll: poll == null
            ? null
            : PollRules.create(
                poll,
                id: '$id-poll',
                createdBy: viewer,
                now: now,
              ),
      ),
    );
    conversation.readAt[viewer] = now;
    return id;
  }

  @override
  Future<ForwardResult> forward(
    String viewer,
    String conversationId,
    String messageId, {
    required List<String> to,
    required String clientMessageId,
  }) async {
    final source = await _access(viewer, conversationId);
    final message = _message(source.conversation, messageId);
    if (!_visible(source, viewer).contains(message) ||
        (source.conversation.isGroup &&
            _settings(viewer).blocked.contains(message.authorId))) {
      throw const CircleFailure('This message is no longer available.');
    }
    _check(ForwardRules.canForward(message));
    final targets = to.toSet().toList();
    _check(ForwardRules.checkTargets(targets));
    final sentTo = <String>[], titles = <String>[];
    final skipped = <ForwardSkip>[];
    for (final target in targets) {
      _Access access;
      try {
        access = await _access(viewer, target);
      } on CircleFailure {
        skipped.add(
          ForwardSkip(
            conversationId: target,
            title: 'a chat',
            reason: 'that chat isn’t available',
          ),
        );
        continue;
      }
      final conversation = access.conversation;
      final title = conversation.isGroup
          ? conversation.title
          : _nameOf(_otherOf(conversation, viewer), viewer, access.workspace);
      final shared = message.shared;
      final view = _sharedView(shared, access.workspace);
      final reason = ForwardRules.skipReason(
        canPost: _mode(access, viewer) == ConversationMode.active,
        shared: shared,
        // The item must still be visible to the viewer, and everyone in
        // the target chat must already see it (the UI-5 share rule).
        everyoneCanSee:
            view != null &&
            view.visible &&
            ChatRules.everyoneCanSee(view.group, _participants(access)),
      );
      if (reason != null) {
        skipped.add(
          ForwardSkip(conversationId: target, title: title, reason: reason),
        );
        continue;
      }
      await send(
        viewer,
        target,
        clientMessageId: '$clientMessageId-$target',
        text: message.text,
        shared: shared,
      );
      // Mark the copy as forwarded (mentions never travel along).
      final copy = ChatRules.duplicateOf(
        conversation.messages,
        viewer,
        '$clientMessageId-$target',
      )!;
      if (!copy.forwarded) {
        _replace(
          conversation,
          ChatMessage(
            id: copy.id,
            conversationId: copy.conversationId,
            authorId: copy.authorId,
            clientMessageId: copy.clientMessageId,
            createdAt: copy.createdAt,
            text: copy.text,
            shared: copy.shared,
            forwarded: true,
          ),
        );
      }
      sentTo.add(target);
      titles.add(title);
    }
    return ForwardResult(sentTo: sentTo, sentTitles: titles, skipped: skipped);
  }

  @override
  Future<void> edit(
    String viewer,
    String conversationId,
    String messageId,
    String text,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final message = _message(access.conversation, messageId);
    _check(ChatRules.canEdit(message, viewer, _time));
    _check(ChatRules.checkText(text));
    _replace(
      access.conversation,
      message.copyWith(
        text: text.trim(),
        editedAt: _time,
        // A name removed by the edit is no longer a mention.
        mentions: {
          for (final entry in message.mentions.entries)
            if (MentionRules.mentions(text.trim(), entry.value))
              entry.key: entry.value,
        },
      ),
    );
  }

  @override
  Future<void> unsend(
    String viewer,
    String conversationId,
    String messageId,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final message = _message(access.conversation, messageId);
    _check(ChatRules.canUnsend(message, viewer));
    _replace(access.conversation, message.copyWith(unsentAt: _time));
  }

  @override
  Future<void> restore(
    String viewer,
    String conversationId,
    String messageId,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final message = _message(access.conversation, messageId);
    _check(ChatRules.canRestore(message, viewer));
    _replace(access.conversation, message.copyWith(restore: true));
  }

  @override
  Future<void> react(
    String viewer,
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final message = _message(access.conversation, messageId);
    _check(ChatRules.canReact(message, emoji));
    _replace(
      access.conversation,
      message.copyWith(
        reactions: ReactionRules.toggle(message.reactions, viewer, emoji),
      ),
    );
  }

  @override
  Future<void> report(
    String viewer,
    String conversationId, {
    String? messageId,
    required ReportReason reason,
    String? note,
  }) async {
    final access = await _access(viewer, conversationId);
    final conversation = access.conversation;
    _check(ModerationRules.checkNote(note));
    final ReportTarget target;
    String? summary;
    if (messageId != null) {
      final message = _message(conversation, messageId);
      if (message.unsent || !_visible(access, viewer).contains(message)) {
        throw const CircleFailure('This message is no longer available.');
      }
      if (message.authorId == viewer) {
        throw const CircleFailure('You can’t report your own posts.');
      }
      target = ReportTarget.message(
        message.id,
        conversationId: conversation.id,
        // Group chats: the group's admins review it; 1:1: the platform.
        groupId: conversation.groupId,
        authorId: message.authorId,
      );
      summary = _summaryOf(message);
    } else if (!conversation.isGroup) {
      final other = _otherOf(conversation, viewer);
      target = ReportTarget(
        kind: ReportKind.member,
        id: other,
        groupId: null,
        personId: other,
      );
    } else {
      throw const CircleFailure('Report a message, or the group from Groups.');
    }
    if (reports.any(
      (r) =>
          r.reporter == viewer &&
          r.conversationId == conversationId &&
          r.messageId == messageId,
    )) {
      throw const CircleFailure('You already reported this. Thank you.');
    }
    await _reportsTo?.report(
      viewer,
      ReportDraft(target: target, reason: reason, note: note, summary: summary),
    );
    reports.add((
      reporter: viewer,
      conversationId: conversationId,
      messageId: messageId,
      reason: reason,
    ));
  }

  @override
  Future<List<ReadableMessage>> readableMessages(String viewer) async {
    final inbox = await this.inbox(viewer);
    final result = <ReadableMessage>[];
    for (final summary in [
      ...inbox.chats,
      ...inbox.requests,
      ...inbox.archived,
    ]) {
      final access = await _access(viewer, summary.id);
      final blocked = _settings(viewer).blocked;
      for (final message in _visible(access, viewer)) {
        if (message.unsent || message.text.isEmpty) continue;
        if (access.conversation.isGroup && blocked.contains(message.authorId)) {
          continue;
        }
        result.add(
          ReadableMessage(
            conversationId: summary.id,
            conversationTitle: summary.title,
            messageId: message.id,
            authorName: _nameOf(message.authorId, viewer, access.workspace),
            text: message.text,
            at: message.createdAt,
            authorId: message.authorId,
            groupId: access.conversation.groupId,
            mentions: message.mentions.keys.toSet(),
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<void> markRead(String viewer, String conversationId) async {
    final access = await _access(viewer, conversationId);
    final last = _visible(access, viewer).lastOrNull?.createdAt;
    final now = _time;
    access.conversation.readAt[viewer] = last != null && last.isAfter(now)
        ? last
        : now;
  }

  @override
  Future<void> setPinned(
    String viewer,
    String conversationId,
    bool pinned,
  ) async {
    final access = await _access(viewer, conversationId);
    _prefs(access.conversation, viewer).pinned = pinned;
  }

  @override
  Future<void> mute(
    String viewer,
    String conversationId,
    ChatMute? mute,
  ) async {
    final access = await _access(viewer, conversationId);
    final length = mute?.length;
    _prefs(access.conversation, viewer)
      ..muteChosen = true
      ..mutedForever = mute == ChatMute.always
      ..mutedUntil = length == null ? null : _time.add(length);
  }

  @override
  Future<void> setArchived(
    String viewer,
    String conversationId,
    bool archived,
  ) async {
    final access = await _access(viewer, conversationId);
    if (archived && access.conversation.pendingFor == viewer) {
      throw const CircleFailure('Accept or delete the request first.');
    }
    _prefs(access.conversation, viewer).archived = archived;
  }

  _Conversation _request(_Access access, String viewer) {
    final conversation = access.conversation;
    if (conversation.pendingFor != viewer) {
      throw const CircleFailure('This request has already been handled.');
    }
    return conversation;
  }

  @override
  Future<void> acceptRequest(String viewer, String conversationId) async {
    final conversation = _request(
      await _access(viewer, conversationId),
      viewer,
    );
    conversation
      ..pendingFor = null
      ..acceptedBy.add(viewer)
      ..hiddenAt.remove(viewer)
      ..readAt[viewer] = _time;
  }

  @override
  Future<void> deleteRequest(String viewer, String conversationId) async {
    final conversation = _request(
      await _access(viewer, conversationId),
      viewer,
    );
    conversation.hiddenAt[viewer] = _time;
  }

  @override
  Future<void> restoreRequest(String viewer, String conversationId) async {
    final conversation = _request(
      await _access(viewer, conversationId),
      viewer,
    );
    conversation.hiddenAt.remove(viewer);
  }

  @override
  Future<void> block(String viewer, String person) async {
    final workspace = await _load(viewer);
    final known =
        workspace.people.containsKey(person) ||
        _conversations.containsKey(ChatRules.directId(viewer, person));
    if (person == viewer || !known) {
      throw const CircleFailure('You can only block people you know here.');
    }
    final settings = _settings(viewer);
    _privacy[viewer] = settings.copyWith(
      blocked: {...settings.blocked, person},
    );
  }

  @override
  Future<void> unblock(String viewer, String person) async {
    final settings = _settings(viewer);
    _privacy[viewer] = settings.copyWith(
      blocked: {...settings.blocked}..remove(person),
    );
  }

  @override
  Future<void> setWhoCanMessage(String viewer, WhoCanMessage value) async {
    _privacy[viewer] = _settings(viewer).copyWith(whoCanMessage: value);
  }

  @override
  Future<void> setCloseGroup(String viewer, String groupId, bool close) async {
    final workspace = await _load(viewer);
    if (workspace.group(groupId) == null) {
      throw const CircleFailure('This group is not shared with you.');
    }
    final settings = _settings(viewer);
    _privacy[viewer] = settings.copyWith(
      closeGroups: {...settings.closeGroups, groupId: close},
    );
  }

  @override
  Future<void> setShowActivity(String viewer, bool show) async {
    _privacy[viewer] = _settings(viewer).copyWith(showActivity: show);
  }

  ({_Conversation conversation, ChatMessage message, Poll poll}) _poll(
    _Access access,
    String messageId,
  ) {
    final message = _message(access.conversation, messageId);
    final poll = message.poll;
    if (poll == null || message.unsent) {
      throw const CircleFailure('This poll is no longer available.');
    }
    return (conversation: access.conversation, message: message, poll: poll);
  }

  @override
  Future<void> votePoll(
    String viewer,
    String conversationId,
    String messageId,
    Set<String> optionIds,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final found = _poll(access, messageId);
    _check(
      PollRules.canVote(
        found.poll,
        voter: viewer,
        isMember: true,
        choices: optionIds,
        now: _time,
      ),
    );
    _replace(
      found.conversation,
      found.message.copyWith(poll: found.poll.withVote(viewer, optionIds)),
    );
  }

  @override
  Future<void> retractPollVote(
    String viewer,
    String conversationId,
    String messageId,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final found = _poll(access, messageId);
    _check(
      PollRules.canRetract(
        found.poll,
        voter: viewer,
        isMember: true,
        now: _time,
      ),
    );
    _replace(
      found.conversation,
      found.message.copyWith(poll: found.poll.withVote(viewer, const {})),
    );
  }

  @override
  Future<void> closePoll(
    String viewer,
    String conversationId,
    String messageId,
  ) async {
    final access = await _access(viewer, conversationId);
    _requireActive(access, viewer);
    final found = _poll(access, messageId);
    _check(
      PollRules.canClose(
        found.poll,
        actor: viewer,
        isMember: true,
        isAdmin: access.group?.roles[viewer]?.isAdmin ?? false,
        now: _time,
      ),
    );
    _replace(
      found.conversation,
      found.message.copyWith(poll: found.poll.closed(_time)),
    );
  }

  // ------------------------------------------------------------------- seed

  void _seed({required bool showcase}) {
    _conversations.clear();
    _privacy.clear();
    _names.clear();
    _lastActive.clear();
    reports.clear();
    _sequence = 0;
    if (!showcase) return;
    final seedTime = _time;
    DateTime ago(Duration duration) => seedTime.subtract(duration);
    const minutes = Duration(minutes: 1), hours = Duration(hours: 1);
    const days = Duration(days: 1);

    // Fictional, static activity. Sam, Noor, Tomas and others: unknown.
    _lastActive.addAll({
      'mira': ago(minutes * 2),
      'priya': ago(minutes * 35),
      'dev': ago(hours * 2),
      'lena': ago(hours * 26),
      'kavya': ago(days * 4),
    });

    _Conversation group(String groupId, String title, CircleType type) {
      final id = ChatRules.groupConversationId(groupId);
      return _conversations[id] =
          _Conversation.group(id, groupId, createdAt: ago(days * 30))
            ..title = title
            ..groupType = type
            ..knownMembers.add('you');
    }

    _Conversation direct(String a, String b) {
      final id = ChatRules.directId(a, b);
      return _conversations[id] = _Conversation.direct(id, {
        a,
        b,
      }, createdAt: ago(days * 30));
    }

    var count = 0;
    ChatMessage message(
      _Conversation conversation,
      String author,
      DateTime at, {
      String? id,
      String text = '',
      String? replyTo,
      Map<String, String> reactions = const {},
      SharedContent? shared,
      Poll? poll,
      Map<String, String> mentions = const {},
    }) {
      final messageId = id ?? '${conversation.id}-${++count}';
      final value = ChatMessage(
        id: messageId,
        conversationId: conversation.id,
        authorId: author,
        clientMessageId: 'seed-$messageId',
        createdAt: at,
        text: text,
        replyToId: replyTo,
        reactions: reactions,
        shared: shared,
        poll: poll,
        mentions: mentions,
      );
      conversation.messages.add(value);
      conversation.knownMembers.add(author);
      return value;
    }

    // The Sunday table: a shared Memory, a reply and "Seen by Mira, Dev".
    final family = group('family', 'The Sunday table', CircleType.family);
    message(
      family,
      'mira',
      ago(hours * 26),
      text: 'Who’s bringing the big pot this Sunday?',
    );
    message(
      family,
      'dev',
      ago(hours * 26 - minutes * 4),
      text: 'Not me. I broke the lid last time 😅',
    );
    message(
      family,
      'you',
      ago(hours * 26 - minutes * 6),
      text: 'I’ll bring it. And the spare lid.',
      reactions: {'mira': '😂', 'priya': '❤️'},
    );
    final shared = message(
      family,
      'priya',
      ago(hours * 3),
      text: 'This one made me smile.',
      shared: const SharedContent.memory('table'),
    );
    message(
      family,
      'mira',
      ago(hours * 3 - minutes * 3),
      text: 'Room for one more, always.',
      replyTo: shared.id,
      reactions: {'priya': '❤️'},
    );
    message(
      family,
      'you',
      ago(minutes * 50),
      text: 'Can’t wait. I’ll come early to help set up.',
    );
    family.readAt.addAll({
      'you': ago(minutes * 50),
      'mira': ago(minutes * 30),
      'dev': ago(minutes * 20),
      'priya': ago(hours * 2),
    });

    // Northbank 2009: a large group (quiet by default) with a shared event.
    final college = group('college', 'Northbank 2009', CircleType.college);
    message(
      college,
      'mira',
      ago(hours * 6),
      text: 'Save the date! Vote for the day that works in the event.',
      shared: const SharedContent.event('reunion'),
      reactions: {'dev': '🎉', 'sam': '🎉', 'kavya': '❤️'},
    );
    message(
      college,
      'kavya',
      ago(hours * 5 + minutes * 40),
      text: 'So happy this is finally happening!',
    );
    // Reported by two classmates (see the circle repository's seed).
    message(
      college,
      'bilal',
      ago(hours * 5 + minutes * 20),
      id: 'college-spam',
      text: 'Selling cheap concert tickets — message me for the link!',
    );
    message(
      college,
      'sam',
      ago(hours * 4),
      id: 'college-mention',
      text:
          'Count me in if it’s the second weekend. @You, do you still have '
          'the farewell photo?',
      // A real mention of the viewer: it shows in Activity.
      mentions: {'you': 'You'},
    );
    college.readAt.addAll({
      'you': ago(hours * 5),
      'mira': ago(hours * 3),
      'sam': ago(hours * 4),
    });

    // Studio North: a poll in the group chat.
    final work = group('work', 'Studio North', CircleType.office);
    final lunch = PollRules.create(
      const PollDraft(
        question: 'Team lunch on Friday?',
        options: ['Noodle place', 'Salad bar', 'Bring our own'],
        resultsVisibility: PollResultsVisibility.always,
      ),
      id: 'work-lunch-poll',
      createdBy: 'lena',
      now: ago(days),
    ).withVote('dev', {'work-lunch-poll-option-1'});
    message(work, 'lena', ago(days), poll: lunch);
    message(
      work,
      'dev',
      ago(days - minutes * 20),
      text: 'Noodle place gets my vote.',
    );
    work.readAt.addAll({
      'you': ago(hours * 20),
      'lena': ago(days - minutes * 20),
      'dev': ago(days - minutes * 20),
    });

    // Mira: pinned, with a reply and "Seen".
    final mira = direct('mira', 'you');
    message(
      mira,
      'mira',
      ago(days * 3),
      text: 'Found the old ride photos. Sharing them with the club soon.',
    );
    message(
      mira,
      'you',
      ago(days * 3 - minutes * 5),
      text: 'Yes please! The lake one especially.',
      reactions: {'mira': '❤️'},
    );
    final walk = message(
      mira,
      'mira',
      ago(hours * 2),
      text: 'Also, are you free for a walk tomorrow morning?',
    );
    message(
      mira,
      'you',
      ago(hours + minutes * 30),
      text: 'Sounds lovely. 7:30?',
      replyTo: walk.id,
    );
    mira
      ..readAt.addAll({'you': ago(hours + minutes * 30), 'mira': ago(hours)})
      ..prefs['you'] = (_Prefs()..pinned = true);

    // Dev shares a Memory you can't see: the card says so.
    final dev = direct('dev', 'you');
    message(
      dev,
      'dev',
      ago(days * 2),
      text: 'Should we let them in on this?',
      shared: const SharedContent.memory('private-memory'),
    );
    message(
      dev,
      'dev',
      ago(days * 2 - minutes),
      text: 'Oops, wrong chat. That one is only for the planners!',
    );
    message(dev, 'you', ago(days * 2 - minutes * 10), text: 'Ha, ignored 🙈');
    message(
      dev,
      'dev',
      ago(minutes * 40),
      text: 'Lunch next week? Studio North has a poll going.',
    );
    dev.readAt.addAll({
      'you': ago(days * 2 - minutes * 10),
      'dev': ago(days * 2 - minutes * 10),
    });

    // Kavya shares only the large Northbank 2009 group: a message request.
    final kavya = direct('kavya', 'you')..pendingFor = 'you';
    message(
      kavya,
      'kavya',
      ago(hours * 5 + minutes * 30),
      text:
          'Hi! Are you the one who organised the 2009 farewell? I’d love a '
          'copy of the group photo.',
    );
    kavya.readAt['kavya'] = ago(hours * 5 + minutes * 30);

    // Lena: an archived conversation.
    final lena = direct('lena', 'you');
    message(lena, 'lena', ago(days * 8), text: 'Thanks for the pottery tips!');
    message(lena, 'you', ago(days * 8 - minutes * 3), text: 'Any time!');
    lena
      ..readAt.addAll({
        'you': ago(days * 8 - minutes * 3),
        'lena': ago(days * 8 - minutes * 3),
      })
      ..prefs['you'] = (_Prefs()..archived = true);

    // Fictional settings of other people, so New chat shows each reason.
    _privacy['noor'] = ChatPrivacy(
      whoCanMessage: WhoCanMessage.onlyPeopleIChattedWith,
    );
    _privacy['tomas'] = ChatPrivacy(whoCanMessage: WhoCanMessage.nobody);
  }
}

class _Access {
  _Access(this.workspace, this.conversation, {this.group});
  final CircleWorkspace workspace;
  final _Conversation conversation;

  /// The group of a group chat while the viewer is still a member.
  final CircleGroup? group;
}

class _Prefs {
  bool pinned = false, archived = false;
  bool muteChosen = false, mutedForever = false;
  DateTime? mutedUntil;
}

class _Conversation {
  _Conversation.group(this.id, String this.groupId, {required this.createdAt})
    : kind = ConversationKind.group,
      participants = const {};
  _Conversation.direct(this.id, this.participants, {required this.createdAt})
    : kind = ConversationKind.direct,
      groupId = null;

  final String id;
  final ConversationKind kind;
  final String? groupId;
  final DateTime createdAt;

  /// The two people of a 1:1 chat.
  final Set<String> participants;

  /// Group chats: the group's name and type, kept for a viewer who left.
  String title = '';
  CircleType? groupType;
  final List<ChatMessage> messages = [];

  /// Read markers: everything up to this time was seen by the person.
  final Map<String, DateTime> readAt = {};
  final Map<String, _Prefs> prefs = {};

  /// Group chats: people who were ever members, and when a viewer was
  /// first seen outside the group.
  final Set<String> knownMembers = {};
  final Map<String, DateTime> leftAt = {};

  /// 1:1: the recipient of a request that hasn't been accepted yet.
  String? pendingFor;
  final Set<String> acceptedBy = {};

  /// 1:1: when a person deleted the request.
  final Map<String, DateTime> hiddenAt = {};

  bool get isGroup => kind == ConversationKind.group;
}
