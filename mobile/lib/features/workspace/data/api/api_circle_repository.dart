import 'dart:async';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_json.dart';
import '../../../groups/domain/membership_rules.dart';
import '../../domain/circle_features.dart';
import '../../domain/circle_repository.dart';
import 'api_mappers.dart';

part 'api_group_repository.dart';
part 'api_invitation_repository.dart';
part 'api_membership_repository.dart';
part 'api_memory_repository.dart';

/// The CIRCLE API behind the app's repository interfaces (contract 0.3.1).
///
/// It keeps a small in-memory copy of what the viewer may see, so building
/// the workspace after a change costs no network round trip; each change
/// updates that copy from the server's answer or refetches just what it
/// touched. [refresh] reloads everything. Events, polls and moderation
/// aren't on the server yet: their methods fail calmly and the workspace
/// has none, so no fictional data is ever mixed into real groups.
class ApiCircleRepository extends ApiRepositoryBase
    with
        ApiGroupRepository,
        ApiMembershipRepository,
        ApiInvitationRepository,
        ApiMemoryRepository
    implements CircleRepository {
  ApiCircleRepository({
    required super.api,
    required super.viewer,
    super.viewerName,
    super.now,
    super.undoWindow,
  });

  // ── Workspace ──────────────────────────────────────────────────────

  @override
  Future<CircleWorkspace> load(String viewer) async {
    _checkViewer(viewer);
    if (!_loaded) await _syncAll();
    return _build();
  }

  @override
  Future<bool> refresh(String viewer) async {
    _checkViewer(viewer);
    _loaded = false;
    await _syncAll();
    return true;
  }

  /// Forgets everything cached (used when a session ends).
  @override
  Future<void> reset({required bool showcase}) async {
    _clear();
  }

  // ── Not on the server yet ──────────────────────────────────────────

  @override
  Future<String> createEvent(String viewer, EventDraft draft) =>
      Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> editEvent(String viewer, String eventId, EventDraft draft) =>
      Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> cancelEvent(String viewer, String eventId) =>
      Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> rsvp(String viewer, String eventId, Rsvp? response) =>
      Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> voteEventPoll(
    String viewer,
    String eventId,
    Set<String> optionIds,
  ) => Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> retractEventPollVote(String viewer, String eventId) =>
      Future.error(notOnServerYet(CircleFeature.events));
  @override
  Future<void> closeEventPoll(String viewer, String eventId) =>
      Future.error(notOnServerYet(CircleFeature.events));

  @override
  Future<void> report(String viewer, ReportDraft draft) =>
      Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<ModerationQueue> queue(String viewer, String groupId) =>
      Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<void> hide(String viewer, String groupId, String targetKey) =>
      Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<void> unhide(String viewer, String groupId, String targetKey) =>
      Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<void> dismiss(String viewer, String groupId, String targetKey) =>
      Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<void> restoreReports(
    String viewer,
    String groupId,
    String targetKey,
  ) => Future.error(notOnServerYet(CircleFeature.moderation));
  @override
  Future<void> removeSubgroup(
    String viewer,
    String parentId,
    String subgroupId,
  ) => Future.error(notOnServerYet(CircleFeature.moderation));
}

/// A group as cached: the server's JSON plus what other calls added.
class _GroupEntry {
  _GroupEntry(this.json);
  Map<String, Object?> json;

  /// Every active member, from `/groups/{id}/members`.
  Map<String, CircleRole>? roles;

  /// From the full `Group` (not part of the `/groups` list).
  String? linkSharing, eventCreation;

  String get id => ApiJson.id(json['id']);
  String? get parentId => ApiJson.optionalId(json['parent_id']);
  String get name => ApiJson.string(json['name']);
}

/// A link created on this device (tokens are shown only once).
class _LinkEntry {
  _LinkEntry(this.id, this.link);
  final String id;
  InviteLink link;
}

/// A Memory as cached: list JSON plus, once opened, its comments and
/// every reaction.
class _MemoryEntry {
  _MemoryEntry(this.json);
  Map<String, Object?> json;
  List<MemoryComment>? comments;
  Map<String, String>? reactions;

  String get groupId => ApiJson.id(json['group_id']);
  String get authorId => ApiJson.id(json['author_id']);
  DateTime get createdAt =>
      ApiJson.time(json['created_at']) ?? DateTime.utc(1970);
}

/// Shared state and helpers for the API repository parts.
abstract class ApiRepositoryBase {
  ApiRepositoryBase({
    required this.api,
    required this.viewer,
    this.viewerName = 'You',
    DateTime Function()? now,
    this.undoWindow = const Duration(seconds: 8),
  }) : now = now ?? DateTime.now;

  final ApiClient api;

  /// The signed-in person's id; this repository serves only them.
  final String viewer;
  final String viewerName;
  final DateTime Function() now;

  /// How long a deleted Memory can still be brought back with Undo before
  /// the deletion is sent (the server deletes at once).
  final Duration undoWindow;

  static const memoryPageSize = 20;

  bool _loaded = false;
  Future<void>? _syncing;

  /// Groups in the server's order (root, depth, name).
  final Map<String, _GroupEntry> _groups = {};
  final Map<String, String> _people = {};
  final Map<String, _LinkEntry> _links = {};
  final Map<String, JoinRequest> _requests = {};

  final List<String> _memoryOrder = [];
  final Map<String, _MemoryEntry> _memories = {};

  /// The viewer's reaction per Memory, when known from this session.
  final Map<String, String?> _myReactions = {};
  String? _cursor;
  bool _hasMore = false;
  final Map<String, Timer> _pendingDeletes = {};

  void _checkViewer(String person) {
    if (person != viewer) {
      throw const CircleFailure('Please log in again.');
    }
  }

  void _check(RuleResult rule) {
    if (!rule.allowed) throw CircleFailure(rule.reason!);
  }

  void _clear() {
    _loaded = false;
    _groups.clear();
    _people.clear();
    _links.clear();
    _requests.clear();
    _memoryOrder.clear();
    _memories.clear();
    _myReactions.clear();
    _cursor = null;
    _hasMore = false;
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    _pendingDeletes.clear();
  }

  /// Sends deletions still waiting for their Undo window (before logout).
  Future<void> flushPendingDeletes() async {
    final ids = _pendingDeletes.keys.toList();
    for (final id in ids) {
      _pendingDeletes.remove(id)?.cancel();
      await _commitDelete(id);
    }
  }

  Future<void> _commitDelete(String memoryId);

  void dispose() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    _pendingDeletes.clear();
  }

  /// Runs [task] for every item, at most [width] at a time.
  static Future<void> pool<T>(
    Iterable<T> items,
    Future<void> Function(T item) task, {
    int width = 4,
  }) async {
    final queue = items.toList();
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        await task(queue[next++]);
      }
    }

    await Future.wait([
      for (var i = 0; i < width && i < queue.length; i++) worker(),
    ]);
  }

  Future<void> _syncAll() => _syncing ??= () async {
    try {
      await _syncGroups();
      await _syncMemories();
      _loaded = true;
    } finally {
      _syncing = null;
    }
  }();

  Future<void> _syncGroups();
  Future<void> _syncMemories();

  CircleRole? _roleIn(String groupId) {
    final entry = _groups[groupId];
    if (entry == null) return null;
    final roles = entry.roles;
    if (roles != null && roles[viewer] != null) return roles[viewer];
    return ApiMappers.role(
      entry.json['role'] ?? entry.json['my_role'],
      owner: ApiJson.optionalId(entry.json['owner_user_id']) == viewer,
    );
  }

  bool _isAdmin(String groupId) => _roleIn(groupId)?.isAdmin ?? false;

  Map<String, CircleRole> _rolesOf(_GroupEntry entry) {
    final known = entry.roles;
    if (known != null && known.isNotEmpty) return known;
    final owner = ApiJson.optionalId(entry.json['owner_user_id']);
    return {
      ?owner: CircleRole.owner,
      viewer: _roleIn(entry.id) ?? CircleRole.member,
    };
  }

  CircleGroup _group(_GroupEntry entry, int order) => ApiMappers.group(
    entry.json,
    roles: _rolesOf(entry),
    linkSharing: entry.linkSharing,
    eventCreation: entry.eventCreation,
    inviteLink: _links[entry.id]?.link,
    order: order,
  );

  CircleGroup _requireGroup(String groupId) {
    final entry = _groups[groupId];
    if (entry == null) {
      throw const CircleFailure('This group is not shared with you.');
    }
    return _group(entry, _groups.keys.toList().indexOf(groupId));
  }

  Map<String, CircleGroup> _domainGroups() {
    var order = 0;
    return {
      for (final entry in _groups.values) entry.id: _group(entry, order++),
    };
  }

  CircleMemory _memory(String id) {
    final entry = _memories[id]!;
    return ApiMappers.memory(
      entry.json,
      viewer: viewer,
      comments: entry.comments,
      reactions: entry.reactions,
      myReaction: _myReactions[id],
    );
  }

  CircleWorkspace _build() {
    final groups = _domainGroups();
    final memories = [
      for (final id in _memoryOrder)
        if (!_pendingDeletes.containsKey(id) &&
            groups.containsKey(_memories[id]?.groupId))
          _memory(id),
    ];
    return CircleWorkspace(
      viewer: viewer,
      groups: groups.values.toList(),
      memories: memories,
      events: const [],
      joinRequests: [
        for (final request in _requests.values)
          if (_isAdmin(request.groupId)) request,
      ],
      people: {..._people, viewer: viewerName},
      hasMoreMemories: _hasMore,
    );
  }
}
