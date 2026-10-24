import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../data/api/api_circle_repository.dart';
import '../data/mock_circle_repository.dart';
import '../domain/circle_features.dart';
import '../domain/circle_repository.dart';
import 'server_session.dart';

export '../domain/circle_features.dart';
export '../domain/circle_repository.dart';
export 'server_session.dart';

/// The person using the app: the signed-in server account's id, or the
/// fictional "you" of the local preview.
final circleViewerProvider = Provider<String>(
  (ref) => ref.watch(serverAccountProvider.select((a) => a?.id)) ?? 'you',
);

/// The app's clock. Tests replace it to make dates predictable.
final circleClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The CIRCLE API while signed in to a server; otherwise the fictional,
/// session-local mock (the preview and the "Explore fictional circles"
/// tour). A new account gets a new repository, so nothing carries over.
final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  final accountId = ref.watch(serverAccountProvider.select((a) => a?.id));
  final api = ref.watch(apiClientProvider);
  if (accountId != null && api != null) {
    final repository = ApiCircleRepository(
      api: api,
      viewer: accountId,
      viewerName: ref.read(serverAccountProvider)?.displayName ?? 'You',
      now: ref.watch(circleClockProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return MockCircleRepository(now: ref.watch(circleClockProvider));
});

/// What this session can do and its one mode label (README §4.0).
final circleFeaturesProvider = Provider<CircleFeatures>((ref) {
  final signedIn = ref.watch(serverAccountProvider) != null;
  final config = ref.watch(apiConfigProvider);
  return signedIn && config != null
      ? CircleFeatures.server(config.host)
      : CircleFeatures.preview;
});

/// The data behind preview-only features (chat, albums, activity). On a
/// server these aren't available yet, so they get an empty local mock
/// that never sees real groups instead of the API repository.
final previewOnlyRepositoryProvider = Provider<CircleRepository>((ref) {
  final repository = ref.watch(circleRepositoryProvider);
  return repository is MockCircleRepository
      ? repository
      : MockCircleRepository(now: ref.watch(circleClockProvider));
});

/// Whether someone is inside the app: a preview session or a server
/// account.
final circleSessionActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(circlePreviewSessionProvider) ||
      ref.watch(serverAccountProvider) != null,
);

final circleWorkspaceProvider =
    AsyncNotifierProvider<CircleWorkspaceController, CircleWorkspace>(
      CircleWorkspaceController.new,
    );

final circlePreviewSessionProvider =
    NotifierProvider<CirclePreviewSession, bool>(CirclePreviewSession.new);

class CirclePreviewSession extends Notifier<bool> {
  @override
  bool build() => false;

  /// Whether this session explores the fictional showcase circles.
  bool showcase = false;

  /// Starts a local session; [showcase] loads the fictional circles.
  Future<void> enter({required bool showcase}) async {
    this.showcase = showcase;
    await ref.read(circleRepositoryProvider).reset(showcase: showcase);
    ref.invalidate(circleWorkspaceProvider);
    state = true;
  }

  Future<void> leave() async {
    showcase = false;
    await ref.read(circleRepositoryProvider).reset(showcase: false);
    ref.invalidate(circleWorkspaceProvider);
    state = false;
  }
}

/// Runs repository mutations for the current viewer, then reloads the
/// workspace. Failures propagate as [CircleFailure] for calm UI messages.
class CircleWorkspaceController extends AsyncNotifier<CircleWorkspace> {
  CircleRepository get _repository => ref.read(circleRepositoryProvider);
  String get _viewer => ref.read(circleViewerProvider);

  @override
  Future<CircleWorkspace> build() =>
      ref.read(circleRepositoryProvider).load(ref.watch(circleViewerProvider));

  Future<T> _run<T>(Future<T> Function(CircleRepository, String) change) async {
    try {
      return await change(_repository, _viewer);
    } finally {
      // Reload even after a failure: another change may have landed.
      state = AsyncData(await _repository.load(_viewer));
    }
  }

  Future<CircleGroup> createGroup(
    String name,
    CircleType type, {
    String? parentId,
    bool hidden = false,
  }) => _run(
    (repo, viewer) => repo.createGroup(
      viewer,
      name,
      type,
      parentId: parentId,
      hidden: hidden,
    ),
  );

  Future<void> updateSettings(
    String groupId, {
    String? name,
    bool? approvalRequired,
    InvitePolicy? invitePolicy,
    bool? hidden,
    EventCreationPolicy? eventCreation,
  }) => _run(
    (repo, viewer) => repo.updateSettings(
      viewer,
      groupId,
      name: name,
      approvalRequired: approvalRequired,
      invitePolicy: invitePolicy,
      hidden: hidden,
      eventCreation: eventCreation,
    ),
  );

  /// Ends a server session. Deletions still waiting for their Undo
  /// window are sent first, so nothing the person removed comes back.
  Future<void> logOut() async {
    final repository = _repository;
    if (repository is ApiCircleRepository) {
      await repository.flushPendingDeletes();
    }
    await ref.read(serverSessionProvider.notifier).logOut();
  }

  /// Fetches the latest from the server (pull to refresh).
  Future<void> refresh() async {
    if (await _repository.refresh(_viewer)) {
      state = AsyncData(await _repository.load(_viewer));
    }
  }

  /// The next page of older Memories, if any.
  Future<void> loadMoreMemories() async {
    if (await _repository.loadMoreMemories(_viewer)) {
      state = AsyncData(await _repository.load(_viewer));
    }
  }

  /// Comments and every reaction of one Memory (when it is opened).
  Future<void> refreshMemory(String id) async {
    if (await _repository.refreshMemory(_viewer, id)) {
      state = AsyncData(await _repository.load(_viewer));
    }
  }

  Future<String> createMemory(
    String groupId,
    String text, {
    List<MemoryScene> photos = const [],
    List<String?> captions = const [],
    List<String> mediaIds = const [],
    PollDraft? poll,
    int? takenYear,
    String? place,
  }) => _run(
    (repo, viewer) => repo.createMemory(
      viewer,
      groupId,
      text,
      photos: photos,
      captions: captions,
      mediaIds: mediaIds,
      poll: poll,
      takenYear: takenYear,
      place: place,
    ),
  );
  Future<void> editMemory(String id, String text) =>
      _run((repo, viewer) => repo.editMemory(viewer, id, text));
  Future<void> deleteMemory(String id) =>
      _run((repo, viewer) => repo.deleteMemory(viewer, id));
  Future<void> restoreMemory(String id) =>
      _run((repo, viewer) => repo.restoreMemory(viewer, id));
  Future<void> love(String id) =>
      _run((repo, viewer) => repo.loveMemory(viewer, id));
  Future<void> react(String id, String emoji) =>
      _run((repo, viewer) => repo.react(viewer, id, emoji));
  Future<void> save(String id) =>
      _run((repo, viewer) => repo.saveMemory(viewer, id));
  Future<String> comment(
    String id,
    String text, {
    String? replyTo,
    Map<String, String> mentions = const {},
  }) => _run(
    (repo, viewer) =>
        repo.comment(viewer, id, text, replyTo: replyTo, mentions: mentions),
  );
  Future<void> deleteComment(String id, String commentId) =>
      _run((repo, viewer) => repo.deleteComment(viewer, id, commentId));
  Future<void> restoreComment(String id, String commentId) =>
      _run((repo, viewer) => repo.restoreComment(viewer, id, commentId));
  Future<void> vote(String id, Set<String> optionIds) =>
      _run((repo, viewer) => repo.vote(viewer, id, optionIds));
  Future<void> retractVote(String id) =>
      _run((repo, viewer) => repo.retractVote(viewer, id));
  Future<void> closePoll(String id) =>
      _run((repo, viewer) => repo.closePoll(viewer, id));

  Future<String> createEvent(EventDraft draft) =>
      _run((repo, viewer) => repo.createEvent(viewer, draft));
  Future<void> editEvent(String id, EventDraft draft) =>
      _run((repo, viewer) => repo.editEvent(viewer, id, draft));
  Future<void> cancelEvent(String id) =>
      _run((repo, viewer) => repo.cancelEvent(viewer, id));
  Future<void> rsvp(String id, Rsvp? response) =>
      _run((repo, viewer) => repo.rsvp(viewer, id, response));
  Future<void> voteEventPoll(String id, Set<String> optionIds) =>
      _run((repo, viewer) => repo.voteEventPoll(viewer, id, optionIds));
  Future<void> retractEventPollVote(String id) =>
      _run((repo, viewer) => repo.retractEventPollVote(viewer, id));
  Future<void> closeEventPoll(String id) =>
      _run((repo, viewer) => repo.closeEventPoll(viewer, id));

  Future<void> report(ReportDraft draft) =>
      _run((repo, viewer) => repo.report(viewer, draft));
  Future<ModerationQueue> queue(String groupId) =>
      _repository.queue(_viewer, groupId);
  Future<void> hide(String groupId, String key) =>
      _run((repo, viewer) => repo.hide(viewer, groupId, key));
  Future<void> unhide(String groupId, String key) =>
      _run((repo, viewer) => repo.unhide(viewer, groupId, key));
  Future<void> dismissReports(String groupId, String key) =>
      _run((repo, viewer) => repo.dismiss(viewer, groupId, key));
  Future<void> restoreReports(String groupId, String key) =>
      _run((repo, viewer) => repo.restoreReports(viewer, groupId, key));
  Future<void> removeSubgroup(String parentId, String subgroupId) =>
      _run((repo, viewer) => repo.removeSubgroup(viewer, parentId, subgroupId));

  Future<void> setRole(String groupId, String person, CircleRole role) =>
      _run((repo, viewer) => repo.setRole(viewer, groupId, person, role));
  Future<List<String>> removalImpact(String groupId, String person) =>
      _repository.removalImpact(_viewer, groupId, person);
  Future<void> removeMember(String groupId, String person) =>
      _run((repo, viewer) => repo.removeMember(viewer, groupId, person));
  Future<void> transferOwnership(String groupId, String person) =>
      _run((repo, viewer) => repo.transferOwnership(viewer, groupId, person));
  Future<void> leaveGroup(String groupId) =>
      _run((repo, viewer) => repo.leaveGroup(viewer, groupId));
  Future<JoinOutcome> requestToJoin(String groupId) =>
      _run((repo, viewer) => repo.requestToJoin(viewer, groupId));
  Future<void> cancelRequest(String requestId) =>
      _run((repo, viewer) => repo.cancelRequest(viewer, requestId));
  Future<void> approveRequest(String requestId) =>
      _run((repo, viewer) => repo.approveRequest(viewer, requestId));
  Future<void> declineRequest(String requestId) =>
      _run((repo, viewer) => repo.declineRequest(viewer, requestId));

  Future<InviteLink> createInviteLink(String groupId) =>
      _run((repo, viewer) => repo.createInviteLink(viewer, groupId));
  Future<void> configureInviteLink(
    String groupId, {
    required Duration expiry,
    int? maxUses,
  }) => _run(
    (repo, viewer) => repo.configureInviteLink(
      viewer,
      groupId,
      expiry: expiry,
      maxUses: maxUses,
    ),
  );
  Future<InviteLink> resetInviteLink(String groupId) =>
      _run((repo, viewer) => repo.resetInviteLink(viewer, groupId));
  Future<void> revokeInviteLink(String groupId) =>
      _run((repo, viewer) => repo.revokeInviteLink(viewer, groupId));
  Future<InvitePreview> previewInvite(String token) =>
      _repository.previewInvite(_viewer, token);
  Future<JoinOutcome> joinWithLink(String token) =>
      _run((repo, viewer) => repo.joinWithLink(viewer, token));
  Future<void> inviteMember(String groupId, String person) =>
      _run((repo, viewer) => repo.inviteMember(viewer, groupId, person));
  Future<void> cancelInvitation(String invitationId) =>
      _run((repo, viewer) => repo.cancelInvitation(viewer, invitationId));
  Future<JoinOutcome?> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) => _run(
    (repo, viewer) =>
        repo.respondToInvitation(viewer, invitationId, accept: accept),
  );
}
