import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/membership_rules.dart';
import '../data/invite_share_bridge.dart';
export '../data/invite_share_bridge.dart' show InviteShareTarget;

class InviteShareSnapshot {
  const InviteShareSnapshot({
    required this.session,
    required this.origin,
    required this.link,
    this.owner,
  });
  final String session;
  final Object? owner;
  final Uri origin;
  final InviteLink link;
  Uri get url =>
      origin.replace(path: '/invite.html', query: null, fragment: link.token);
}

final inviteShareBridgeProvider = Provider<InviteShareBridge>(
  (ref) => const InviteShareBridge(),
);
final inviteSharingProvider = Provider<InviteSharing>(
  (ref) => InviteSharing(
    bridge: ref.watch(inviteShareBridgeProvider),
    clock: ref.watch(circleClockProvider),
    current: (groupId) {
      if (!ref.mounted || !ref.read(circleFeaturesProvider).server) return null;
      final workspace = ref.read(circleWorkspaceProvider).value;
      final account = ref.read(serverAccountProvider),
          api = ref.read(apiClientProvider);
      if (workspace == null ||
          account == null ||
          api == null ||
          !api.config.secure) {
        return null;
      }
      if (workspace.viewer != account.id) return null;
      final group = workspace.group(groupId);
      if (group == null ||
          group.inviteLink == null ||
          !MembershipRules.canInvite(group, workspace.viewer).allowed) {
        return null;
      }
      return InviteShareSnapshot(
        session: '${api.config.baseUrl}:${account.id}:${api.sessionRevision}',
        owner: api,
        origin: Uri.parse(api.config.baseUrl.origin),
        link: group.inviteLink!,
      );
    },
  ),
);

enum InviteShareResult { opened, cancelled }

class InviteSharing {
  InviteSharing({
    required this.bridge,
    required this.current,
    required this.clock,
  });
  final InviteShareBridge bridge;
  final InviteShareSnapshot? Function(String groupId) current;
  final DateTime Function() clock;
  bool _busy = false;
  String? linkFor(String groupId) => current(groupId)?.url.toString();
  InviteShareSnapshot _valid(String groupId) {
    final snapshot = current(groupId);
    if (snapshot == null ||
        snapshot.origin.scheme != 'https' ||
        snapshot.origin.host.isEmpty ||
        snapshot.origin.userInfo.isNotEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(snapshot.link.token) ||
        snapshot.link.expiredAt(clock().toUtc()) ||
        snapshot.link.exhausted) {
      throw const CircleFailure(
        'This invite is no longer available. Open the group for a current link.',
      );
    }
    return snapshot;
  }

  Future<InviteShareResult> share(
    String groupId,
    InviteShareTarget target,
  ) async {
    if (_busy) throw const CircleFailure('Finish choosing a recipient first.');
    _busy = true;
    try {
      final before = _valid(groupId);
      if (!bridge.supported) {
        throw const CircleFailure(
          'Copy the invite link and share it from your messaging app.',
        );
      }
      String? phone;
      if (target == InviteShareTarget.smsContact) {
        phone = await bridge.pickPhone();
        if (phone == null) return InviteShareResult.cancelled;
        phone = phone.replaceAll(RegExp(r'[\s()-]'), '');
        if (!RegExp(r'^\+?[0-9]{2,20}$').hasMatch(phone)) {
          throw const CircleFailure(
            'Choose a regular phone number, or enter it in your SMS app.',
          );
        }
      }
      final after = _valid(groupId);
      if (!identical(after.owner, before.owner) ||
          after.session != before.session ||
          after.link.token != before.link.token ||
          after.origin != before.origin) {
        throw const CircleFailure(
          'Your session or invite changed. Open the invite again.',
        );
      }
      final opened = await bridge.compose(
        target,
        'Join my circle on CIRCLE:\n${after.url}',
        phone: phone,
      );
      if (!opened) {
        throw CircleFailure(
          target == InviteShareTarget.whatsapp
              ? 'WhatsApp isn’t available. Try SMS or More apps.'
              : 'Your messaging app couldn’t open. Copy the invite link instead.',
        );
      }
      return InviteShareResult.opened;
    } finally {
      _busy = false;
    }
  }
}
