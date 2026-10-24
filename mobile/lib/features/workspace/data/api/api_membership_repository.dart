part of 'api_circle_repository.dart';

/// Roles, removal (with bans), ownership, leaving and join requests.
mixin ApiMembershipRepository on ApiRepositoryBase
    implements MembershipRepository {
  Object _userId(String person) => int.tryParse(person) ?? person;

  @override
  Future<void> setRole(
    String viewer,
    String groupId,
    String person,
    CircleRole role,
  ) async {
    _checkViewer(viewer);
    if (role == CircleRole.owner) {
      return transferOwnership(viewer, groupId, person);
    }
    final group = _requireGroup(groupId);
    _check(MembershipRules.canChangeRole(group, viewer, person, role));
    await api.patch(
      '/groups/$groupId/members/$person',
      body: {'role': ApiMappers.roleName(role)},
    );
    final roles = _groups[groupId]!.roles;
    if (roles != null && roles.containsKey(person)) roles[person] = role;
  }

  @override
  Future<List<String>> removalImpact(
    String viewer,
    String groupId,
    String person,
  ) async {
    _checkViewer(viewer);
    final groups = _domainGroups();
    return [
      for (final group in MembershipRules.descendants(groups, groupId))
        if (group.isMember(person)) group.name,
    ];
  }

  @override
  Future<void> removeMember(String viewer, String groupId, String person) =>
      _remove(viewer, groupId, person, ban: false);

  /// Removes [person] and bans them from rejoining [groupId] until
  /// [unbanMember]. (The app's screens don't offer bans yet.)
  Future<void> banMember(String viewer, String groupId, String person) =>
      _remove(viewer, groupId, person, ban: true);

  Future<void> unbanMember(String viewer, String groupId, String person) async {
    _checkViewer(viewer);
    await api.post('/groups/$groupId/members/$person/unban');
  }

  Future<void> _remove(
    String viewer,
    String groupId,
    String person, {
    required bool ban,
  }) async {
    _checkViewer(viewer);
    final groups = _domainGroups();
    final group = _requireGroup(groupId);
    _check(
      MembershipRules.canRemove(
        group,
        viewer,
        person,
        ownedDescendants: MembershipRules.ownedDescendants(
          groups,
          groupId,
          person,
        ),
      ),
    );
    await api.delete(
      '/groups/$groupId/members/$person',
      query: ban ? {'ban': 'true'} : null,
    );
    // The server removed them from this group and every descendant.
    final affected = [
      groupId,
      for (final sub in MembershipRules.descendants(_domainGroups(), groupId))
        sub.id,
    ];
    for (final id in affected) {
      _groups[id]?.roles?.remove(person);
    }
    _requests.removeWhere(
      (_, request) =>
          request.person == person && affected.contains(request.groupId),
    );
  }

  @override
  Future<void> transferOwnership(
    String viewer,
    String groupId,
    String person,
  ) async {
    _checkViewer(viewer);
    final group = _requireGroup(groupId);
    _check(MembershipRules.canTransferOwnership(group, viewer, person));
    await api.post(
      '/groups/$groupId/transfer-ownership',
      body: {'new_owner_id': _userId(person)},
    );
    final entry = _groups[groupId]!;
    entry.json = {...entry.json, 'owner_user_id': _userId(person)};
    final roles = entry.roles;
    if (roles != null) {
      roles[viewer] = CircleRole.admin;
      roles[person] = CircleRole.owner;
    }
  }

  @override
  Future<void> leaveGroup(String viewer, String groupId) async {
    _checkViewer(viewer);
    final groups = _domainGroups();
    final group = _requireGroup(groupId);
    _check(
      MembershipRules.canLeave(
        group,
        viewer,
        MembershipRules.cascade(groups, groupId, viewer),
      ),
    );
    final data = ApiJson.map(await api.post('/groups/$groupId/leave'));
    final left = {
      groupId,
      for (final item in ApiJson.list(data['left_groups']))
        if (item is Map) ?ApiJson.optionalId(item['group_id']),
    };
    _groups.removeWhere((id, _) => left.contains(id));
    _links.removeWhere((id, _) => left.contains(id));
    _requests.removeWhere((_, request) => left.contains(request.groupId));
    _memoryOrder.removeWhere((id) => left.contains(_memories[id]?.groupId));
  }

  @override
  Future<JoinOutcome> requestToJoin(String viewer, String groupId) =>
      Future.error(notOnServerYet(CircleFeature.joinListedSubgroups));

  @override
  Future<void> cancelRequest(String viewer, String requestId) =>
      Future.error(notOnServerYet(CircleFeature.joinListedSubgroups));

  JoinRequest _request(String requestId) {
    final request = _requests[requestId];
    if (request == null) {
      throw const CircleFailure('That request is no longer waiting.');
    }
    return request;
  }

  @override
  Future<void> approveRequest(String viewer, String requestId) async {
    _checkViewer(viewer);
    final request = _request(requestId);
    try {
      await api.post(
        '/groups/${request.groupId}/join-requests/$requestId/approve',
      );
    } on ApiError catch (error) {
      // The server cancelled the request (not in the parent any more,
      // banned) or it was handled elsewhere.
      if (error.status == 409 || error.status == 404) {
        _requests.remove(requestId);
      }
      rethrow;
    }
    _requests.remove(requestId);
    final roles = _groups[request.groupId]?.roles;
    if (roles != null) roles[request.person] = CircleRole.member;
  }

  @override
  Future<void> declineRequest(String viewer, String requestId) async {
    _checkViewer(viewer);
    final request = _request(requestId);
    try {
      await api.post(
        '/groups/${request.groupId}/join-requests/$requestId/decline',
      );
    } on ApiError catch (error) {
      if (error.status == 404) _requests.remove(requestId);
      rethrow;
    }
    _requests.remove(requestId);
  }
}
