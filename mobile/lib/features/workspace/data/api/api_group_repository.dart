part of 'api_circle_repository.dart';

/// Groups and subgroups: `/groups`, `/groups/{id}`, members lists.
mixin ApiGroupRepository on ApiRepositoryBase implements GroupRepository {
  static const _maxName = 60;

  @override
  Future<void> _syncGroups() async {
    final list = ApiJson.list(await api.get('/groups'));
    final fresh = <String, _GroupEntry>{};
    for (final item in list) {
      final json = ApiJson.map(item);
      final id = ApiJson.id(json['id']);
      final entry = _groups[id] ?? _GroupEntry(json);
      entry.json = {...?_groups[id]?.json, ...json};
      fresh[id] = entry;
    }
    _groups
      ..clear()
      ..addAll(fresh);
    _requests.removeWhere((_, request) => !fresh.containsKey(request.groupId));
    _links.removeWhere((groupId, _) => !fresh.containsKey(groupId));
    await ApiRepositoryBase.pool(fresh.keys, _syncGroupDetails);
  }

  /// Members (for roles and names), settings once per session, and for
  /// admins the join requests and the status of a link made here.
  Future<void> _syncGroupDetails(String groupId) async {
    final entry = _groups[groupId];
    if (entry == null) return;
    await _syncMembers(groupId);
    if (entry.linkSharing == null) await _syncSettings(groupId);
    if (!_isAdmin(groupId)) return;
    final requests = ApiJson.list(
      await api.get('/groups/$groupId/join-requests'),
    );
    _requests.removeWhere((_, request) => request.groupId == groupId);
    for (final item in requests) {
      final request = ApiMappers.joinRequest(item, groupId: groupId);
      final json = ApiJson.map(item);
      _people[request.person] = ApiJson.string(json['display_name'], 'Someone');
      _requests[request.id] = request;
    }
    final link = _links[groupId];
    if (link != null) {
      final links = ApiJson.list(
        await api.get('/groups/$groupId/invite-links'),
      );
      final info = links
          .whereType<Map>()
          .where((item) => ApiJson.optionalId(item['id']) == link.id)
          .firstOrNull;
      final updated = info == null
          ? null
          : ApiMappers.linkStatus(link.link, info);
      if (updated == null) {
        _links.remove(groupId);
      } else {
        link.link = updated;
      }
    }
  }

  Future<void> _syncMembers(String groupId) async {
    final roles = <String, CircleRole>{};
    var offset = 0;
    while (true) {
      final page = await api.getPage(
        '/groups/$groupId/members',
        query: {'limit': 100, 'offset': offset},
      );
      for (final item in page.items) {
        final member = ApiMappers.member(item);
        roles[member.id] = member.role;
        _people[member.id] = member.name;
      }
      offset += page.items.length;
      final total = ApiJson.integer(page.pagination['total']) ?? offset;
      if (page.items.isEmpty || offset >= total || offset >= 2000) break;
    }
    _groups[groupId]?.roles = roles;
  }

  Future<void> _syncSettings(String groupId) async {
    final json = ApiJson.map(await api.get('/groups/$groupId'));
    _applyGroup(json);
  }

  void _applyGroup(Map<String, Object?> json) {
    final id = ApiJson.id(json['id']);
    final entry = _groups[id];
    if (entry == null) return;
    entry.json = {...entry.json, ...json};
    entry.linkSharing = ApiJson.optionalString(json['link_sharing']);
    entry.eventCreation = ApiJson.optionalString(json['event_creation']);
  }

  @override
  Future<CircleGroup> readGroup(String viewer, String groupId) async {
    _checkViewer(viewer);
    if (!_loaded) await _syncAll();
    if (!_groups.containsKey(groupId)) {
      throw const CircleFailure('This group is not shared with you.');
    }
    await _syncSettings(groupId);
    await _syncMembers(groupId);
    return _requireGroup(groupId);
  }

  String _validName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed.runes.length > _maxName) {
      throw const CircleFailure('Use a group name with 1–60 characters.');
    }
    return trimmed;
  }

  @override
  Future<CircleGroup> createGroup(
    String viewer,
    String name,
    CircleType type, {
    String? parentId,
    bool hidden = false,
  }) async {
    _checkViewer(viewer);
    final parent = parentId == null ? null : _requireGroup(parentId);
    final rule = MembershipRules.canCreateGroup(person: viewer, parent: parent);
    if (!rule.allowed) throw CircleFailure(rule.reason!);
    final created = ApiJson.map(
      await api.post(
        '/groups',
        body: {
          'name': _validName(name),
          'type': type.name,
          if (parentId != null) 'parent_id': int.tryParse(parentId) ?? parentId,
          'visibility': parentId != null && hidden ? 'hidden' : 'listed',
          // The app's default: people who use a link wait for approval.
          'approval_mode': 'manual',
        },
      ),
    );
    final entry = _GroupEntry({...created, 'role': 'admin'})
      ..roles = {viewer: CircleRole.owner}
      ..linkSharing = ApiJson.optionalString(created['link_sharing'])
      ..eventCreation = ApiJson.optionalString(created['event_creation']);
    _groups[entry.id] = entry;
    return _requireGroup(entry.id);
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
    _checkViewer(viewer);
    final group = _requireGroup(groupId);
    final rule = MembershipRules.canEditSettings(group, viewer);
    if (!rule.allowed) throw CircleFailure(rule.reason!);
    if (eventCreation != null) throw notOnServerYet(CircleFeature.events);
    if (hidden != null && !group.isSubgroup) {
      throw const CircleFailure('Only subgroups can be listed or hidden.');
    }
    final body = {
      if (name != null) 'name': _validName(name),
      if (approvalRequired != null)
        'approval_mode': approvalRequired ? 'manual' : 'auto',
      if (invitePolicy != null)
        'link_sharing': invitePolicy == InvitePolicy.allMembers
            ? 'members'
            : 'admins',
      if (hidden != null) 'visibility': hidden ? 'hidden' : 'listed',
    };
    if (body.isEmpty) return;
    _applyGroup(ApiJson.map(await api.patch('/groups/$groupId', body: body)));
  }
}
