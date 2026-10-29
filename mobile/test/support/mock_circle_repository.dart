import 'package:mobile/features/groups/domain/membership_rules.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

/// Fictional classmates who make Northbank 2009 a large group (57 people).
const northbankClassmates = {
  'kavya': 'Kavya',
  'asha': 'Asha',
  'bilal': 'Bilal',
  'chen': 'Chen',
  'dara': 'Dara',
  'elif': 'Elif',
  'farah': 'Farah',
  'gopal': 'Gopal',
  'hana': 'Hana',
  'ivan': 'Ivan',
  'jonah': 'Jonah',
  'keiko': 'Keiko',
  'leo': 'Leo',
  'maya': 'Maya',
  'nikhil': 'Nikhil',
  'omar': 'Omar',
  'pia': 'Pia',
  'quinn': 'Quinn',
  'ravi': 'Ravi',
  'sara': 'Sara',
  'tariq': 'Tariq',
  'uma': 'Uma',
  'vikram': 'Vikram',
  'wen': 'Wen',
  'xavi': 'Xavi',
  'yara': 'Yara',
  'zoe': 'Zoe',
  'anil': 'Anil',
  'bea': 'Bea',
  'chidi': 'Chidi',
  'diya': 'Diya',
  'emil': 'Emil',
  'femi': 'Femi',
  'gita': 'Gita',
  'hugo': 'Hugo',
  'isha': 'Isha',
  'jules': 'Jules',
  'kofi': 'Kofi',
  'lina': 'Lina',
  'marco': 'Marco',
  'nadia': 'Nadia',
  'oren': 'Oren',
  'pooja': 'Pooja',
  'rhea': 'Rhea',
  'sunil': 'Sunil',
  'tara': 'Tara',
  'uri': 'Uri',
  'vera': 'Vera',
  'wes': 'Wes',
  'yusuf': 'Yusuf',
  'zara': 'Zara',
  'ines': 'Ines',
};

/// Session-local, fictional implementation. Nothing is sent or persisted.
/// Invite tokens are readable placeholders, not secure random values.
class MockCircleRepository implements CircleRepository {
  MockCircleRepository({bool showcase = false, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _seed(showcase: showcase);
  }
  final DateTime Function() _now;
  final Map<String, CircleGroup> _groups = {};
  List<_StoredMemory> _memories = [];
  List<CircleEvent> _events = [];

  /// Date polls of events, by event id.
  final Map<String, Poll> _eventPolls = {};
  List<JoinRequest> _requests = [];
  List<DirectInvitation> _invitations = [];

  /// Tokens that were reset or turned off, mapped to their group.
  final Map<String, String> _retiredTokens = {};

  /// When a person was removed, per group. Matches the backend rule: a
  /// removed person can only rejoin with a link created after the removal.
  final Map<String, Map<String, DateTime>> _removedAt = {};
  final Map<String, String> _names = {};
  int _sequence = 0;

  /// Open reports, reports an admin dismissed (kept for Undo), content keys
  /// admins hid, and the admin audit trail. Session-local and fictional.
  List<ContentReport> _reports = [];
  final Map<String, List<ContentReport>> _dismissed = {};

  /// Hidden content key → its group.
  final Map<String, String> _hidden = {};
  List<AuditEntry> _audit = [];

  @override
  Future<void> reset({required bool showcase}) async =>
      _seed(showcase: showcase);

  /// Everything is already here; there is no server to ask.
  @override
  Future<bool> refresh(String viewer) async => false;

  /// The preview has no pages: every Memory is loaded.
  @override
  Future<bool> loadMoreMemories(String viewer) async => false;

  /// Comments and reactions are always loaded in the preview.
  @override
  Future<bool> refreshMemory(String viewer, String memoryId) async => false;

  void _seed({required bool showcase}) {
    final seedTime = _now().toUtc();
    _sequence = 0;
    _groups.clear();
    _retiredTokens.clear();
    _removedAt.clear();
    _names
      ..clear()
      ..addAll(const {
        'you': 'You',
        'mira': 'Mira',
        'dev': 'Dev',
        'arjun': 'Arjun',
        'lena': 'Lena',
        'sam': 'Sam',
        'priya': 'Priya',
        'tomas': 'Tomas',
        'noor': 'Noor',
        ...northbankClassmates,
      });
    _memories = [];
    _events = [];
    _eventPolls.clear();
    _requests = [];
    _invitations = [];
    _reports = [];
    _dismissed.clear();
    _hidden.clear();
    _audit = [];
    if (!showcase) return;

    InviteLink link(String token, String by, {int days = 7, int? max}) =>
        InviteLink(
          token: token,
          createdBy: by,
          createdAt: seedTime.subtract(const Duration(days: 1)),
          expiresAt: seedTime.add(Duration(days: days)),
          maxUses: max,
          uses: max == null ? 0 : 3,
        );
    void add(
      String id,
      String name,
      CircleType type,
      Map<String, CircleRole> roles, {
      String? parent,
      bool hidden = false,
      bool approval = true,
      InvitePolicy policy = InvitePolicy.adminsOnly,
      EventCreationPolicy events = EventCreationPolicy.members,
      InviteLink? inviteLink,
    }) {
      _groups[id] = CircleGroup(
        id: id,
        name: name,
        type: type,
        depth: parent == null ? 1 : _groups[parent]!.depth + 1,
        parentId: parent,
        roles: roles,
        settings: GroupSettings(
          approvalRequired: approval,
          invitePolicy: policy,
          hidden: hidden,
          eventCreation: events,
        ),
        inviteLink: inviteLink,
        order: ++_sequence,
      );
    }

    const owner = CircleRole.owner, admin = CircleRole.admin;
    const member = CircleRole.member;
    add(
      'family',
      'The Sunday table',
      CircleType.family,
      {'you': owner, 'mira': admin, 'dev': member, 'priya': member},
      inviteLink: link('sunday-table-preview', 'you'),
    );
    _retiredTokens['sunday-table-old'] = 'family';
    add(
      'private-plans',
      'Surprise planners',
      CircleType.family,
      {'mira': owner, 'dev': member},
      parent: 'family',
      hidden: true,
    );
    add(
      'recipes',
      'Recipe swap',
      CircleType.family,
      {'priya': owner, 'mira': member},
      parent: 'family',
      approval: false,
    );
    add(
      'college',
      'Northbank 2009',
      CircleType.college,
      {
        'mira': owner,
        'you': admin,
        'dev': member,
        'sam': member,
        'noor': member,
        // A large batch (57 people): chat treats it as a big group, so
        // first messages from classmates wait in Requests (README §3.2).
        for (final id in northbankClassmates.keys) id: member,
      },
      inviteLink: link('northbank-2009-preview', 'mira'),
    );
    add(
      'cse',
      'Computer science',
      CircleType.college,
      {'dev': owner, 'you': member, 'sam': member},
      parent: 'college',
      policy: InvitePolicy.allMembers,
    );
    add('section', 'Section A', CircleType.college, {
      'dev': owner,
      'you': member,
    }, parent: 'cse');
    add(
      'friends',
      'The window-seat crew',
      CircleType.friends,
      {'dev': owner, 'you': member},
      parent: 'section',
      hidden: true,
    );
    add('ece', 'Electronics', CircleType.college, {
      'noor': owner,
      'sam': member,
    }, parent: 'college');
    add('meetup', 'Meetup helpers', CircleType.college, {
      'mira': owner,
      'noor': member,
    }, parent: 'college');
    add(
      'committee',
      'Organising committee',
      CircleType.college,
      {'mira': owner},
      parent: 'college',
      hidden: true,
    );
    // A listed subgroup the viewer is not in, reported by classmates. Its
    // parent's admins can remove it without reading it.
    add(
      'memes',
      'Late-night memes',
      CircleType.college,
      {'kavya': owner, 'asha': member, 'bilal': member},
      parent: 'college',
      approval: false,
    );
    add(
      'work',
      'Studio North',
      CircleType.office,
      {'dev': owner, 'you': member, 'lena': member},
      inviteLink: link('studio-north-preview', 'dev'),
      events: EventCreationPolicy.admins,
    );
    add(
      'social',
      'Studio social',
      CircleType.office,
      {'lena': owner, 'dev': member},
      parent: 'work',
      approval: false,
    );
    add(
      'quiz',
      'Quiz night',
      CircleType.office,
      {'lena': owner},
      parent: 'social',
      inviteLink: link('quiz-night-preview', 'lena'),
    );
    add(
      'board',
      'Board games',
      CircleType.office,
      {'dev': owner, 'lena': member},
      parent: 'work',
      hidden: true,
    );
    add(
      'club',
      'Sunday miles',
      CircleType.club,
      {'you': owner, 'mira': member, 'tomas': member},
      inviteLink: link('sunday-miles-preview', 'you', max: 25),
    );
    add('riders', 'Early riders', CircleType.club, {
      'you': owner,
      'mira': member,
    }, parent: 'club');
    add(
      'book',
      'Chapter & verse',
      CircleType.club,
      {'noor': owner, 'sam': member},
      inviteLink: link('chapter-verse-preview', 'noor'),
    );
    add(
      'garden',
      'Garden plot 14',
      CircleType.other,
      {'tomas': owner},
      approval: false,
      inviteLink: link('garden-plot-preview', 'tomas'),
    );
    add(
      'trip',
      'Hill trip',
      CircleType.friends,
      {'sam': owner},
      inviteLink: InviteLink(
        token: 'hill-trip-preview',
        createdBy: 'sam',
        createdAt: seedTime.subtract(const Duration(days: 30)),
        expiresAt: seedTime.subtract(const Duration(days: 23)),
      ),
    );
    add('cousins', 'Cousins’ corner', CircleType.family, {
      'priya': owner,
      'mira': member,
    });

    _requests = [
      JoinRequest(
        id: 'request-arjun-family',
        groupId: 'family',
        person: 'arjun',
        createdAt: seedTime.subtract(const Duration(hours: 3)),
        source: JoinRequestSource.link,
      ),
      JoinRequest(
        id: 'request-lena-club',
        groupId: 'club',
        person: 'lena',
        createdAt: seedTime.subtract(const Duration(hours: 5)),
        source: JoinRequestSource.link,
      ),
      JoinRequest(
        id: 'request-you-meetup',
        groupId: 'meetup',
        person: 'you',
        createdAt: seedTime.subtract(const Duration(hours: 8)),
        source: JoinRequestSource.listed,
      ),
    ];
    _invitations = [
      DirectInvitation(
        id: 'invite-cousins',
        groupId: 'cousins',
        invitee: 'you',
        inviter: 'priya',
        createdAt: seedTime.subtract(const Duration(hours: 2)),
      ),
      DirectInvitation(
        id: 'invite-board',
        groupId: 'board',
        invitee: 'you',
        inviter: 'dev',
        createdAt: seedTime.subtract(const Duration(hours: 6)),
      ),
      DirectInvitation(
        id: 'invite-tomas-riders',
        groupId: 'riders',
        invitee: 'tomas',
        inviter: 'you',
        createdAt: seedTime.subtract(const Duration(hours: 1)),
      ),
    ];
    _memories = _seedMemories(seedTime);
    _seedEvents(seedTime);
    _seedReports(seedTime);
  }

  /// Fictional reports from fictional classmates, so the Northbank 2009
  /// admins (including the viewer) have a small queue to review.
  void _seedReports(DateTime seedTime) {
    DateTime ago(Duration age) => seedTime.subtract(age);
    ContentReport report(
      String id,
      ReportTarget target,
      String reporter,
      ReportReason reason,
      Duration age, {
      String? summary,
      String? note,
    }) => ContentReport(
      id: id,
      target: target,
      reporter: reporter,
      reason: reason,
      createdAt: ago(age),
      summary: summary,
      note: note,
    );
    const spam = 'Selling cheap concert tickets — message me for the link!';
    const message = ReportTarget.message(
      'college-spam',
      conversationId: 'g-college',
      groupId: 'college',
      authorId: 'bilal',
    );
    const memes = ReportTarget.subgroup('memes', parentGroup: 'college');
    _reports = [
      report(
        'report-1',
        message,
        'dara',
        ReportReason.spam,
        const Duration(hours: 5),
        summary: spam,
      ),
      report(
        'report-2',
        message,
        'elif',
        ReportReason.spam,
        const Duration(hours: 4),
        summary: spam,
      ),
      report(
        'report-3',
        memes,
        'farah',
        ReportReason.harassment,
        const Duration(hours: 9),
        note: 'Jokes about one classmate, every night.',
      ),
      report(
        'report-4',
        memes,
        'gopal',
        ReportReason.harassment,
        const Duration(hours: 7),
      ),
      report(
        'report-5',
        memes,
        'hana',
        ReportReason.spam,
        const Duration(hours: 6),
      ),
    ];
    _audit = [
      AuditEntry(
        groupId: 'college',
        actorId: 'mira',
        action: 'dismissed a report about a comment',
        at: ago(const Duration(days: 1, hours: 2)),
      ),
    ];
  }

  // ---------------------------------------------------------------- helpers

  void _check(RuleResult result) {
    if (!result.allowed) throw CircleFailure(result.reason!);
  }

  CircleGroup _member(String viewer, String groupId) {
    final group = _groups[groupId];
    if (group == null || !group.isMember(viewer)) {
      throw const CircleFailure('This group is not shared with you.');
    }
    return group;
  }

  String _name(String person) => _names[person] ?? 'Someone';

  String _validName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 60) {
      throw const CircleFailure('Use a group name with 1–60 characters.');
    }
    return trimmed;
  }

  void _setRoles(CircleGroup group, Map<String, CircleRole> roles) =>
      _groups[group.id] = group.copyWith(roles: roles);

  void _addMember(CircleGroup group, String person) {
    final current = _groups[group.id]!;
    _setRoles(current, {...current.roles, person: CircleRole.member});
    _requests.removeWhere(
      (request) => request.groupId == group.id && request.person == person,
    );
    _invitations.removeWhere(
      (invitation) =>
          invitation.groupId == group.id && invitation.invitee == person,
    );
  }

  /// Removes [person] from [groupId] and every descendant they belong to,
  /// then closes requests/invitations they can no longer use.
  void _cascadeRemove(String groupId, String person) {
    for (final group in MembershipRules.cascade(_groups, groupId, person)) {
      _setRoles(group, {...group.roles}..remove(person));
    }
    _requests.removeWhere(
      (request) =>
          request.person == person &&
          !MembershipRules.canJoin(
            _groups[request.groupId]!,
            person,
            _groups,
          ).allowed,
    );
    _invitations.removeWhere(
      (invitation) =>
          invitation.invitee == person &&
          !MembershipRules.canJoin(
            _groups[invitation.groupId]!,
            person,
            _groups,
          ).allowed,
    );
  }

  String _newToken(CircleGroup group) {
    final slug = group.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'group' : slug}-${++_sequence}-preview';
  }

  GroupPreview _preview(CircleGroup group) => GroupPreview(
    id: group.id,
    name: group.name,
    type: group.type,
    memberCount: group.roles.length,
    approvalRequired: group.approvalRequired,
    parentId: group.parentId,
    parentName: _groups[group.parentId]?.name,
  );

  // ------------------------------------------------------------------- reads

  @override
  Future<CircleWorkspace> load(String viewer) async {
    final groups = [
      for (final group in _groups.values)
        if (group.isMember(viewer))
          MembershipRules.canInvite(group, viewer).allowed
              ? group
              : group.copyWith(clearInviteLink: true),
    ];
    final ids = groups.map((group) => group.id).toSet();
    final adminOf = {
      for (final group in groups)
        if (group.roles[viewer]!.isAdmin) group.id,
    };
    final invitable = {
      for (final group in groups)
        if (MembershipRules.canInvite(group, viewer).allowed) group.id,
    };
    bool shown(ReportKind kind, String id, String groupId) =>
        !_hidden.containsKey(ReportTarget.contentKey(kind, id)) ||
        adminOf.contains(groupId);
    final memories =
        [
          for (final memory in _memories)
            if (!memory.deleted &&
                ids.contains(memory.groupId) &&
                shown(ReportKind.memory, memory.id, memory.groupId))
              _view(memory, viewer),
        ]..sort((a, b) {
          final order = b.createdAt.compareTo(a.createdAt);
          return order == 0 ? b.id.compareTo(a.id) : order;
        });
    final joinRequests = _requests
        .where((request) => adminOf.contains(request.groupId))
        .toList();
    final sent = _invitations
        .where((invitation) => invitable.contains(invitation.groupId))
        .toList();
    final invitations = [
      for (final invitation in _invitations)
        if (invitation.invitee == viewer && _groups[invitation.groupId] != null)
          InvitationView(
            invitation: invitation,
            groupName: _groups[invitation.groupId]!.name,
            groupType: _groups[invitation.groupId]!.type,
            inviterName: _name(invitation.inviter),
            memberCount: _groups[invitation.groupId]!.roles.length,
            parentName: _groups[_groups[invitation.groupId]!.parentId]?.name,
          ),
    ];
    final people = <String, String>{
      for (final group in groups)
        for (final person in group.roles.keys) person: _name(person),
      for (final request in joinRequests) request.person: _name(request.person),
      for (final invitation in sent)
        invitation.invitee: _name(invitation.invitee),
    }..remove(viewer);
    return CircleWorkspace(
      viewer: viewer,
      groups: groups,
      memories: memories,
      events: [
        for (final event in _events)
          if (ids.contains(event.groupId) &&
              shown(ReportKind.event, event.id, event.groupId))
            _eventView(event, viewer),
      ]..sort(_byStart),
      discoverable: [
        for (final group in _groups.values)
          if (MembershipRules.isDiscoverable(group, viewer, _groups))
            _preview(group),
      ],
      pending: [
        for (final request in _requests)
          if (request.person == viewer)
            PendingGroup(
              requestId: request.id,
              groupId: request.groupId,
              name: _groups[request.groupId]!.name,
            ),
      ],
      invitations: invitations,
      joinRequests: joinRequests,
      sentInvitations: sent,
      people: people,
      hiddenByAdmins: {
        for (final entry in _hidden.entries)
          if (ids.contains(entry.value)) entry.key,
      },
      reportedByMe: {
        for (final report in [
          ..._reports,
          for (final list in _dismissed.values) ...list,
        ])
          if (report.reporter == viewer) report.target.key,
      },
      openReports: {
        for (final groupId in adminOf)
          if (_openCount(groupId) > 0) groupId: _openCount(groupId),
      },
    );
  }

  @override
  Future<CircleGroup> readGroup(String viewer, String groupId) async =>
      _member(viewer, groupId);

  // ------------------------------------------------------------------ groups

  @override
  Future<CircleGroup> createGroup(
    String viewer,
    String name,
    CircleType type, {
    String? parentId,
    bool hidden = false,
  }) async {
    final parent = parentId == null ? null : _groups[parentId];
    if (parentId != null && parent == null) {
      throw const CircleFailure('This group is not shared with you.');
    }
    _check(MembershipRules.canCreateGroup(person: viewer, parent: parent));
    final trimmed = _validName(name);
    final group = CircleGroup(
      id: 'local-${++_sequence}',
      name: trimmed,
      type: type,
      depth: (parent?.depth ?? 0) + 1,
      parentId: parentId,
      roles: {viewer: CircleRole.owner},
      settings: GroupSettings(hidden: parentId != null && hidden),
      order: _sequence,
    );
    _groups[group.id] = group;
    return group;
  }

  @override
  Future<void> updateSettings(
    String viewer,
    String groupId, {
    String? name,
    bool? approvalRequired,
    InvitePolicy? invitePolicy,
    bool? hidden,
    EventCreationPolicy? eventCreation,
  }) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canEditSettings(group, viewer));
    if (hidden != null && !group.isSubgroup) {
      throw const CircleFailure('Only subgroups can be listed or hidden.');
    }
    _groups[groupId] = group.copyWith(
      name: name == null ? null : _validName(name),
      settings: group.settings.copyWith(
        approvalRequired: approvalRequired,
        invitePolicy: invitePolicy,
        hidden: hidden,
        eventCreation: eventCreation,
      ),
    );
  }

  // -------------------------------------------------------------- membership

  @override
  Future<void> setRole(
    String viewer,
    String groupId,
    String person,
    CircleRole role,
  ) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canChangeRole(group, viewer, person, role));
    _setRoles(group, {...group.roles, person: role});
  }

  @override
  Future<List<String>> removalImpact(
    String viewer,
    String groupId,
    String person,
  ) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canReviewRequests(group, viewer));
    return [
      for (final child in MembershipRules.cascade(_groups, groupId, person))
        if (child.id != groupId &&
            (child.isMember(viewer) ||
                MembershipRules.isDiscoverable(child, viewer, _groups)))
          child.name,
    ];
  }

  @override
  Future<void> removeMember(
    String viewer,
    String groupId,
    String person,
  ) async {
    final group = _member(viewer, groupId);
    _check(
      MembershipRules.canRemove(
        group,
        viewer,
        person,
        ownedDescendants: MembershipRules.ownedDescendants(
          _groups,
          groupId,
          person,
        ),
      ),
    );
    final removedAt = _now().toUtc();
    for (final left in MembershipRules.cascade(_groups, groupId, person)) {
      (_removedAt[left.id] ??= {})[person] = removedAt;
    }
    _cascadeRemove(groupId, person);
    // Reports about this member are settled by the removal.
    _reports.removeWhere(
      (report) =>
          report.target.groupId == groupId &&
          report.target.kind == ReportKind.member &&
          report.target.id == person,
    );
    _log(groupId, viewer, 'removed ${_name(person)}');
  }

  @override
  Future<void> transferOwnership(
    String viewer,
    String groupId,
    String person,
  ) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canTransferOwnership(group, viewer, person));
    _setRoles(group, {
      ...group.roles,
      viewer: CircleRole.admin,
      person: CircleRole.owner,
    });
  }

  @override
  Future<void> leaveGroup(String viewer, String groupId) async {
    final group = _member(viewer, groupId);
    _check(
      MembershipRules.canLeave(
        group,
        viewer,
        MembershipRules.cascade(_groups, groupId, viewer),
      ),
    );
    _cascadeRemove(groupId, viewer);
  }

  @override
  Future<JoinOutcome> requestToJoin(String viewer, String groupId) async {
    final group = _groups[groupId];
    // Only listed subgroups can be requested; hidden ones need an invitation.
    if (group == null || !group.isSubgroup || group.hidden) {
      throw const CircleFailure('This group isn’t available to you.');
    }
    return _joinOrRequest(group, viewer, JoinRequestSource.listed);
  }

  JoinOutcome _joinOrRequest(
    CircleGroup group,
    String person,
    JoinRequestSource source,
  ) {
    _check(MembershipRules.canJoin(group, person, _groups));
    if (_requests.any(
      (request) => request.groupId == group.id && request.person == person,
    )) {
      throw const CircleFailure('Your request is already waiting.');
    }
    if (!group.approvalRequired) {
      _addMember(group, person);
      return JoinOutcome.joined;
    }
    _requests = [
      ..._requests,
      JoinRequest(
        id: 'request-${++_sequence}',
        groupId: group.id,
        person: person,
        createdAt: _now().toUtc(),
        source: source,
      ),
    ];
    return JoinOutcome.requested;
  }

  JoinRequest _request(String id) {
    final request = _requests.where((item) => item.id == id).firstOrNull;
    if (request == null) {
      throw const CircleFailure('This request has already been handled.');
    }
    return request;
  }

  @override
  Future<void> cancelRequest(String viewer, String requestId) async {
    final request = _request(requestId);
    if (request.person != viewer) {
      throw const CircleFailure('This request has already been handled.');
    }
    _requests.removeWhere((item) => item.id == requestId);
  }

  @override
  Future<void> approveRequest(String viewer, String requestId) async {
    final request = _request(requestId);
    final group = _member(viewer, request.groupId);
    _check(MembershipRules.canReviewRequests(group, viewer));
    final parent = _groups[group.parentId];
    if (parent != null && !parent.isMember(request.person)) {
      throw CircleFailure(
        '${_name(request.person)} is no longer in ${parent.name}, so they can’t join this subgroup. You can decline the request.',
      );
    }
    _check(MembershipRules.canJoin(group, request.person, _groups));
    _addMember(group, request.person);
  }

  @override
  Future<void> declineRequest(String viewer, String requestId) async {
    final request = _request(requestId);
    final group = _member(viewer, request.groupId);
    _check(MembershipRules.canReviewRequests(group, viewer));
    _requests.removeWhere((item) => item.id == requestId);
  }

  // ------------------------------------------------------------- invitations

  @override
  Future<InviteLink> createInviteLink(
    String viewer,
    String groupId, {
    Duration expiry = defaultInviteExpiry,
    int? maxUses,
  }) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canInvite(group, viewer));
    final existing = group.inviteLink;
    final now = _now().toUtc();
    if (existing != null && !existing.expiredAt(now) && !existing.exhausted) {
      return existing;
    }
    if (existing != null) _retiredTokens[existing.token] = groupId;
    final created = InviteLink(
      token: _newToken(group),
      createdBy: viewer,
      createdAt: now,
      expiresAt: now.add(expiry),
      maxUses: maxUses,
    );
    _groups[groupId] = group.copyWith(inviteLink: created);
    return created;
  }

  @override
  Future<void> configureInviteLink(
    String viewer,
    String groupId, {
    required Duration expiry,
    int? maxUses,
  }) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canManageLink(group, viewer));
    final current = group.inviteLink;
    if (current == null) {
      throw const CircleFailure('Create a link first.');
    }
    if (expiry <= Duration.zero || (maxUses != null && maxUses < 1)) {
      throw const CircleFailure('Choose a future expiry and a positive limit.');
    }
    final updated = current.copyWith(
      expiresAt: _now().toUtc().add(expiry),
      maxUses: maxUses,
    );
    _groups[groupId] = group.copyWith(
      inviteLink: maxUses == null ? updated.withoutLimit() : updated,
    );
  }

  @override
  Future<InviteLink> resetInviteLink(String viewer, String groupId) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canManageLink(group, viewer));
    final current = group.inviteLink;
    final now = _now().toUtc();
    if (current != null) _retiredTokens[current.token] = groupId;
    final created = InviteLink(
      token: _newToken(group),
      createdBy: viewer,
      createdAt: now,
      expiresAt: now.add(
        current == null || current.expiredAt(now)
            ? defaultInviteExpiry
            : current.expiresAt.difference(current.createdAt),
      ),
      maxUses: current?.maxUses,
    );
    _groups[groupId] = group.copyWith(inviteLink: created);
    return created;
  }

  @override
  Future<void> revokeInviteLink(String viewer, String groupId) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canManageLink(group, viewer));
    final current = group.inviteLink;
    if (current != null) _retiredTokens[current.token] = groupId;
    _groups[groupId] = group.copyWith(clearInviteLink: true);
  }

  @override
  Future<InvitePreview> previewInvite(String viewer, String input) async {
    final token = normalizeInviteToken(input);
    final group = _groups.values
        .where((group) => group.inviteLink?.token == token)
        .firstOrNull;
    if (group == null) {
      return InvitePreview(
        token: token,
        status: _retiredTokens.containsKey(token)
            ? InviteLinkStatus.reset
            : InviteLinkStatus.unknown,
      );
    }
    final link = group.inviteLink!;
    InvitePreview result(InviteLinkStatus status) => InvitePreview(
      status: status,
      token: token,
      group: _preview(group),
      inviterName: _name(link.createdBy),
    );
    if (link.expiredAt(_now().toUtc())) {
      return InvitePreview(status: InviteLinkStatus.expired, token: token);
    }
    if (link.exhausted) {
      return InvitePreview(status: InviteLinkStatus.exhausted, token: token);
    }
    if (group.isMember(viewer)) return result(InviteLinkStatus.alreadyMember);
    if (_requests.any(
      (request) => request.groupId == group.id && request.person == viewer,
    )) {
      return result(InviteLinkStatus.alreadyRequested);
    }
    if (!MembershipRules.canJoin(group, viewer, _groups).allowed) {
      return result(InviteLinkStatus.needsParent);
    }
    return result(InviteLinkStatus.valid);
  }

  @override
  Future<JoinOutcome> joinWithLink(String viewer, String input) async {
    final preview = await previewInvite(viewer, input);
    final message = switch (preview.status) {
      InviteLinkStatus.valid => null,
      InviteLinkStatus.alreadyMember => 'You are already in this group.',
      InviteLinkStatus.alreadyRequested => 'Your request is already waiting.',
      InviteLinkStatus.needsParent =>
        'Join ${preview.group?.parentName ?? 'the parent group'} first.',
      InviteLinkStatus.expired =>
        'This invite link has expired. Ask for a new one.',
      InviteLinkStatus.reset =>
        'This invite link was reset and no longer works. Ask for the new one.',
      InviteLinkStatus.exhausted =>
        'This invite link has reached its limit. Ask for a new one.',
      InviteLinkStatus.unknown => 'This invite link isn’t recognised.',
    };
    if (message != null) throw CircleFailure(message);
    final group = _groups[preview.group!.id]!;
    final removedAt = _removedAt[group.id]?[viewer];
    if (removedAt != null && !group.inviteLink!.createdAt.isAfter(removedAt)) {
      throw const CircleFailure(
        'You were removed from this group. Ask an admin for a new invite link.',
      );
    }
    final outcome = _joinOrRequest(group, viewer, JoinRequestSource.link);
    final link = _groups[group.id]!.inviteLink!;
    _groups[group.id] = _groups[group.id]!.copyWith(
      inviteLink: link.copyWith(uses: link.uses + 1),
    );
    return outcome;
  }

  @override
  Future<void> inviteMember(
    String viewer,
    String groupId,
    String person,
  ) async {
    final group = _member(viewer, groupId);
    _check(MembershipRules.canInvite(group, viewer));
    if (person == viewer || group.isMember(person)) {
      throw const CircleFailure('They are already in this group.');
    }
    if (!group.isSubgroup) {
      final shares = _groups.values.any(
        (other) => other.isMember(viewer) && other.isMember(person),
      );
      if (!shares) {
        throw const CircleFailure(
          'You can only add people who already share a group with you.',
        );
      }
    } else if (!_groups[group.parentId]!.isMember(person)) {
      throw CircleFailure(
        '${_name(person)} isn’t in ${_groups[group.parentId]!.name}.',
      );
    }
    if (_invitations.any(
      (invitation) =>
          invitation.groupId == groupId && invitation.invitee == person,
    )) {
      throw const CircleFailure('They already have an invitation waiting.');
    }
    _invitations = [
      ..._invitations,
      DirectInvitation(
        id: 'invitation-${++_sequence}',
        groupId: groupId,
        invitee: person,
        inviter: viewer,
        createdAt: _now().toUtc(),
      ),
    ];
  }

  DirectInvitation _invitation(String id) {
    final invitation = _invitations.where((item) => item.id == id).firstOrNull;
    if (invitation == null) {
      throw const CircleFailure('This invitation is no longer available.');
    }
    return invitation;
  }

  @override
  Future<void> cancelInvitation(String viewer, String invitationId) async {
    final invitation = _invitation(invitationId);
    final group = _groups[invitation.groupId];
    final allowed =
        invitation.inviter == viewer ||
        (group?.roles[viewer]?.isAdmin ?? false);
    if (!allowed) {
      throw const CircleFailure('Only the inviter or an admin can cancel.');
    }
    _invitations.removeWhere((item) => item.id == invitationId);
  }

  @override
  Future<JoinOutcome?> respondToInvitation(
    String viewer,
    String invitationId, {
    required bool accept,
  }) async {
    final invitation = _invitation(invitationId);
    if (invitation.invitee != viewer) {
      throw const CircleFailure('This invitation is no longer available.');
    }
    if (!accept) {
      _invitations.removeWhere((item) => item.id == invitationId);
      return null;
    }
    final group = _groups[invitation.groupId]!;
    _check(MembershipRules.canJoin(group, viewer, _groups));
    _invitations.removeWhere((item) => item.id == invitationId);
    final inviterIsAdmin = group.roles[invitation.inviter]?.isAdmin ?? false;
    if (inviterIsAdmin || !group.approvalRequired) {
      _addMember(group, viewer);
      return JoinOutcome.joined;
    }
    return _joinOrRequest(group, viewer, JoinRequestSource.invitation);
  }

  // ---------------------------------------------------------------- memories

  /// Fictional showcase Memories: photos are illustrated scenes, reaction
  /// counts come from made-up members, and both polls are local only.
  List<_StoredMemory> _seedMemories(DateTime seedTime) {
    DateTime ago(Duration age) => seedTime.subtract(age);

    /// Reactions from fictional people outside the viewer's view.
    Map<String, String> crowd(String id, Map<String, int> counts) => {
      for (final entry in counts.entries)
        for (var i = 1; i <= entry.value; i++)
          'fictional-$id-${memoryReactions.indexOf(entry.key)}-$i': entry.key,
    };
    List<MemoryPhoto> photos(String id, List<(MemoryScene, String?)> list) => [
      for (final (index, (scene, caption)) in list.indexed)
        MemoryPhoto(
          id: '$id-photo-${index + 1}',
          scene: scene,
          caption: caption,
        ),
    ];
    return [
      _StoredMemory(
        id: 'table',
        groupId: 'family',
        authorId: 'mira',
        text:
            'Same table, a few new stories. Sunday lunch is still my favourite way to bring everyone together.',
        createdAt: ago(const Duration(hours: 1)),
        photos: photos('table', [
          (MemoryScene.sundayLunch, 'Room for one more'),
          (MemoryScene.birthdayCake, 'Priya’s cake, slightly lopsided'),
          (MemoryScene.templeFestival, null),
          (MemoryScene.weddingStage, 'Last year’s big day'),
        ]),
        reactions: crowd('table', {'❤️': 12, '😂': 3, '🙏': 1}),
        comments: [
          MemoryComment(
            id: 'table-comment-1',
            authorId: 'dev',
            authorName: 'Dev',
            text: 'I’m bringing dessert next time.',
            createdAt: ago(const Duration(minutes: 50)),
          ),
          MemoryComment(
            id: 'table-comment-2',
            authorId: 'mira',
            authorName: 'Mira',
            text: 'Holding you to that.',
            createdAt: ago(const Duration(minutes: 40)),
            parentId: 'table-comment-1',
          ),
        ],
      ),
      _StoredMemory(
        id: 'reunion-poll',
        groupId: 'college',
        authorId: 'mira',
        text: 'Fifteen years! Help me pick a place for the reunion dinner.',
        createdAt: ago(const Duration(hours: 5)),
        poll: Poll(
          id: 'reunion-poll-poll',
          question: 'Where should the reunion dinner be?',
          createdBy: 'mira',
          options: const [
            PollOption(id: 'reunion-canteen', label: 'The old canteen'),
            PollOption(id: 'reunion-cafe', label: 'Riverside café'),
            PollOption(id: 'reunion-terrace', label: 'Someone’s terrace'),
          ],
          closesAt: seedTime.add(const Duration(days: 2, hours: 1)),
          votes: const {
            'mira': {'reunion-canteen'},
            'dev': {'reunion-cafe'},
            'sam': {'reunion-canteen'},
          },
        ),
        reactions: crowd('reunion-poll', {'🎉': 2}),
      ),
      _StoredMemory(
        id: 'ride',
        groupId: 'club',
        authorId: 'dev',
        text:
            'A slow ride, a long breakfast, and absolutely no one checking the time.',
        createdAt: ago(const Duration(days: 1)),
        photos: photos('ride', [
          (MemoryScene.hillTrip, 'The scenic route'),
          (MemoryScene.beachWalk, 'Breakfast by the water'),
        ]),
        reactions: crowd('ride', {'❤️': 7, '🔥': 2}),
        comments: [
          // A real @mention of the viewer: it shows in Activity.
          MemoryComment(
            id: 'ride-comment-1',
            authorId: 'tomas',
            authorName: 'Tomas',
            text: '@You, saving you a seat at breakfast next time.',
            createdAt: ago(const Duration(hours: 20)),
            mentions: const {'you': 'You'},
          ),
        ],
      ),
      _StoredMemory(
        id: 'old-days',
        groupId: 'friends',
        authorId: 'mira',
        text:
            'Found our old project notes. The ideas were ambitious. The handwriting, less so.',
        createdAt: ago(const Duration(days: 2)),
        takenYear: 2007,
        place: 'Kodaikanal',
        photos: photos('old-days', [(MemoryScene.oldClassroom, null)]),
        reactions: crowd('old-days', {'❤️': 4}),
      ),
      _StoredMemory(
        id: 'route-poll',
        groupId: 'club',
        authorId: 'tomas',
        text: '',
        createdAt: ago(const Duration(days: 3)),
        poll: Poll(
          id: 'route-poll-poll',
          question: 'Which route for the season’s last ride?',
          createdBy: 'tomas',
          anonymous: true,
          resultsVisibility: PollResultsVisibility.afterClosing,
          options: const [
            PollOption(id: 'route-lake', label: 'Around the lake'),
            PollOption(id: 'route-hills', label: 'Through the hills'),
          ],
          closedAt: ago(const Duration(days: 1)),
          votes: const {
            'you': {'route-lake'},
            'mira': {'route-lake'},
            'tomas': {'route-hills'},
          },
        ),
      ),
      _StoredMemory(
        id: 'private-memory',
        groupId: 'private-plans',
        authorId: 'mira',
        text: 'A private planning note.',
        createdAt: ago(const Duration(minutes: 30)),
      ),
    ];
  }

  String _display(String person, String viewer) =>
      person == viewer ? 'You' : _name(person);

  CircleMemory _view(_StoredMemory memory, String viewer) {
    final group = _groups[memory.groupId]!;
    final admin = group.roles[viewer]?.isAdmin ?? false;
    // Deleted comments, and (for non-admins) comments admins hid.
    final hidden = {
      ...memory.deletedComments,
      if (!admin)
        for (final comment in memory.comments)
          if (_hidden.containsKey(
            ReportTarget.contentKey(ReportKind.comment, comment.id),
          ))
            comment.id,
    };
    return CircleMemory(
      id: memory.id,
      groupId: memory.groupId,
      authorId: memory.authorId,
      author: _display(memory.authorId, viewer),
      text: memory.text,
      createdAt: memory.createdAt,
      editedAt: memory.editedAt,
      photos: memory.photos,
      poll: memory.poll == null
          ? null
          : PollRules.view(
              memory.poll!,
              viewer: viewer,
              isMember: group.isMember(viewer),
              isAdmin: group.roles[viewer]?.isAdmin ?? false,
              now: _now().toUtc(),
              nameOf: (person) => _display(person, viewer),
            ),
      takenYear: memory.takenYear,
      place: memory.place,
      comments: [
        for (final comment in memory.comments)
          if (!hidden.contains(comment.id) &&
              !hidden.contains(comment.parentId))
            comment.copyWith(authorName: _display(comment.authorId, viewer)),
      ],
      reactions: ReactionRules.viewFor(memory.reactions, viewer),
      saved: memory.savedBy.contains(viewer),
    );
  }

  /// Finds a Memory and re-checks exact-group membership for [viewer].
  _StoredMemory _memory(
    String viewer,
    String id, {
    bool includeDeleted = false,
  }) {
    final memory = _memories.where((memory) => memory.id == id).firstOrNull;
    if (memory == null || (memory.deleted && !includeDeleted)) {
      throw const CircleFailure('This Memory is unavailable.');
    }
    final group = _member(viewer, memory.groupId);
    if (_hidden.containsKey(ReportTarget.contentKey(ReportKind.memory, id)) &&
        !group.roles[viewer]!.isAdmin) {
      throw const CircleFailure('This Memory is unavailable.');
    }
    return memory;
  }

  _StoredMemory _ownMemory(String viewer, String id, {bool deleted = false}) {
    final memory = _memory(viewer, id, includeDeleted: deleted);
    _check(MemoryRules.canChange(memory.authorId, viewer));
    return memory;
  }

  Poll _poll(_StoredMemory memory) =>
      memory.poll ?? (throw const CircleFailure('This Memory has no poll.'));

  @override
  Future<String> createMemory(
    String viewer,
    String groupId,
    String text, {
    List<MemoryScene> photos = const [],
    List<String?> captions = const [],
    List<String> mediaIds = const [],
    PollDraft? poll,
    int? takenYear,
    String? place,
  }) async {
    _member(viewer, groupId);
    for (final caption in captions) {
      _check(PhotoCaptionRules.check(caption));
    }
    if (mediaIds.isNotEmpty) {
      throw const CircleFailure(
        'The preview uses fictional illustrations, not uploaded photos.',
      );
    }
    final now = _now().toUtc();
    _check(
      MemoryRules.checkContent(
        text: text,
        photoCount: photos.length,
        hasPoll: poll != null,
      ),
    );
    if (poll != null) _check(PollRules.checkDraft(poll));
    _check(MemoryRules.checkYear(takenYear, now));
    _check(MemoryRules.checkPlace(place));
    final id = 'local-memory-${(++_sequence).toString().padLeft(8, '0')}';
    _memories = [
      _StoredMemory(
        id: id,
        groupId: groupId,
        authorId: viewer,
        text: text.trim(),
        createdAt: now,
        photos: [
          for (final (index, scene) in photos.indexed)
            MemoryPhoto(
              id: '$id-photo-${index + 1}',
              scene: scene,
              caption: PhotoCaptionRules.clean(
                index < captions.length ? captions[index] : null,
              ),
            ),
        ],
        poll: poll == null
            ? null
            : PollRules.create(
                poll,
                id: '$id-poll',
                createdBy: viewer,
                now: now,
              ),
        takenYear: takenYear,
        place: MemoryRules.cleanPlace(place),
      ),
      ..._memories,
    ];
    return id;
  }

  @override
  Future<void> editMemory(String viewer, String memoryId, String text) async {
    final memory = _ownMemory(viewer, memoryId);
    _check(
      MemoryRules.checkContent(
        text: text,
        photoCount: memory.photos.length,
        hasPoll: memory.poll != null,
      ),
    );
    final value = text.trim();
    if (value == memory.text) return;
    memory
      ..text = value
      ..editedAt = _now().toUtc();
  }

  @override
  Future<void> deleteMemory(String viewer, String memoryId) async =>
      _ownMemory(viewer, memoryId).deleted = true;

  @override
  Future<void> restoreMemory(String viewer, String memoryId) async =>
      _ownMemory(viewer, memoryId, deleted: true).deleted = false;

  @override
  Future<void> loveMemory(String viewer, String memoryId) =>
      react(viewer, memoryId, loveReaction);

  @override
  Future<void> react(String viewer, String memoryId, String emoji) async {
    final memory = _memory(viewer, memoryId);
    _check(ReactionRules.check(emoji));
    memory.reactions = ReactionRules.toggle(memory.reactions, viewer, emoji);
  }

  @override
  Future<void> saveMemory(String viewer, String memoryId) async {
    final saved = _memory(viewer, memoryId).savedBy;
    if (!saved.remove(viewer)) saved.add(viewer);
  }

  @override
  Future<String> comment(
    String viewer,
    String memoryId,
    String text, {
    String? replyTo,
    Map<String, String> mentions = const {},
  }) async {
    final memory = _memory(viewer, memoryId);
    _check(CommentRules.checkText(text));
    final members = _groups[memory.groupId]!.roles.keys.toSet();
    if (replyTo != null) {
      _check(
        CommentRules.canReply([
          for (final comment in memory.comments)
            if (!memory.deletedComments.contains(comment.id)) comment,
        ], replyTo),
      );
    }
    final id = 'comment-${++_sequence}';
    memory.comments = [
      ...memory.comments,
      MemoryComment(
        id: id,
        authorId: viewer,
        authorName: _name(viewer),
        text: text.trim(),
        createdAt: _now().toUtc(),
        parentId: replyTo,
        // Only members of this exact group, and only names still written.
        mentions: MentionRules.resolve(
          text: text.trim(),
          picked: mentions,
          members: members,
        ),
      ),
    ];
    return id;
  }

  MemoryComment _comment(_StoredMemory memory, String id) =>
      memory.comments.where((comment) => comment.id == id).firstOrNull ??
      (throw const CircleFailure('That comment is no longer here.'));

  @override
  Future<void> deleteComment(
    String viewer,
    String memoryId,
    String commentId,
  ) async {
    final memory = _memory(viewer, memoryId);
    final comment = _comment(memory, commentId);
    if (memory.deletedComments.contains(commentId)) {
      throw const CircleFailure('That comment is no longer here.');
    }
    _check(CommentRules.canDelete(comment, viewer));
    memory.deletedComments.add(commentId);
  }

  @override
  Future<void> restoreComment(
    String viewer,
    String memoryId,
    String commentId,
  ) async {
    final memory = _memory(viewer, memoryId);
    _check(CommentRules.canDelete(_comment(memory, commentId), viewer));
    memory.deletedComments.remove(commentId);
  }

  @override
  Future<void> vote(
    String viewer,
    String memoryId,
    Set<String> optionIds,
  ) async {
    final memory = _memory(viewer, memoryId);
    final poll = _poll(memory);
    _check(
      PollRules.canVote(
        poll,
        voter: viewer,
        isMember: true,
        choices: optionIds,
        now: _now().toUtc(),
      ),
    );
    memory.poll = poll.withVote(viewer, {...optionIds});
  }

  @override
  Future<void> retractVote(String viewer, String memoryId) async {
    final memory = _memory(viewer, memoryId);
    final poll = _poll(memory);
    _check(
      PollRules.canRetract(
        poll,
        voter: viewer,
        isMember: true,
        now: _now().toUtc(),
      ),
    );
    memory.poll = poll.withVote(viewer, const {});
  }

  @override
  Future<void> closePoll(String viewer, String memoryId) async {
    final memory = _memory(viewer, memoryId);
    final poll = _poll(memory);
    final now = _now().toUtc();
    _check(
      PollRules.canClose(
        poll,
        actor: viewer,
        isMember: true,
        isAdmin: _groups[memory.groupId]!.roles[viewer]!.isAdmin,
        now: now,
      ),
    );
    memory.poll = poll.closed(now);
  }

  // ------------------------------------------------------------------ events

  /// Showcase events are planned in India Standard Time.
  static const _ist = Duration(hours: 5, minutes: 30);

  static int _byStart(CircleEvent a, CircleEvent b) {
    final order = a.startsAt.compareTo(b.startsAt);
    return order == 0 ? a.id.compareTo(b.id) : order;
  }

  /// Fictional showcase events across several groups, relative to
  /// [seedTime]: a family function with guests, a ride, a reunion with a
  /// date poll, an online call, a full workshop, a past picnic and one
  /// event in a hidden subgroup the viewer is not in.
  void _seedEvents(DateTime seedTime) {
    final today = wallClock(seedTime, _ist);
    DateTime at(int days, int hour, [int minute = 0]) => fromWallClock(
      DateTime.utc(today.year, today.month, today.day + days, hour, minute),
      _ist,
    );
    CircleEvent event(
      String id,
      String groupId,
      String createdBy,
      EventType type,
      String title,
      DateTime start, {
      List<String> coHosts = const [],
      DateTime? end,
      String? venue,
      String? link,
      String? description,
      DateTime? deadline,
      int? capacity,
      Map<String, Rsvp> rsvps = const {},
      String? datePollId,
    }) => CircleEvent(
      id: id,
      groupId: groupId,
      createdBy: createdBy,
      hosts: [createdBy, ...coHosts],
      type: type,
      title: title,
      startsAt: start,
      endsAt: end,
      timeZoneLabel: 'IST',
      utcOffset: _ist,
      createdAt: seedTime.subtract(const Duration(days: 20)),
      venue: venue,
      onlineLink: link,
      description: description,
      rsvpDeadline: deadline,
      capacity: capacity,
      rsvps: rsvps,
      datePollId: datePollId,
    );

    const going = Attendance.going, maybe = Attendance.maybe;
    _events = [
      event(
        'lunch',
        'family',
        'mira',
        EventType.familyFunction,
        'A Sunday well spent',
        at(2, 12, 30),
        end: at(2, 16),
        venue: 'The family table · Fictional venue',
        description:
            'Lunch at home with everyone. Bring an appetite — dessert is covered.',
        deadline: at(1, 20),
        capacity: 20,
        rsvps: const {
          'mira': Rsvp(going, guests: 3, note: 'Bringing the kids'),
          'priya': Rsvp(going, guests: 4, note: 'Will arrive after lunch'),
          'dev': Rsvp(maybe, guests: 1),
        },
      ),
      event(
        'catch-up',
        'cse',
        'dev',
        EventType.online,
        'Computer science catch-up call',
        at(5, 20),
        end: at(5, 21, 30),
        link: 'meet.example.invalid/cse-catch-up',
        description:
            'A short video call to plan the reunion. Fictional link; nothing opens in this preview.',
        rsvps: const {'dev': Rsvp(going), 'sam': Rsvp(maybe)},
      ),
      event(
        'cycling',
        'club',
        'you',
        EventType.meetup,
        'Take the long way home',
        at(9, 6, 30),
        coHosts: const ['mira'],
        end: at(9, 9, 30),
        venue: 'Lakeside meeting point · Fictional venue',
        rsvps: const {
          'tomas': Rsvp(going),
          'mira': Rsvp(Attendance.notGoing, note: 'Away that weekend'),
        },
      ),
      event(
        'workshop',
        'work',
        'dev',
        EventType.meetup,
        'Pottery afternoon',
        at(12, 15),
        coHosts: const ['lena'],
        end: at(12, 17),
        venue: 'Studio North kitchen · Fictional venue',
        capacity: 4,
        rsvps: const {'lena': Rsvp(going, guests: 2), 'dev': Rsvp(going)},
      ),
      event(
        'reunion',
        'college',
        'mira',
        EventType.reunion,
        'Fifteen-year reunion dinner',
        at(30, 19),
        end: at(30, 23),
        venue: 'The old canteen · Fictional venue',
        description: 'Vote for the date that works for you.',
        rsvps: const {'mira': Rsvp(going), 'sam': Rsvp(maybe)},
        datePollId: 'reunion-date-poll',
      ),
      event(
        'picnic',
        'club',
        'mira',
        EventType.other,
        'Autumn picnic',
        at(-10, 11),
        end: at(-10, 15),
        venue: 'Riverside lawn · Fictional venue',
        rsvps: const {
          'you': Rsvp(going, guests: 1, note: 'Bringing the blanket'),
          'mira': Rsvp(going),
          'tomas': Rsvp(maybe),
        },
      ),
      event(
        'surprise',
        'private-plans',
        'mira',
        EventType.birthday,
        'Surprise party',
        at(20, 18),
        venue: 'A secret place · Fictional venue',
      ),
    ];
    final poll = PollRules.create(
      EventRules.datePollDraft(
        DatePollDraft(slots: [at(30, 19), at(37, 19), at(44, 19)]),
        offset: _ist,
        zone: 'IST',
        today: today,
      ),
      id: 'reunion-date-poll',
      createdBy: 'mira',
      now: seedTime.subtract(const Duration(days: 20)),
    );
    _eventPolls['reunion'] = poll
        .withVote('mira', {
          'reunion-date-poll-option-1',
          'reunion-date-poll-option-2',
        })
        .withVote('dev', {'reunion-date-poll-option-1'})
        .withVote('sam', {'reunion-date-poll-option-2'});
  }

  /// The event as [viewer] sees it: hosts and RSVPs of people still in the
  /// exact group, and the date poll projected for the viewer.
  CircleEvent _eventView(CircleEvent event, String viewer) {
    final group = _groups[event.groupId]!;
    final poll = _eventPolls[event.id];
    return event.copyWith(
      hosts: [
        for (final host in event.hosts)
          if (group.isMember(host)) host,
      ],
      rsvps: {
        for (final entry in event.rsvps.entries)
          if (group.isMember(entry.key)) entry.key: entry.value,
      },
      datePoll: poll == null
          ? null
          : PollRules.view(
              poll,
              viewer: viewer,
              isMember: group.isMember(viewer),
              isAdmin: group.roles[viewer]?.isAdmin ?? false,
              now: _now().toUtc(),
              nameOf: (person) => _display(person, viewer),
            ),
    );
  }

  /// Finds an event and re-checks exact-group membership for [viewer].
  CircleEvent _storedEvent(String viewer, String id) {
    final event = _events.where((event) => event.id == id).firstOrNull;
    if (event == null) throw const CircleFailure('This event is unavailable.');
    final group = _member(viewer, event.groupId);
    if (_hidden.containsKey(ReportTarget.contentKey(ReportKind.event, id)) &&
        !group.roles[viewer]!.isAdmin) {
      throw const CircleFailure('This event is unavailable.');
    }
    return event;
  }

  void _replaceEvent(CircleEvent updated) => _events = [
    for (final event in _events) event.id == updated.id ? updated : event,
  ];

  /// Co-hosts must be members of the exact group; the creator is a host
  /// already and duplicates are dropped.
  List<String> _coHosts(CircleGroup group, String creator, List<String> list) {
    final result = <String>[];
    for (final person in list) {
      if (person == creator || result.contains(person)) continue;
      if (!group.isMember(person)) {
        throw const CircleFailure('Co-hosts need to be members of this group.');
      }
      result.add(person);
    }
    return result;
  }

  void _checkManage(CircleEvent stored, String viewer, DateTime now) => _check(
    EventRules.canManage(
      _eventView(stored, viewer),
      viewer,
      isMember: true,
      isAdmin: _groups[stored.groupId]!.roles[viewer]!.isAdmin,
      now: now,
    ),
  );

  @override
  Future<String> createEvent(String viewer, EventDraft draft) async {
    final group = _member(viewer, draft.groupId);
    _check(MembershipRules.canCreateEvent(group, viewer));
    final now = _now().toUtc();
    _check(EventRules.checkDraft(draft, now: now));
    final coHosts = _coHosts(group, viewer, draft.coHosts);
    final id = 'local-event-${(++_sequence).toString().padLeft(8, '0')}';
    final datePoll = draft.datePoll;
    Poll? poll;
    if (datePoll != null) {
      final pollDraft = EventRules.datePollDraft(
        datePoll,
        offset: draft.utcOffset,
        zone: draft.timeZoneLabel,
        today: wallClock(now, draft.utcOffset),
      );
      _check(PollRules.checkDraft(pollDraft));
      poll = PollRules.create(
        pollDraft,
        id: '$id-date-poll',
        createdBy: viewer,
        now: now,
      );
    }
    _events = [
      ..._events,
      CircleEvent(
        id: id,
        groupId: group.id,
        createdBy: viewer,
        hosts: [viewer, ...coHosts],
        type: draft.type,
        title: draft.title.trim(),
        startsAt: draft.startsAt!.toUtc(),
        endsAt: draft.endsAt?.toUtc(),
        timeZoneLabel: draft.timeZoneLabel,
        utcOffset: draft.utcOffset,
        createdAt: now,
        description: EventRules.clean(draft.description),
        venue: EventRules.clean(draft.venue),
        onlineLink: EventRules.clean(draft.onlineLink),
        rsvpDeadline: draft.rsvpDeadline?.toUtc(),
        capacity: draft.capacity,
        datePollId: poll?.id,
      ),
    ];
    if (poll != null) _eventPolls[id] = poll;
    return id;
  }

  @override
  Future<void> editEvent(
    String viewer,
    String eventId,
    EventDraft draft,
  ) async {
    final stored = _storedEvent(viewer, eventId);
    final now = _now().toUtc();
    _checkManage(stored, viewer, now);
    if (draft.groupId != stored.groupId) {
      throw const CircleFailure('An event can’t move to another group.');
    }
    _check(
      EventRules.checkDraft(draft, now: now, originalStart: stored.startsAt),
    );
    final group = _groups[stored.groupId]!;
    _replaceEvent(
      stored.copyWith(
        clearOptional: true,
        hosts: [
          stored.createdBy,
          ..._coHosts(group, stored.createdBy, draft.coHosts),
        ],
        type: draft.type,
        title: draft.title.trim(),
        startsAt: draft.startsAt!.toUtc(),
        endsAt: draft.endsAt?.toUtc(),
        description: EventRules.clean(draft.description),
        venue: EventRules.clean(draft.venue),
        onlineLink: EventRules.clean(draft.onlineLink),
        rsvpDeadline: draft.rsvpDeadline?.toUtc(),
        capacity: draft.capacity,
        editedAt: now,
      ),
    );
  }

  @override
  Future<void> cancelEvent(String viewer, String eventId) async {
    final stored = _storedEvent(viewer, eventId);
    final now = _now().toUtc();
    _checkManage(stored, viewer, now);
    _replaceEvent(stored.copyWith(cancelledAt: now));
  }

  @override
  Future<void> rsvp(String viewer, String eventId, Rsvp? response) async {
    final stored = _storedEvent(viewer, eventId);
    final view = _eventView(stored, viewer);
    final now = _now().toUtc();
    if (response == null) {
      _check(EventRules.canClearRsvp(view, viewer, isMember: true, now: now));
      _replaceEvent(stored.copyWith(rsvps: {...stored.rsvps}..remove(viewer)));
      return;
    }
    _check(
      EventRules.canRsvp(view, viewer, response, isMember: true, now: now),
    );
    _replaceEvent(
      stored.copyWith(
        rsvps: {
          ...stored.rsvps,
          viewer: Rsvp(
            response.status,
            guests: response.guests,
            note: EventRules.clean(response.note),
          ),
        },
      ),
    );
  }

  Poll _datePoll(CircleEvent event) =>
      _eventPolls[event.id] ??
      (throw const CircleFailure('This event has no date poll.'));

  @override
  Future<void> voteEventPoll(
    String viewer,
    String eventId,
    Set<String> optionIds,
  ) async {
    final event = _storedEvent(viewer, eventId);
    final poll = _datePoll(event);
    _check(
      PollRules.canVote(
        poll,
        voter: viewer,
        isMember: true,
        choices: optionIds,
        now: _now().toUtc(),
      ),
    );
    _eventPolls[event.id] = poll.withVote(viewer, {...optionIds});
  }

  @override
  Future<void> retractEventPollVote(String viewer, String eventId) async {
    final event = _storedEvent(viewer, eventId);
    final poll = _datePoll(event);
    _check(
      PollRules.canRetract(
        poll,
        voter: viewer,
        isMember: true,
        now: _now().toUtc(),
      ),
    );
    _eventPolls[event.id] = poll.withVote(viewer, const {});
  }

  @override
  Future<void> closeEventPoll(String viewer, String eventId) async {
    final event = _storedEvent(viewer, eventId);
    final poll = _datePoll(event);
    final now = _now().toUtc();
    _check(
      PollRules.canClose(
        poll,
        actor: viewer,
        isMember: true,
        isAdmin: _groups[event.groupId]!.roles[viewer]!.isAdmin,
        now: now,
      ),
    );
    _eventPolls[event.id] = poll.closed(now);
  }

  // -------------------------------------------------------------- moderation

  /// Reported items (not reports) waiting in [groupId]'s queue.
  int _openCount(String groupId) => {
    for (final report in _reports)
      if (report.target.groupId == groupId) report.target.key,
  }.length;

  void _log(String groupId, String actor, String action) => _audit = [
    AuditEntry(
      groupId: groupId,
      actorId: actor,
      action: action,
      at: _now().toUtc(),
    ),
    ..._audit,
  ];

  CircleGroup _moderated(String viewer, String groupId) {
    final group = _member(viewer, groupId);
    _check(ModerationRules.canModerate(group, viewer));
    return group;
  }

  /// Resolves what [draft] points at from the repository's own records, so
  /// the group, author and summary can't be made up by the caller.
  ({ReportTarget target, String? summary}) _resolve(
    String viewer,
    ReportDraft draft,
  ) {
    final target = draft.target;
    switch (target.kind) {
      case ReportKind.memory:
        final memory = _memory(viewer, target.id);
        return (
          target: ReportTarget.memory(
            memory.id,
            groupId: memory.groupId,
          ).withPerson(memory.authorId),
          summary: memory.text.isNotEmpty
              ? memory.text
              : memory.poll?.question ?? 'A Memory with photos',
        );
      case ReportKind.comment:
        final memory = _memory(viewer, target.parentId ?? '');
        final comment = _comment(memory, target.id);
        if (memory.deletedComments.contains(comment.id)) {
          throw const CircleFailure('That comment is no longer here.');
        }
        return (
          target: ReportTarget.comment(
            comment.id,
            memoryId: memory.id,
            groupId: memory.groupId,
          ).withPerson(comment.authorId),
          summary: comment.text,
        );
      case ReportKind.event:
        final event = _storedEvent(viewer, target.id);
        return (
          target: ReportTarget.event(
            event.id,
            groupId: event.groupId,
          ).withPerson(event.createdBy),
          summary: event.title,
        );
      case ReportKind.message:
        // The chat service checked the message; a group chat is reviewed
        // by that group's admins, a 1:1 message by the platform.
        final groupId = target.groupId;
        if (groupId != null) _member(viewer, groupId);
        return (target: target, summary: draft.summary);
      case ReportKind.member:
        // A 1:1 chat report goes to the platform; the chat checked it.
        if (target.groupId == null) {
          return (target: target, summary: _name(target.id));
        }
        final group = _member(viewer, target.groupId!);
        if (!group.isMember(target.id)) {
          throw const CircleFailure('This person is not in the group.');
        }
        return (
          target: ReportTarget.member(target.id, groupId: group.id),
          summary: _name(target.id),
        );
      case ReportKind.subgroup:
        final parent = _member(viewer, target.groupId ?? '');
        final subgroup = _groups[target.id];
        if (subgroup == null ||
            subgroup.parentId != parent.id ||
            (subgroup.hidden && !subgroup.isMember(viewer))) {
          throw const CircleFailure('This subgroup isn’t available to you.');
        }
        return (
          target: ReportTarget.subgroup(subgroup.id, parentGroup: parent.id),
          summary: null,
        );
    }
  }

  @override
  Future<void> report(String viewer, ReportDraft draft) async {
    final resolved = _resolve(viewer, draft);
    _check(
      ModerationRules.canReport(
        reporter: viewer,
        target: resolved.target,
        existing: [..._reports, for (final list in _dismissed.values) ...list],
      ),
    );
    _check(ModerationRules.checkNote(draft.note));
    _reports = [
      ..._reports,
      ContentReport(
        id: 'report-${++_sequence}',
        target: resolved.target,
        reporter: viewer,
        reason: draft.reason,
        createdAt: _now().toUtc(),
        note: ModerationRules.cleanNote(draft.note),
        summary: resolved.summary,
      ),
    ];
  }

  @override
  Future<ModerationQueue> queue(String viewer, String groupId) async {
    final group = _moderated(viewer, groupId);
    final items = <QueueItem>[];
    for (final entry in ModerationRules.aggregate(_reports, groupId)) {
      final target = entry.target;
      final person = target.personId;
      final subgroup = target.kind == ReportKind.subgroup
          ? _groups[target.id]
          : null;
      if (target.kind == ReportKind.subgroup && subgroup == null) continue;
      items.add(
        QueueItem(
          target: target,
          reasons: entry.reasons,
          latestAt: entry.latestAt,
          hidden: _hidden.containsKey(target.key),
          // Parent admins never read a subgroup: name and size only.
          summary: subgroup == null ? entry.summary : null,
          personName: person == null ? null : _display(person, viewer),
          notes: subgroup == null ? entry.notes : const [],
          canRemovePerson:
              person != null &&
              group.isMember(person) &&
              MembershipRules.canRemove(
                group,
                viewer,
                person,
                ownedDescendants: MembershipRules.ownedDescendants(
                  _groups,
                  groupId,
                  person,
                ),
              ).allowed,
          subgroupName: subgroup?.name,
          subgroupMemberCount: subgroup?.roles.length,
        ),
      );
    }
    return ModerationQueue(
      group: group,
      items: items,
      audit: [
        for (final entry in _audit)
          if (entry.groupId == groupId)
            AuditView(
              actorName: _display(entry.actorId, viewer),
              action: entry.action,
              at: entry.at,
            ),
      ],
    );
  }

  ReportTarget _reported(String groupId, String key) {
    final target = [..._reports, ...?_dismissed[key]]
        .where((r) => r.target.key == key && r.target.groupId == groupId)
        .firstOrNull
        ?.target;
    if (target == null) {
      throw const CircleFailure('This report has already been handled.');
    }
    return target;
  }

  @override
  Future<void> hide(String viewer, String groupId, String targetKey) async {
    _moderated(viewer, groupId);
    final target = _reported(groupId, targetKey);
    if (!target.kind.hideable) {
      throw const CircleFailure('Only posts and messages can be hidden.');
    }
    if (_hidden.containsKey(targetKey)) return;
    _hidden[targetKey] = groupId;
    _log(groupId, viewer, 'hid ${ModerationRules.article(target.kind)}');
  }

  @override
  Future<void> unhide(String viewer, String groupId, String targetKey) async {
    _moderated(viewer, groupId);
    if (_hidden[targetKey] != groupId) {
      throw const CircleFailure('This isn’t hidden any more.');
    }
    _hidden.remove(targetKey);
    final kind = ReportKind.values.byName(targetKey.split(':').first);
    _log(groupId, viewer, 'unhid ${ModerationRules.article(kind)}');
  }

  @override
  Future<void> dismiss(String viewer, String groupId, String targetKey) async {
    _moderated(viewer, groupId);
    final target = _reported(groupId, targetKey);
    final closing = [
      for (final report in _reports)
        if (report.target.key == targetKey && report.target.groupId == groupId)
          report,
    ];
    if (closing.isEmpty) {
      throw const CircleFailure('This report has already been handled.');
    }
    _reports = [
      for (final report in _reports)
        if (!closing.contains(report)) report,
    ];
    _dismissed[targetKey] = [...?_dismissed[targetKey], ...closing];
    _log(
      groupId,
      viewer,
      'dismissed a report about ${ModerationRules.article(target.kind)}',
    );
  }

  @override
  Future<void> restoreReports(
    String viewer,
    String groupId,
    String targetKey,
  ) async {
    _moderated(viewer, groupId);
    final restored = _dismissed.remove(targetKey);
    if (restored == null) return;
    _reports = [..._reports, ...restored];
    _audit = [
      for (final (index, entry) in _audit.indexed)
        // Undo takes back the matching "dismissed" line.
        if (!(index == 0 &&
            entry.groupId == groupId &&
            entry.actorId == viewer &&
            entry.action.startsWith('dismissed')))
          entry,
    ];
  }

  @override
  Future<void> removeSubgroup(
    String viewer,
    String parentId,
    String subgroupId,
  ) async {
    final parent = _member(viewer, parentId);
    final subgroup = _groups[subgroupId];
    _check(
      ModerationRules.canRemoveSubgroup(
        parent: parent,
        subgroup: subgroup,
        actor: viewer,
      ),
    );
    final removed = {
      subgroupId,
      for (final child in MembershipRules.descendants(_groups, subgroupId))
        child.id,
    };
    for (final id in removed) {
      _groups.remove(id);
    }
    _requests.removeWhere((request) => removed.contains(request.groupId));
    _invitations.removeWhere(
      (invitation) => removed.contains(invitation.groupId),
    );
    _reports = [
      for (final report in _reports)
        if (!removed.contains(report.target.groupId) &&
            !(report.target.kind == ReportKind.subgroup &&
                removed.contains(report.target.id)))
          report,
    ];
    _hidden.removeWhere((_, groupId) => removed.contains(groupId));
    _log(parentId, viewer, 'removed the subgroup ${subgroup!.name}');
  }
}

/// The repository's own record of a Memory, including every person's
/// reactions, saves and votes. Only [CircleMemory] views leave the mock.
class _StoredMemory {
  _StoredMemory({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.photos = const [],
    this.poll,
    this.takenYear,
    this.place,
    this.comments = const [],
    Map<String, String> reactions = const {},
  }) : reactions = Map.of(reactions);
  final String id, groupId, authorId;
  final DateTime createdAt;
  final List<MemoryPhoto> photos;
  final int? takenYear;
  final String? place;
  String text;
  DateTime? editedAt;
  Poll? poll;
  List<MemoryComment> comments;

  /// Person → emoji; at most one reaction per person.
  Map<String, String> reactions;
  final Set<String> savedBy = {};

  /// Soft deletes, so Undo can bring things back.
  bool deleted = false;
  final Set<String> deletedComments = {};
}
