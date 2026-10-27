import '../../../core/circle_failure.dart';

/// Parts of CIRCLE that the API contract (0.3.1) doesn't cover yet. The
/// local preview has all of them (fictional and session-local); a real
/// server session shows an honest "not on the server yet" state instead of
/// mixing mock data into real groups.
enum CircleFeature {
  events('Events', plural: true),
  polls('Polls', plural: true),
  chat('Chat'),
  albums('Albums', plural: true),
  activity('Activity'),
  notificationSettings('Notification settings', plural: true),
  privacy('Privacy settings', plural: true),
  moderation('Reports', plural: true),
  contactInvitations('Contact invitations', plural: true),
  directInvitations('Direct invitations', plural: true),
  joinListedSubgroups('Asking to join from the subgroup list'),
  commentDeletion('Deleting comments');

  const CircleFeature(this.label, {this.plural = false});

  /// What people call it, e.g. "Events".
  final String label;
  final bool plural;

  /// "Events aren’t on the server yet." / "Chat isn’t on the server yet."
  String get notOnServer =>
      '$label ${plural ? 'aren’t' : 'isn’t'} on the server yet.';
}

/// What the current session can do, and how it is labelled.
class CircleFeatures {
  const CircleFeatures._({required this.host, required this.available});

  /// The fictional, session-local preview: everything works locally.
  static const preview = CircleFeatures._(
    host: null,
    available: {...CircleFeature.values},
  );

  /// Enable each family only after its real server implementation is verified.
  /// Chats and Events remain required work in docs/pending-work.md.
  const CircleFeatures.server(String this.host, {bool notifications = false})
    : available = notifications
          ? const {
              CircleFeature.moderation,
              CircleFeature.notificationSettings,
              CircleFeature.contactInvitations,
            }
          : const {CircleFeature.contactInvitations, CircleFeature.moderation};

  /// Null in the preview; the server's host in server mode.
  final String? host;

  /// Features that work in this session.
  final Set<CircleFeature> available;

  bool get server => host != null;

  bool has(CircleFeature feature) => available.contains(feature);

  /// The header's one mode label: "PREVIEW" or the server's host.
  String get label => host ?? 'PREVIEW';
}

/// The calm failure for an action the server doesn't offer yet.
CircleFailure notOnServerYet(CircleFeature feature) =>
    CircleFailure('${feature.notOnServer} It’s coming in a later milestone.');
