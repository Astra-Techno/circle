import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/contact_invitation_client.dart';
import '../domain/membership_rules.dart';
import '../domain/contact_invitation.dart';
import 'invite_sharing.dart';
export '../domain/contact_invitation.dart';

final contactInvitationClientProvider = Provider<ContactInvitationClient?>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  final account = ref.watch(serverAccountProvider);
  return api == null || account == null
      ? null
      : ContactInvitationClient(api, account.id, api.sessionRevision);
});
final contactInvitationsProvider = Provider<ContactInvitations>(
  (ref) => ContactInvitations(ref),
);

/// Captures account, API and session before any external picker or dialog.
class ContactInviteScope {
  const ContactInviteScope(this.client, this.group);
  final ContactInvitationClient client;
  final String group;
}

class ContactInvitations {
  ContactInvitations(this.ref);
  final Ref ref;
  ContactInviteScope capture(String group) {
    final client = ref.read(contactInvitationClientProvider);
    final workspace = ref.read(circleWorkspaceProvider).value;
    final g = workspace?.group(group);
    if (client == null ||
        workspace == null ||
        workspace.viewer != client.account ||
        g == null ||
        !MembershipRules.canInvite(g, workspace.viewer).allowed) {
      throw const CircleFailure(
        'Inviting is no longer available. Open the group again.',
      );
    }
    return ContactInviteScope(client, group);
  }

  void validate(ContactInviteScope scope) {
    final now = capture(scope.group);
    if (!identical(now.client.api, scope.client.api) ||
        now.client.account != scope.client.account ||
        now.client.session != scope.client.session ||
        scope.client.api.sessionRevision != scope.client.session) {
      throw const CircleFailure('Your account changed. Open the invite again.');
    }
  }

  Future<String?> pick(ContactInviteScope scope) async {
    validate(scope);
    final number = await ref.read(inviteShareBridgeProvider).pickPhone();
    validate(scope);
    return number;
  }

  Future<ContactInviteOutcome> send(
    ContactInviteScope scope,
    String mobile,
  ) async {
    validate(scope);
    final result = await scope.client.invite(scope.group, mobile);
    validate(scope);
    return result;
  }

  Future<String> link(ContactInviteScope scope) async {
    validate(scope);
    var link = ref.read(inviteSharingProvider).linkFor(scope.group);
    final group = ref.read(circleWorkspaceProvider).value!.group(scope.group)!;
    if (group.inviteLink == null ||
        group.inviteLink!.expiredAt(DateTime.now().toUtc()) ||
        group.inviteLink!.exhausted) {
      await ref
          .read(circleWorkspaceProvider.notifier)
          .createInviteLink(scope.group);
      validate(scope);
      link = ref.read(inviteSharingProvider).linkFor(scope.group);
    }
    if (link == null) {
      throw const CircleFailure('The invite link is unavailable. Try again.');
    }
    return link;
  }

  Future<bool> share(
    ContactInviteScope scope,
    InviteShareTarget target,
    String phone,
  ) async {
    final url = await link(scope);
    validate(scope);
    return ref
        .read(inviteShareBridgeProvider)
        .compose(
          target,
          'Join my circle on CIRCLE:\n$url',
          phone: target == InviteShareTarget.smsManual ? phone : null,
        );
  }
}
