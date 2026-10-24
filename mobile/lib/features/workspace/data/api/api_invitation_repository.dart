part of 'api_circle_repository.dart';

/// Invite links (create, revoke, reset, preview, join). Direct invitations
/// with consent aren't on the server yet.
mixin ApiInvitationRepository on ApiRepositoryBase
    implements InvitationRepository {
  static const _maxHours = 720;

  int _hours(Duration expiry) => expiry.inHours.clamp(1, _maxHours);

  void _checkInvite(String groupId) {
    final group = _requireGroup(groupId);
    final rule = MembershipRules.canInvite(group, viewer);
    if (!rule.allowed) throw CircleFailure(rule.reason!);
  }

  InviteLink _remember(String groupId, Object? data) {
    final created = ApiMappers.newInviteLink(
      data,
      createdBy: viewer,
      now: now(),
    );
    _links[groupId] = _LinkEntry(created.id, created.link);
    return created.link;
  }

  @override
  Future<InviteLink> createInviteLink(
    String viewer,
    String groupId, {
    Duration expiry = defaultInviteExpiry,
    int? maxUses,
  }) async {
    _checkViewer(viewer);
    _checkInvite(groupId);
    final data = await api.post(
      '/groups/$groupId/invite-links',
      body: {'expires_in_hours': _hours(expiry), 'max_uses': ?maxUses},
    );
    return _remember(groupId, data);
  }

  /// Links can't be edited on the server, so a new link with the new
  /// settings replaces the old one (which stops working).
  @override
  Future<void> configureInviteLink(
    String viewer,
    String groupId, {
    required Duration expiry,
    int? maxUses,
  }) async {
    final old = _links[groupId];
    await createInviteLink(viewer, groupId, expiry: expiry, maxUses: maxUses);
    if (old != null) {
      try {
        await api.delete('/groups/$groupId/invite-links/${old.id}');
      } on ApiError {
        // The old link still expires on its own.
      }
    }
  }

  @override
  Future<InviteLink> resetInviteLink(String viewer, String groupId) async {
    _checkViewer(viewer);
    final group = _requireGroup(groupId);
    final rule = MembershipRules.canManageLink(group, viewer);
    if (!rule.allowed) throw CircleFailure(rule.reason!);
    return _remember(
      groupId,
      await api.post('/groups/$groupId/invite-links/reset'),
    );
  }

  @override
  Future<void> revokeInviteLink(String viewer, String groupId) async {
    _checkViewer(viewer);
    final link = _links[groupId];
    if (link == null) return;
    await api.delete('/groups/$groupId/invite-links/${link.id}');
    _links.remove(groupId);
  }

  @override
  Future<InvitePreview> previewInvite(String viewer, String input) async {
    final token = serverInviteToken(input);
    if (token == null) {
      return const InvitePreview(status: InviteLinkStatus.unknown);
    }
    try {
      return ApiMappers.invitePreview(
        await api.get('/invites/$token', auth: false),
        token,
      );
    } on ApiError catch (error) {
      final status = switch (error.code) {
        'link_expired' => InviteLinkStatus.expired,
        'link_revoked' => InviteLinkStatus.reset,
        'link_exhausted' => InviteLinkStatus.exhausted,
        'not_found' => InviteLinkStatus.unknown,
        _ => null,
      };
      if (status == null) rethrow;
      return InvitePreview(status: status, token: token);
    }
  }

  @override
  Future<JoinOutcome> joinWithLink(String viewer, String input) async {
    _checkViewer(viewer);
    final token = serverInviteToken(input);
    if (token == null) {
      throw const CircleFailure('Check the link or code and try again.');
    }
    final data = ApiJson.map(await api.post('/invites/$token/join'));
    if (data['status'] == 'joined') {
      await _syncGroups();
      await _syncMemories();
      return JoinOutcome.joined;
    }
    return JoinOutcome.requested;
  }

  @override
  Future<void> inviteMember(String viewer, String groupId, String person) =>
      Future.error(notOnServerYet(CircleFeature.directInvitations));

  @override
  Future<void> cancelInvitation(String viewer, String invitationId) =>
      Future.error(notOnServerYet(CircleFeature.directInvitations));

  @override
  Future<JoinOutcome?> respondToInvitation(
    String viewer,
    String invitationId, {
    required bool accept,
  }) => Future.error(notOnServerYet(CircleFeature.directInvitations));
}
