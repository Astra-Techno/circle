import '../../moderation/domain/moderation_repository.dart';
import 'circle_workspace.dart';

export '../../moderation/domain/moderation_repository.dart';
export 'circle_workspace.dart';

/// Every method is asynchronous so an HTTP implementation can replace the
/// local mock. Failures are reported as [CircleFailure] with calm copy.

abstract interface class WorkspaceReader {
  Future<CircleWorkspace> load(String viewer);

  /// Fetches the latest from the source of truth. Returns whether anything
  /// may have changed (the local preview has nothing to fetch).
  Future<bool> refresh(String viewer);

  /// Loads the next page of older Memories, if there is one. Returns
  /// whether the workspace changed.
  Future<bool> loadMoreMemories(String viewer);
}

abstract interface class GroupRepository {
  Future<CircleGroup> readGroup(String viewer, String groupId);
  Future<CircleGroup> createGroup(
    String viewer,
    String name,
    CircleType type, {
    String? parentId,
    bool hidden = false,
  });
  Future<void> updateSettings(
    String viewer,
    String groupId, {
    String? name,
    bool? approvalRequired,
    InvitePolicy? invitePolicy,
    bool? hidden,
    EventCreationPolicy? eventCreation,
  });
}

abstract interface class MembershipRepository {
  Future<void> setRole(
    String viewer,
    String groupId,
    String person,
    CircleRole role,
  );

  /// Names of subgroups the viewer can see that [person] would also leave.
  Future<List<String>> removalImpact(
    String viewer,
    String groupId,
    String person,
  );
  Future<void> removeMember(String viewer, String groupId, String person);
  Future<void> transferOwnership(String viewer, String groupId, String person);
  Future<void> leaveGroup(String viewer, String groupId);
  Future<JoinOutcome> requestToJoin(String viewer, String groupId);
  Future<void> cancelRequest(String viewer, String requestId);
  Future<void> approveRequest(String viewer, String requestId);
  Future<void> declineRequest(String viewer, String requestId);
}

abstract interface class InvitationRepository {
  Future<InviteLink> createInviteLink(
    String viewer,
    String groupId, {
    Duration expiry = defaultInviteExpiry,
    int? maxUses,
  });
  Future<void> configureInviteLink(
    String viewer,
    String groupId, {
    required Duration expiry,
    int? maxUses,
  });

  /// Replaces the token; the old link stops working for everyone.
  Future<InviteLink> resetInviteLink(String viewer, String groupId);
  Future<void> revokeInviteLink(String viewer, String groupId);
  Future<InvitePreview> previewInvite(String viewer, String token);
  Future<JoinOutcome> joinWithLink(String viewer, String token);

  /// Direct addition; the invitee must accept before joining.
  Future<void> inviteMember(String viewer, String groupId, String person);
  Future<void> cancelInvitation(String viewer, String invitationId);
  Future<JoinOutcome?> respondToInvitation(
    String viewer,
    String invitationId, {
    required bool accept,
  });
}

/// Every mutation re-checks that [viewer] is a member of the Memory's exact
/// group; nothing is inherited from parent groups.
abstract interface class MemoryRepository {
  /// Shares a Memory with text, photos, a poll, or any mix of them.
  /// Photos are fictional [photos] in the preview, or uploaded [mediaIds]
  /// (ready, uploaded by the viewer to this exact group) on a server.
  /// [captions] line up with [photos] (preview only: the API has no
  /// caption field yet). Returns the new Memory's id.
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
  });

  /// Fetches one Memory's comments and reactions (opening it). Returns
  /// whether the workspace changed; the local preview is always complete.
  Future<bool> refreshMemory(String viewer, String memoryId);

  /// Author only. Marks the Memory as edited.
  Future<void> editMemory(String viewer, String memoryId, String text);

  /// Author only. Reversible with [restoreMemory] (Undo).
  Future<void> deleteMemory(String viewer, String memoryId);
  Future<void> restoreMemory(String viewer, String memoryId);

  /// Toggles the viewer's ❤️ (same as [react] with ❤️).
  Future<void> loveMemory(String viewer, String memoryId);

  /// Sets the viewer's single reaction; the same emoji again removes it.
  Future<void> react(String viewer, String memoryId, String emoji);
  Future<void> saveMemory(String viewer, String memoryId);

  /// Adds a comment, or a reply when [replyTo] is a top-level comment of
  /// the same Memory. [mentions] (person id → name as written) keeps only
  /// members of the Memory's exact group; a server stores plain text for
  /// now. Returns the new comment's id.
  Future<String> comment(
    String viewer,
    String memoryId,
    String text, {
    String? replyTo,
    Map<String, String> mentions = const {},
  });

  /// Author only. Replies under a deleted comment are hidden with it.
  /// Reversible with [restoreComment] (Undo).
  Future<void> deleteComment(String viewer, String memoryId, String commentId);
  Future<void> restoreComment(String viewer, String memoryId, String commentId);

  /// Replaces the viewer's vote with [optionIds].
  Future<void> vote(String viewer, String memoryId, Set<String> optionIds);
  Future<void> retractVote(String viewer, String memoryId);

  /// The poll's creator or a group owner/admin.
  Future<void> closePoll(String viewer, String memoryId);
}

/// Every mutation re-checks that [viewer] is a member of the event's exact
/// group; nothing is inherited from parent groups.
abstract interface class EventRepository {
  /// Creates an event (and its date poll, if any). Returns the new id.
  Future<String> createEvent(String viewer, EventDraft draft);

  /// Hosts and group admins only. Replaces the details (not the group or
  /// the date poll) and marks the event as edited.
  Future<void> editEvent(String viewer, String eventId, EventDraft draft);

  /// Hosts and group admins only. Closes RSVPs; can't be undone.
  Future<void> cancelEvent(String viewer, String eventId);

  /// Sets the viewer's answer; a null [response] clears it.
  Future<void> rsvp(String viewer, String eventId, Rsvp? response);

  /// Votes on the event's date poll (same rules as Memory polls).
  Future<void> voteEventPoll(
    String viewer,
    String eventId,
    Set<String> optionIds,
  );
  Future<void> retractEventPollVote(String viewer, String eventId);
  Future<void> closeEventPoll(String viewer, String eventId);
}

/// One local implementation serves every interface for now.
abstract interface class CircleRepository
    implements
        WorkspaceReader,
        GroupRepository,
        MembershipRepository,
        InvitationRepository,
        MemoryRepository,
        EventRepository,
        ModerationRepository {
  /// Local preview only: discards every change.
  Future<void> reset({required bool showcase});
}
