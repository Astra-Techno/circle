import '../../profile/application/profile_providers.dart'
    show profilePhotoPickerProvider;
import '../../../core/private_photo.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/live_chat.dart';
import '../../profile/presentation/server_blocking.dart';
import '../../moderation/presentation/report_sheet.dart';

class LiveChatsScreen extends ConsumerStatefulWidget {
  const LiveChatsScreen({super.key, this.id, this.contacts = false});
  final String? id;
  final bool contacts;
  @override
  ConsumerState<LiveChatsScreen> createState() => _LiveChatsState();
}

class _LiveChatsState extends ConsumerState<LiveChatsScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = false;
  final _text = TextEditingController();
  bool _busy = false;
  final _photos = <String>[];
  int _offset = 0;
  int? _before, _reply;
  String? _retrySignature, _retryKey;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      if (visible) {
        _start();
        Future.microtask(_retrySaved);
      } else {
        _timer?.cancel();
      }
    }
  }

  void _start() {
    _timer?.cancel();
    if (!_visible) return;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy) _retrySaved();
    });
  }

  void _retrySaved() {
    if (!mounted ||
        !_visible ||
        !TickerMode.valuesOf(context).enabled ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    LiveChatApi api;
    try {
      api = ref.read(liveChatApiProvider);
    } catch (_) {
      return;
    }
    unawaited(
      api
          .flush()
          .then((_) {
            if (mounted) _refresh();
          })
          .catchError((Object _) {}),
    );
  }

  void _refresh() {
    ref.invalidate(liveChatPendingProvider);
    ref.invalidate(liveChatInboxProvider);
    ref.invalidate(liveConversationProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retrySaved();
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveChatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _text.clear();
      _photos.clear();
      _retryKey = null;
      _retrySignature = null;
      _reply = null;
      _before = null;
    }
  }

  Future<void> _run(Future<void> Function(LiveChatApi) action) async {
    final scope = ref.read(liveChatApiProvider);
    setState(() => _busy = true);
    await runCalmly(context, () => action(scope));
    if (mounted) {
      setState(() => _busy = false);
      _refresh();
    }
  }

  bool _loves(Map<String, Object?> item) => ApiJson.list(item['reactions'])
      .map(ApiJson.map)
      .any(
        (r) =>
            '${r['user_id']}' == ref.read(liveChatApiProvider).scope.account &&
            r['emoji'] == '❤️',
      );
  Future<void> _edit(String chat, Map<String, Object?> item) async {
    final scope = ref.read(liveChatApiProvider);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditLiveMessageDialog(body: item['body'] as String),
    );
    if (value != null && mounted) {
      await _run(
        (_) => scope.message(chat, ApiJson.id(item['id']), {'body': value}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveChatApiProvider, (_, _) {
      _text.clear();
      _photos.clear();
      _reply = null;
      _before = null;
      _offset = 0;
      _retryKey = null;
      _retrySignature = null;
    });
    final id = widget.id, contacts = widget.contacts;
    final load = contacts
        ? ref.watch(liveChatContactsProvider(_offset))
        : id == null
        ? ref.watch(liveChatInboxProvider(_offset))
        : ref.watch(liveConversationProvider((id: id, before: _before)));
    return ReadingPane(
      child: load.when(
        skipLoadingOnRefresh: true,
        loading: () => const CircleSkeletonPage(
          shape: CircleSkeletonShape.cards,
          count: 3,
          label: 'Loading chats',
        ),
        error: (_, _) => CircleEmpty(
          title: 'Chats couldn’t load',
          message: 'Check your connection and access.',
          action: TextButton(
            onPressed: () {
              _refresh();
              ref.invalidate(liveChatContactsProvider);
            },
            child: const Text('Try again'),
          ),
        ),
        data: (data) {
          final items = ApiJson.list(data['items']).map(ApiJson.map).toList();
          final active = data['can_send'] == true;
          final chat = id == null ? '' : ApiJson.id(data['id']);
          // At very large text sizes the composer scrolls with the
          // conversation instead of taking a fixed share of the screen.
          final inline =
              MediaQuery.textScalerOf(context).scale(1) >
              CircleLayout.largeTextThreshold;
          final composer = <Widget>[
            if (_reply != null)
              ListTile(
                title: Text('Replying to message $_reply'),
                trailing: IconButton(
                  onPressed: () => setState(() => _reply = null),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel reply',
                ),
              ),
            if (_photos.isNotEmpty)
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final photo in _photos)
                    InputChip(
                      label: Text('Photo ${_photos.indexOf(photo) + 1}'),
                      onDeleted: _busy
                          ? null
                          : () => setState(() => _photos.remove(photo)),
                    ),
                ],
              ),
            if (data['kind'] == 'group' || data['request_state'] == 'accepted')
              OutlinedButton.icon(
                onPressed: _busy || _photos.length >= 4
                    ? null
                    : () async {
                        final api = ref.read(liveChatApiProvider);
                        final picker = ref.read(profilePhotoPickerProvider);
                        setState(() => _busy = true);
                        final photo = await runCalmly(
                          context,
                          () => api.pickPhoto(chat, picker),
                        );
                        if (!mounted) return;
                        if (photo != null &&
                            identical(ref.read(liveChatApiProvider), api)) {
                          _photos.add(photo);
                        }
                        setState(() => _busy = false);
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_busy ? 'Please wait…' : 'Add photo'),
              ),
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final api = ref.read(liveChatApiProvider),
                          body = _text.text;
                      if (body.trim().isEmpty && _photos.isEmpty) {
                        return;
                      }
                      final signature =
                          '$chat\n$body\n$_reply\n${_photos.join(',')}';
                      if (signature != _retrySignature) {
                        _retrySignature = signature;
                        _retryKey =
                            'circle-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
                      }
                      setState(() => _busy = true);
                      final ok = await runCalmly(context, () async {
                        await api.send(chat, {
                          'body': body,
                          'client_id': _retryKey,
                          if (_photos.isNotEmpty)
                            'attachments': List<String>.of(_photos),
                          if (_reply != null) 'reply_to_id': _reply,
                        });
                        return true;
                      });
                      if (!mounted) return;
                      if (ok == true &&
                          identical(ref.read(liveChatApiProvider), api)) {
                        _text.clear();
                        _photos.clear();
                        _retryKey = null;
                        _retrySignature = null;
                        _reply = null;
                        _before = null;
                      }
                      setState(() => _busy = false);
                      _refresh();
                    },
              icon: const Icon(Icons.send_outlined),
              label: Text(_busy ? 'Sending…' : 'Send'),
            ),
          ];
          final list = ListView(
            padding: CircleInsets.form,
            children: [
              CircleHeading(
                title: contacts
                    ? 'New message'
                    : id == null
                    ? 'Chats'
                    : data['name'] as String? ??
                          (data['kind'] == 'direct'
                              ? 'Direct message'
                              : 'Group chat'),
                subtitle: contacts
                    ? 'Choose someone from your groups.'
                    : id == null
                    ? 'Keep your people close.'
                    : active
                    ? 'Your private conversation.'
                    : 'Read-only. Sending is currently unavailable.',
              ),
              if (id == null && !contacts)
                Wrap(
                  spacing: Space.md,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/chats/new'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('New message'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/chats/privacy'),
                      child: const Text('Messaging privacy'),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        _refresh();
                        ref.invalidate(liveChatContactsProvider);
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              if (id != null && data['other_id'] != null)
                ServerBlockButton(
                  person: ApiJson.id(data['other_id']),
                  name: data['name'] as String? ?? 'this person',
                ),
              if (id != null) ...[
                if (data['request_state'] == 'pending') ...[
                  Text(
                    data['incoming'] == true
                        ? 'A message request. Accept only if you want to chat.'
                        : 'Your request is waiting. You can send one introduction.',
                  ),
                  if (data['incoming'] == true)
                    Wrap(
                      spacing: Space.md,
                      children: [
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                    _run((api) => api.respond(chat, 'accept')),
                          child: const Text('Accept request'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                    _run((api) => api.respond(chat, 'decline')),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mute this chat'),
                  value: data['muted'] == true,
                  onChanged: _busy
                      ? null
                      : (v) => _run((api) => api.state(chat, {'muted': v})),
                ),
                Wrap(
                  spacing: Space.md,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (api) => api.state(chat, {
                                'pinned': data['pinned'] != true,
                              }),
                            ),
                      child: Text(
                        data['pinned'] == true ? 'Unpin' : 'Pin chat',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (api) => api.state(chat, {
                                'archived': data['archived'] != true,
                              }),
                            ),
                      child: Text(
                        data['archived'] == true ? 'Unarchive' : 'Archive',
                      ),
                    ),
                  ],
                ),
              ],
              if (items.isEmpty)
                CircleEmpty(
                  title: contacts
                      ? 'No people to show'
                      : id == null
                      ? 'Your conversations start here'
                      : 'Say hello',
                  message: contacts
                      ? 'Join a group to message its members.'
                      : id == null
                      ? 'Group conversations follow your memberships.'
                      : 'Start a conversation with your circle.',
                ),
              for (final item in items)
                if (contacts)
                  Card(
                    child: ListTile(
                      title: Text(item['display_name'] as String),
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: _busy
                          ? null
                          : () async {
                              final api = ref.read(liveChatApiProvider);
                              final opened = await runCalmly(
                                context,
                                () => api.direct(ApiJson.id(item['id'])),
                              );
                              if (context.mounted && opened != null) {
                                context.go('/chats/c/$opened');
                              }
                            },
                    ),
                  )
                else if (id == null)
                  Card(
                    child: ListTile(
                      title: Text(item['name'] as String? ?? 'Conversation'),
                      subtitle: Text(
                        '${item['request_state'] == 'pending' ? (item['incoming'] == true ? 'Message request · ' : 'Waiting · ') : ''}${item['archived'] == true ? 'Archived · ' : ''}${item['pinned'] == true ? 'Pinned · ' : ''}${item['unread']} unread',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/chats/c/${item['id']}'),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: Space.md),
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: CircleDepth.panel(
                      context,
                      radius: CircleRadius.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['display_name'] as String,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (item['reply_to_id'] != null)
                          Text(
                            'Reply to message ${item['reply_to_id']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        SelectableText(
                          item['removed'] == true
                              ? 'Message unsent'
                              : item['body'] as String,
                        ),
                        if (item['removed'] != true)
                          for (final photo in ApiJson.list(item['attachments']))
                            PrivatePhoto(
                              load: ref.watch(
                                liveChatPhotoProvider((
                                  chat: chat,
                                  photo: photo as String,
                                )),
                              ),
                              label: 'Chat photo',
                            ),
                        if (item['edited'] == true) const Text('Edited'),
                        if (ApiJson.list(item['reactions']).isNotEmpty)
                          Text(
                            ApiJson.list(
                              item['reactions'],
                            ).map((v) => ApiJson.map(v)['emoji']).join(' '),
                          ),
                        if (data['kind'] == 'direct' &&
                            item['removed'] != true &&
                            '${item['author_id']}' !=
                                ref.read(liveChatApiProvider).scope.account)
                          TextButton(
                            onPressed: () {
                              final api = ref.read(liveChatApiProvider);
                              showReportSheet(
                                context,
                                title: 'Report this message',
                                explanation:
                                    'This selected message and your optional note will be saved privately for server administrator review. The rest of your conversation is not shared. No alert is sent to the other person.',
                                confirmation:
                                    'Report saved privately for review.',
                                submit: (reason, note) => api.report(
                                  chat,
                                  ApiJson.id(item['id']),
                                  reason.name,
                                  note,
                                ),
                              );
                            },
                            child: const Text('Report message'),
                          ),
                        if (active)
                          Wrap(
                            spacing: Space.sm,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _reply = int.parse(
                                          ApiJson.id(item['id']),
                                        ),
                                      ),
                                child: const Text('Reply'),
                              ),
                              if (item['removed'] != true)
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          (api) => api.react(
                                            chat,
                                            ApiJson.id(item['id']),
                                            _loves(item) ? null : '❤️',
                                          ),
                                        ),
                                  icon: Icon(
                                    _loves(item)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                                  tooltip: _loves(item)
                                      ? 'Remove heart'
                                      : 'React with heart',
                                ),
                              if ('${item['author_id']}' ==
                                  ref
                                      .read(liveChatApiProvider)
                                      .scope
                                      .account) ...[
                                if (item['removed'] != true)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _edit(chat, item),
                                    child: const Text('Edit'),
                                  ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          (api) => api.message(
                                            chat,
                                            ApiJson.id(item['id']),
                                            {
                                              'removed':
                                                  item['removed'] != true,
                                            },
                                          ),
                                        ),
                                  child: Text(
                                    item['removed'] == true
                                        ? 'Undo unsend'
                                        : 'Unsend',
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
              Wrap(
                spacing: Space.md,
                children: [
                  if (id == null && _offset > 0)
                    TextButton(
                      onPressed: () => setState(() => _offset -= 30),
                      child: const Text('Previous'),
                    ),
                  if (data['has_more'] == true)
                    TextButton(
                      onPressed: () => setState(() {
                        if (id == null) {
                          _offset += 30;
                        } else if (items.isNotEmpty) {
                          _before = int.parse(ApiJson.id(items.first['id']));
                        }
                      }),
                      child: Text(id == null ? 'Next' : 'Older messages'),
                    ),
                  if (id != null && _before != null)
                    TextButton(
                      onPressed: () => setState(() => _before = null),
                      child: const Text('Latest messages'),
                    ),
                ],
              ),
              if (id != null && items.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          (api) => api.state(chat, {
                            'read_id': int.parse(ApiJson.id(items.last['id'])),
                          }),
                        ),
                  child: const Text('Mark as read'),
                ),
              if (id != null)
                for (final pending
                    in (ref.watch(liveChatPendingProvider).asData?.value ??
                            <Map<String, Object?>>[])
                        .where((p) => p['chat'] == chat))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pending['failed'] == true
                                ? 'Pending message needs review'
                                : 'Pending · will retry while Chats is open',
                          ),
                          Text(
                            [
                              if (ApiJson.list(
                                ApiJson.map(pending['body'])['attachments'],
                              ).isNotEmpty)
                                '${ApiJson.list(ApiJson.map(pending['body'])['attachments']).length} photo(s)',
                              if ((ApiJson.map(pending['body'])['body']
                                          as String? ??
                                      '')
                                  .isNotEmpty)
                                ApiJson.map(pending['body'])['body'] as String,
                            ].join(' · '),
                          ),
                          Wrap(
                            spacing: Space.sm,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run((api) async {
                                        await api.outbox.retry(
                                          ApiJson.id(
                                            ApiJson.map(
                                              pending['body'],
                                            )['client_id'],
                                          ),
                                        );
                                        await api.flush();
                                      }),
                                child: const Text('Retry pending message'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        (api) => api.outbox.discard(
                                          ApiJson.id(
                                            ApiJson.map(
                                              pending['body'],
                                            )['client_id'],
                                          ),
                                        ),
                                      ),
                                child: const Text('Cancel pending send'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              if (id != null && active && inline) ...composer,
            ],
          );
          // The composer is pinned below the conversation, in the thumb
          // zone; it scrolls on its own if it grows (photos, replies).
          if (id == null || !active || inline) return list;
          return Column(
            children: [
              Expanded(child: list),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: CircleAccents.of(context).hairline),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height / 3,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Space.section,
                      Space.sm,
                      Space.section,
                      Space.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...composer],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LiveChatPrivacyScreen extends ConsumerWidget {
  const LiveChatPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ReadingPane(
    child: ref
        .watch(liveChatPrivacyProvider)
        .when(
          loading: () =>
              const CircleSkeletonPage(label: 'Loading messaging choices'),
          error: (_, _) => CircleEmpty(
            title: 'Choices couldn’t load',
            message: 'Try again when connected.',
            action: TextButton(
              onPressed: () => ref.invalidate(liveChatPrivacyProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (data) => ListView(
            padding: CircleInsets.form,
            children: [
              const CircleHeading(
                title: 'Messaging privacy',
                subtitle: 'Choose who can send you direct messages.',
              ),
              RadioGroup<String>(
                groupValue: data['who_can_message'] as String,
                onChanged: (value) async {
                  final api = ref.read(liveChatApiProvider);
                  await runCalmly(context, () => api.setPrivacy(value!));
                  ref.invalidate(liveChatPrivacyProvider);
                },
                child: Column(
                  children: [
                    for (final entry in {
                      'all': 'People in my groups',
                      'existing': 'Accepted conversations only',
                      'none': 'Nobody',
                    }.entries)
                      RadioListTile<String>(
                        title: Text(entry.value),
                        value: entry.key,
                      ),
                  ],
                ),
              ),
              const Text(
                'First contact waits in message requests. Blocks stop direct contact in both directions. Shared-group conversations remain visible.',
              ),
            ],
          ),
        ),
  );
}

class _EditLiveMessageDialog extends StatefulWidget {
  const _EditLiveMessageDialog({required this.body});
  final String body;
  @override
  State<_EditLiveMessageDialog> createState() => _EditLiveMessageDialogState();
}

class _EditLiveMessageDialogState extends State<_EditLiveMessageDialog> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.body);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit message'),
    content: TextField(
      controller: _text,
      minLines: 1,
      maxLines: 5,
      maxLength: 4000,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('Save'),
      ),
    ],
  );
}
