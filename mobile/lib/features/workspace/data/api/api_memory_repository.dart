part of 'api_circle_repository.dart';

/// Memories: cursor-paginated list, create (with uploaded photos), edit,
/// delete with a client-side Undo window, comments with replies, the
/// 8-emoji reactions and saves. Polls aren't on the server yet.
mixin ApiMemoryRepository on ApiRepositoryBase
    implements MemoryRepository, MemoryQueryReader {
  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    _checkViewer(viewer);
    if (query.groupId != null) _requireGroup(query.groupId!);
    final page = await api.getPage(
      '/memories',
      query: {
        'limit': ApiRepositoryBase.memoryPageSize,
        if (query.groupId != null) 'group_id': query.groupId!,
        if (query.saved) 'saved': true,
        if (query.text.trim().isNotEmpty) 'q': query.text.trim(),
        'cursor': ?cursor,
      },
    );
    final ids = <String>[];
    for (final item in page.items) {
      final json = ApiJson.map(item);
      final id = ApiJson.id(json['id']);
      final groupId = ApiJson.id(json['group_id']);
      // Repeat the exact-group boundary when translating server data.
      if (!_groups.containsKey(groupId) ||
          (query.groupId != null && groupId != query.groupId)) {
        continue;
      }
      final entry = _memories[id] ?? _MemoryEntry(json);
      if (entry.json['updated_at'] != json['updated_at']) {
        entry.comments = null;
        entry.reactions = null;
      }
      entry.json = json;
      _memories[id] = entry;
      if (!_pendingDeletes.containsKey(id)) ids.add(id);
    }
    // A list says only whether the viewer reacted, not their selected emoji.
    await ApiRepositoryBase.pool(
      ids.where(
        (id) =>
            ApiJson.boolean(_memories[id]!.json['user_reacted']) &&
            !_myReactions.containsKey(id),
      ),
      (id) async {
        final json = ApiJson.map(await api.get('/memories/$id'));
        final reactions = ApiMappers.reactions(json['reactions']);
        _memories[id]!.reactions = reactions;
        _myReactions[id] = reactions[viewer];
      },
    );
    return MemoryPage(
      items: [for (final id in ids) _memory(id)],
      cursor: page.nextCursor,
      hasMore: page.hasMore && page.nextCursor != null,
    );
  }

  @override
  Future<void> _syncMemories() async {
    final page = await api.getPage(
      '/memories',
      query: {'limit': ApiRepositoryBase.memoryPageSize},
    );
    _memoryOrder.clear();
    _addPage(page);
    await _completeReactions();
  }

  void _addPage(ApiPage page) {
    for (final item in page.items) {
      final json = ApiJson.map(item);
      final id = ApiJson.id(json['id']);
      final entry = _memories[id];
      if (entry == null) {
        _memories[id] = _MemoryEntry(json);
      } else {
        final changed =
            entry.json['updated_at'] != json['updated_at'] ||
            entry.json['reaction_count'] != json['reaction_count'] ||
            entry.json['comment_count'] != json['comment_count'];
        entry.json = json;
        // Someone else commented or reacted: the breakdown is stale.
        if (changed) {
          entry
            ..comments = null
            ..reactions = null;
        }
      }
      if (!_memoryOrder.contains(id)) _memoryOrder.add(id);
    }
    _cursor = page.nextCursor;
    _hasMore = page.hasMore && _cursor != null;
  }

  /// A list only says *that* the viewer reacted; fetch which emoji, so the
  /// Love button never shows the wrong state.
  Future<void> _completeReactions() => ApiRepositoryBase.pool(
    [
      for (final id in _memoryOrder)
        if (_memories[id]!.reactions == null &&
            !_myReactions.containsKey(id) &&
            ApiJson.boolean(_memories[id]!.json['user_reacted']))
          id,
    ],
    (id) async {
      try {
        await _fetchDetails(id);
      } on ApiError catch (error) {
        if (error.isNetwork) rethrow;
      }
    },
  );

  Future<bool> loadMoreMemories(String viewer) async {
    _checkViewer(viewer);
    if (!_hasMore || _cursor == null) return false;
    try {
      _addPage(
        await api.getPage(
          '/memories',
          query: {'limit': ApiRepositoryBase.memoryPageSize, 'cursor': _cursor},
        ),
      );
    } on ApiError catch (error) {
      if (error.code != 'invalid_cursor') rethrow;
      await _syncMemories();
      return true;
    }
    await _completeReactions();
    return true;
  }

  /// `GET /memories/{id}`: comments, every reaction, the latest text.
  Future<void> _fetchDetails(String memoryId) async {
    final json = ApiJson.map(await api.get('/memories/$memoryId'));
    final entry = _memories[memoryId] ?? _MemoryEntry(json);
    final comments = [
      for (final item in ApiJson.list(json['comments']))
        ApiMappers.comment(item, viewer: viewer),
    ];
    final reactions = ApiMappers.reactions(json['reactions']);
    for (final item in ApiJson.list(json['reactions'])) {
      if (item is Map && item['display_name'] is String) {
        _people[ApiJson.id(item['user_id'])] = item['display_name'] as String;
      }
    }
    entry
      ..json = {
        ...entry.json,
        ...json,
        'comment_count': comments.length,
        'reaction_count': reactions.length,
        'user_reacted': reactions.containsKey(viewer),
      }
      ..comments = comments
      ..reactions = reactions;
    _memories[memoryId] = entry;
    _myReactions[memoryId] = reactions[viewer];
    if (!_memoryOrder.contains(memoryId)) _insertByTime(memoryId);
  }

  void _insertByTime(String memoryId) {
    final created = _memories[memoryId]!.createdAt;
    final index = _memoryOrder.indexWhere(
      (id) => _memories[id]!.createdAt.isBefore(created),
    );
    _memoryOrder.insert(index < 0 ? _memoryOrder.length : index, memoryId);
  }

  @override
  Future<bool> refreshMemory(String viewer, String memoryId) async {
    _checkViewer(viewer);
    if (_pendingDeletes.containsKey(memoryId)) return false;
    try {
      await _fetchDetails(memoryId);
    } on ApiError catch (error) {
      if (error.status != 404) rethrow;
      _memoryOrder.remove(memoryId);
      _memories.remove(memoryId);
    }
    return true;
  }

  _MemoryEntry _entry(String memoryId) {
    final entry = _memories[memoryId];
    if (entry == null || _pendingDeletes.containsKey(memoryId)) {
      throw const CircleFailure('This Memory is no longer available.');
    }
    return entry;
  }

  @override
  Future<String> createMemory(
    String viewer,
    String groupId,
    String text, {
    List<MemoryScene> photos = const [],
    // The API has no caption field yet; the composer hides captions on a
    // server, so these are never sent.
    List<String?> captions = const [],
    List<String> mediaIds = const [],
    PollDraft? poll,
    int? takenYear,
    String? place,
  }) async {
    _checkViewer(viewer);
    _requireGroup(groupId);
    if (poll != null) throw notOnServerYet(CircleFeature.polls);
    if (photos.isNotEmpty) {
      throw const CircleFailure(
        'Fictional illustrations belong to the preview. Add your own photos instead.',
      );
    }
    _check(MemoryRules.checkContent(text: text, photoCount: mediaIds.length));
    _check(MemoryRules.checkYear(takenYear, now()));
    _check(MemoryRules.checkPlace(place));
    final body = text.trim();
    final cleanPlace = MemoryRules.cleanPlace(place);
    final Object? data;
    try {
      data = await api.post(
        '/groups/$groupId/memories',
        body: {
          if (body.isNotEmpty) 'body': body,
          // The server keeps a date; the app asks only for the year.
          if (takenYear != null) 'memory_date': '$takenYear-01-01',
          'place': ?cleanPlace,
          if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
        },
      );
    } on ApiError catch (error) {
      if (error.code == 'validation_error' &&
          error.details.containsKey('media_ids')) {
        throw const CircleFailure(
          'Some photos couldn’t be added. Remove them and try again.',
        );
      }
      rethrow;
    }
    final json = ApiJson.map(data);
    final id = ApiJson.id(json['id']);
    _memories[id] =
        _MemoryEntry({
            ...json,
            'reaction_count': 0,
            'comment_count': 0,
            'user_reacted': false,
            'user_saved': false,
          })
          ..comments = []
          ..reactions = {};
    _memoryOrder
      ..remove(id)
      ..insert(0, id);
    return id;
  }

  @override
  Future<void> editMemory(String viewer, String memoryId, String text) async {
    _checkViewer(viewer);
    final entry = _entry(memoryId);
    _check(MemoryRules.canChange(entry.authorId, viewer));
    final memory = _memory(memoryId);
    _check(
      MemoryRules.checkContent(text: text, photoCount: memory.photos.length),
    );
    final body = text.trim();
    if (body.isEmpty) {
      throw const CircleFailure(
        'Write 1–2000 characters. Clearing the words isn’t on the server yet.',
      );
    }
    final json = ApiJson.map(
      await api.patch('/memories/$memoryId', body: {'body': body}),
    );
    entry.json = {...entry.json, ...json};
  }

  /// Hidden at once and sent after [undoWindow], so Undo works even though
  /// the server deletes immediately.
  @override
  Future<void> deleteMemory(String viewer, String memoryId) async {
    _checkViewer(viewer);
    final entry = _entry(memoryId);
    _check(MemoryRules.canChange(entry.authorId, viewer));
    _pendingDeletes[memoryId] = Timer(
      undoWindow,
      () => _commitDelete(memoryId),
    );
  }

  @override
  Future<void> restoreMemory(String viewer, String memoryId) async {
    _checkViewer(viewer);
    final timer = _pendingDeletes.remove(memoryId);
    if (timer == null) {
      throw const CircleFailure('This Memory was already deleted.');
    }
    timer.cancel();
  }

  @override
  Future<void> _commitDelete(String memoryId) async {
    _pendingDeletes.remove(memoryId);
    try {
      await api.delete('/memories/$memoryId');
      _memoryOrder.remove(memoryId);
      _memories.remove(memoryId);
    } on ApiError catch (error) {
      // Already gone; otherwise it reappears on the next load.
      if (error.status == 404) {
        _memoryOrder.remove(memoryId);
        _memories.remove(memoryId);
      }
    }
  }

  @override
  Future<void> loveMemory(String viewer, String memoryId) =>
      react(viewer, memoryId, loveReaction);

  @override
  Future<void> react(String viewer, String memoryId, String emoji) async {
    _checkViewer(viewer);
    _entry(memoryId);
    _check(ReactionRules.check(emoji));
    final data = ApiJson.map(
      await api.post('/memories/$memoryId/reactions', body: {'emoji': emoji}),
    );
    _myReactions[memoryId] = ApiJson.boolean(data['reacted'])
        ? ApiJson.optionalString(data['emoji'])
        : null;
    await _fetchDetails(memoryId);
  }

  @override
  Future<void> saveMemory(String viewer, String memoryId) async {
    _checkViewer(viewer);
    final entry = _entry(memoryId);
    final data = ApiJson.map(await api.post('/memories/$memoryId/save'));
    entry.json = {...entry.json, 'user_saved': ApiJson.boolean(data['saved'])};
  }

  @override
  Future<String> comment(
    String viewer,
    String memoryId,
    String text, {
    String? replyTo,
    // No mention metadata on the server yet: the text ("@Mira") is sent as
    // written and nobody is notified (documented in mobile/README.md).
    Map<String, String> mentions = const {},
  }) async {
    _checkViewer(viewer);
    final entry = _entry(memoryId);
    _check(CommentRules.checkText(text));
    if (replyTo != null && entry.comments != null) {
      _check(CommentRules.canReply(entry.comments!, replyTo));
    }
    final data = ApiJson.map(
      await api.post(
        '/memories/$memoryId/comments',
        body: {
          'body': text.trim(),
          if (replyTo != null) 'parent_id': int.tryParse(replyTo) ?? replyTo,
        },
      ),
    );
    final id = ApiJson.id(data['id']);
    await _fetchDetails(memoryId);
    return id;
  }

  @override
  Future<void> deleteComment(
    String viewer,
    String memoryId,
    String commentId,
  ) => Future.error(notOnServerYet(CircleFeature.commentDeletion));

  @override
  Future<void> restoreComment(
    String viewer,
    String memoryId,
    String commentId,
  ) => Future.error(notOnServerYet(CircleFeature.commentDeletion));

  @override
  Future<void> vote(String viewer, String memoryId, Set<String> optionIds) =>
      Future.error(notOnServerYet(CircleFeature.polls));

  @override
  Future<void> retractVote(String viewer, String memoryId) =>
      Future.error(notOnServerYet(CircleFeature.polls));

  @override
  Future<void> closePoll(String viewer, String memoryId) =>
      Future.error(notOnServerYet(CircleFeature.polls));
}
