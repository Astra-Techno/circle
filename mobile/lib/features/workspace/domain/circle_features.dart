import '../../../core/circle_failure.dart';

/// Feature families of CIRCLE. The connected server offers a subset;
/// anything it doesn't offer yet is hidden from the app.
enum CircleFeature {
  events('Events', plural: true),
  polls('Polls', plural: true),
  chat('Chat'),
  liveChat('Chats', plural: true),
  liveEvents('Events', plural: true),
  livePolls('Polls', plural: true),
  albums('Albums', plural: true),
  activity('Activity'),
  notificationSettings('Notification settings', plural: true),
  blocking('Blocking'),
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

/// What the connected server offers.
class CircleFeatures {
  /// Enable each family only after its real server implementation is
  /// verified.
  const CircleFeatures.server(this.host, {bool notifications = false})
    : available = notifications
          ? const {
              CircleFeature.liveChat,
              CircleFeature.liveEvents,
              CircleFeature.livePolls,
              CircleFeature.blocking,
              CircleFeature.moderation,
              CircleFeature.notificationSettings,
              CircleFeature.contactInvitations,
            }
          : const {
              CircleFeature.contactInvitations,
              CircleFeature.moderation,
              CircleFeature.liveChat,
              CircleFeature.liveEvents,
              CircleFeature.livePolls,
              CircleFeature.blocking,
            };

  /// The connected server's host, e.g. "circle.cloudkart24.com".
  final String host;

  /// Features that work in this session.
  final Set<CircleFeature> available;

  bool has(CircleFeature feature) => available.contains(feature);
}

/// The calm failure for an action the server doesn't offer yet.
CircleFailure notOnServerYet(CircleFeature feature) =>
    CircleFailure('${feature.notOnServer} It’s coming in a later milestone.');
