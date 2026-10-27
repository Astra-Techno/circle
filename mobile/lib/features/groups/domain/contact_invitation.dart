import '../../../core/api/api_json.dart';

class ContactInvitation {
  const ContactInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterName,
    required this.status,
    required this.approvalRequired,
    this.expiresAt,
  });
  final String id, groupId, groupName, inviterName, status;
  final bool approvalRequired;
  final DateTime? expiresAt;
  factory ContactInvitation.fromJson(Object? value) {
    final map = ApiJson.map(value);
    if (!const {
          'pending',
          'accepted',
          'declined',
          'expired',
        }.contains(map['status']) ||
        ApiJson.time(map['expires_at']) == null ||
        map['approval_required'] is! bool) {
      ApiJson.unexpected();
    }
    return ContactInvitation(
      id: ApiJson.id(map['id']),
      groupId: ApiJson.id(map['group_id']),
      groupName: map['group_name'] as String? ?? 'Private circle',
      inviterName: map['inviter_name'] as String? ?? 'A circle member',
      status: map['status'] as String? ?? 'pending',
      approvalRequired: map['approval_required'] == true,
      expiresAt: ApiJson.time(map['expires_at']),
    );
  }
}

class ContactInviteOutcome {
  const ContactInviteOutcome(this.outcome, this.invitationId);
  final String outcome;
  final String? invitationId;
}
