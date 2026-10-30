import '../../profile/application/profile_providers.dart'
    show profilePhotoPickerProvider;
import '../../../core/private_photo.dart';
import 'live_chat_design.dart';
import 'dart:async';
import 'package:flutter/services.dart';
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

  /// Inbox/contact rows from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];
  bool _loadingMore = false;
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
    _thread.dispose();
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

  int? _readMarked;

  /// The reversed conversation list: offset 0 is the newest message and,
  /// at large text, the composer.
  final _thread = ScrollController();

  /// Starts a reply and brings the composer into view.
  void _replyTo(Map<String, Object?> item) {
    setState(() => _reply = int.parse(ApiJson.id(item['id'])));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_thread.hasClients) {
        _thread.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go('/chats');

  /// Opening the latest messages marks them read, as WhatsApp does. The
  /// read position only drives this person's own unread count; it is never
  /// shown to anyone else.
  void _markRead(String chat, List<Map<String, Object?>> items) {
    if (_before != null || items.isEmpty) return;
    final last = int.tryParse(ApiJson.id(items.last['id']));
    if (last == null || last == _readMarked) return;
    _readMarked = last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LiveChatApi api;
      try {
        api = ref.read(liveChatApiProvider);
      } catch (_) {
        return;
      }
      unawaited(
        api
            .state(chat, {'read_id': last})
            .then((_) {
              if (mounted) ref.invalidate(liveChatInboxProvider);
            })
            .catchError((Object _) {}),
      );
    });
  }

  Future<void> _options(String chat, Map<String, Object?> data) {
    final active = data['can_send'] == true;
    VoidCallback run(Future<void> Function(LiveChatApi) action) =>
        () => _run(action);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) {
        VoidCallback close(VoidCallback then) => () {
          Navigator.of(sheet).pop();
          then();
        };
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_off_outlined),
                title: const Text('Mute this chat'),
                value: data['muted'] == true,
                onChanged: _busy
                    ? null
                    : (v) =>
                          close(run((api) => api.state(chat, {'muted': v})))(),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(data['pinned'] == true ? 'Unpin' : 'Pin chat'),
                onTap: _busy
                    ? null
                    : close(
                        run(
                          (api) => api.state(chat, {
                            'pinned': data['pinned'] != true,
                          }),
                        ),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(data['archived'] == true ? 'Unarchive' : 'Archive'),
                onTap: _busy
                    ? null
                    : close(
                        run(
                          (api) => api.state(chat, {
                            'archived': data['archived'] != true,
                          }),
                        ),
                      ),
              ),
              if (active && data['kind'] == 'group' && data['group_id'] != null)
                ListTile(
                  leading: const Icon(Icons.poll_outlined),
                  title: const Text('Group polls'),
                  onTap: close(
                    () => context.push('/polls?group=${data['group_id']}'),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh'),
                onTap: close(_refresh),
              ),
              if (data['other_id'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: ServerBlockButton(
                    person: ApiJson.id(data['other_id']),
                    name: data['name'] as String? ?? 'this person',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Inbox preview: "You: …", "Mira: …" in groups, a photo or unsent note.
  ({String text, IconData? icon, bool highlight}) _preview(
    Map<String, Object?> item,
    String me,
  ) {
    if (item['request_state'] == 'pending') {
      return (
        text: item['incoming'] == true
            ? 'Message request'
            : 'Waiting for acceptance',
        icon: null,
        highlight: item['incoming'] == true,
      );
    }
    final last = item['last_message'] is Map
        ? ApiJson.map(item['last_message'])
        : null;
    if (last == null) {
      return (
        text: item['archived'] == true
            ? 'Archived conversation'
            : item['kind'] == 'group'
            ? 'Group conversation'
            : 'Direct conversation',
        icon: null,
        highlight: false,
      );
    }
    final who = '${last['author_id']}' == me
        ? 'You: '
        : item['kind'] == 'group'
        ? '${last['author_name'] ?? 'Someone'}: '
        : '';
    if (last['removed'] == true) {
      return (
        text: '${who}Message unsent',
        icon: Icons.block,
        highlight: false,
      );
    }
    final photos = (last['photos'] as num?)?.toInt() ?? 0;
    final body = (last['body'] as String? ?? '').replaceAll('\n', ' ');
    return (
      text:
          who +
          (body.isNotEmpty
              ? body
              : photos == 1
              ? 'Photo'
              : '$photos photos'),
      icon: photos > 0 ? Icons.photo_camera_outlined : null,
      highlight: false,
    );
  }

  Widget _inbox(Map<String, Object?> data, List<Map<String, Object?>> items) {
    final me = ref.read(liveChatApiProvider).scope.account;
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _offset = 0;
          _earlier.clear();
          _loadingMore = false;
        });
        _refresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Collapsing pinned header: large title shrinks to compact bar.
          const CircleCollapsingHeader(),
          SliverPadding(
            padding: CircleInsets.page.copyWith(
              left: 0,
              right: 0,
              top: Space.xs,
            ),
            sliver: SliverList.list(
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.section),
                    child: CircleEmpty(
                      title: 'Your conversations start here',
                      message: 'Group conversations follow your memberships.',
                    ),
                  ),
                for (final item in items)
                  Builder(
                    builder: (context) {
                      final preview = _preview(item, me);
                      final last = item['last_message'] is Map
                          ? ApiJson.map(item['last_message'])
                          : null;
                      final at = DateTime.tryParse('${last?['created_at']}');
                      return ChatInboxRow(
                        name: item['name'] as String? ?? 'Conversation',
                        group: item['kind'] == 'group',
                        groupId: item['group_id']?.toString(),
                        person: item['other_id']?.toString(),
                        unread: (item['unread'] as num?)?.toInt() ?? 0,
                        muted: item['muted'] == true,
                        pinned: item['pinned'] == true,
                        time: at == null
                            ? null
                            : chatInboxTime(context, at, now),
                        preview: preview.text,
                        previewIcon: preview.icon,
                        highlight: preview.highlight,
                        onTap: () => context.go('/chats/c/${item['id']}'),
                      );
                    },
                  ),
                _pages(data, items, inbox: true),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/chats/privacy'),
                    child: const Text('Messaging privacy'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactsList(List<Map<String, Object?>> items, Map data) => ListView(
    padding: CircleInsets.page.copyWith(left: 0, right: 0, top: Space.xs),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.section,
          Space.sm,
          Space.section,
          Space.sm,
        ),
        child: Text(
          'People from your groups',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CircleAccents.of(context).caption,
          ),
        ),
      ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.section),
          child: CircleEmpty(
            title: 'No people to show',
            message: 'Join a group to message its members.',
          ),
        ),
      for (final item in items)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
          leading: ChatIdentity(
            name: item['display_name'] as String,
            person: '${item['id']}',
          ),
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
                  if (mounted && opened != null) {
                    context.go('/chats/c/$opened');
                  }
                },
        ),
      _pages(data.cast(), items, inbox: true),
    ],
  );

  Widget _pages(
    Map<String, Object?> data,
    List<Map<String, Object?>> items, {
    required bool inbox,
  }) => Wrap(
    alignment: WrapAlignment.center,
    spacing: Space.md,
    children: [
      // Lists load the next page as they scroll; no Next/Previous.
      if (inbox && (data['has_more'] == true || _loadingMore))
        CircleLoadMore(
          key: ValueKey('more-$_offset'),
          onLoad: () {
            if (_loadingMore || data['has_more'] != true) return;
            setState(() {
              _earlier.addAll(ApiJson.list(data['items']).map(ApiJson.map));
              _offset += 30;
              _loadingMore = true;
            });
          },
        ),
      if (!inbox && data['has_more'] == true)
        TextButton(
          onPressed: () => setState(() {
            if (items.isNotEmpty) {
              _before = int.parse(ApiJson.id(items.first['id']));
            }
          }),
          child: const Text('Older messages'),
        ),
      if (!inbox && _before != null)
        TextButton(
          onPressed: () => setState(() => _before = null),
          child: const Text('Latest messages'),
        ),
    ],
  );

  List<Widget> _messageActions(
    String chat,
    Map<String, Object?> data,
    Map<String, Object?> item,
    String me,
  ) {
    final active = data['can_send'] == true;
    final mine = '${item['author_id']}' == me;
    final removed = item['removed'] == true;
    return [
      if (active)
        ListTile(
          leading: const Icon(Icons.reply),
          title: const Text('Reply'),
          onTap: _busy ? null : () => _replyTo(item),
        ),
      if (active && !removed)
        ListTile(
          leading: Icon(_loves(item) ? Icons.favorite : Icons.favorite_border),
          title: Text(_loves(item) ? 'Remove heart' : 'React with heart'),
          onTap: _busy
              ? null
              : () => _run(
                  (api) => api.react(
                    chat,
                    ApiJson.id(item['id']),
                    _loves(item) ? null : '❤️',
                  ),
                ),
        ),
      if (!removed && (item['body'] as String? ?? '').isNotEmpty)
        ListTile(
          leading: const Icon(Icons.copy_outlined),
          title: const Text('Copy'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: item['body'] as String));
            showCircleMessage(context, 'Message copied.');
          },
        ),
      if (active && mine && !removed)
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit'),
          onTap: _busy ? null : () => _edit(chat, item),
        ),
      if (active && mine)
        ListTile(
          leading: Icon(removed ? Icons.undo : Icons.delete_outline),
          title: Text(removed ? 'Undo unsend' : 'Unsend'),
          onTap: _busy
              ? null
              : () => _run(
                  (api) => api.message(chat, ApiJson.id(item['id']), {
                    'removed': !removed,
                  }),
                ),
        ),
      if (data['kind'] == 'direct' && !removed && !mine)
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Report message'),
          onTap: () {
            final api = ref.read(liveChatApiProvider);
            showReportSheet(
              context,
              title: 'Report this message',
              explanation:
                  'This selected message and your optional note will be saved privately for server administrator review. The rest of your conversation is not shared. No alert is sent to the other person.',
              confirmation: 'Report saved privately for review.',
              submit: (reason, note) =>
                  api.report(chat, ApiJson.id(item['id']), reason.name, note),
            );
          },
        ),
    ];
  }

  Widget _conversation(
    String chat,
    Map<String, Object?> data,
    List<Map<String, Object?>> items,
  ) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final me = ref.read(liveChatApiProvider).scope.account;
    final active = data['can_send'] == true;
    final group = data['kind'] == 'group';
    final pending = data['request_state'] == 'pending';
    final now = DateTime.now();
    _markRead(chat, items);
    // At very large text sizes the composer scrolls with the conversation
    // instead of taking a fixed share of the screen.
    final inline =
        MediaQuery.textScalerOf(context).scale(1) >
        CircleLayout.largeTextThreshold;
    final byId = {for (final item in items) ApiJson.id(item['id']): item};
    String nameOf(Map<String, Object?> item) =>
        '${item['author_id']}' == me ? 'You' : '${item['display_name']}';

    final thread = <Widget>[
      _pages(data, items, inbox: false),
      if (pending) ...[
        ChatNoticeChip(
          data['incoming'] == true
              ? 'A message request. Accept only if you want to chat.'
              : 'Your request is waiting. You can send one introduction.',
        ),
        if (data['incoming'] == true)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.sm,
              children: [
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run((api) => api.respond(chat, 'accept')),
                  child: const Text('Accept request'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run((api) => api.respond(chat, 'decline')),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ),
      ],
      if (items.isEmpty) const ChatNoticeChip('Say hello to start the chat.'),
    ];
    DateTime? previousDay;
    String? previousAuthor;
    for (final item in items) {
      final at = DateTime.tryParse('${item['created_at']}');
      final day = at == null ? null : DateUtils.dateOnly(at.toLocal());
      final newDay = day != null && day != previousDay;
      if (newDay) thread.add(ChatNoticeChip(chatDayLabel(context, at!, now)));
      final author = '${item['author_id']}';
      final mine = author == me;
      final first = newDay || author != previousAuthor;
      previousDay = day ?? previousDay;
      previousAuthor = author;
      final removed = item['removed'] == true;
      final reply = item['reply_to_id'] == null
          ? null
          : byId[ApiJson.id(item['reply_to_id'])];
      final actions = _messageActions(chat, data, item, me);
      thread.add(
        ChatMessageBubble(
          mine: mine,
          tail: first,
          sender: group && !mine && first ? '${item['display_name']}' : null,
          sentAt: at,
          edited: item['edited'] == true,
          quote: item['reply_to_id'] == null
              ? null
              : ChatQuote(
                  author: reply == null ? 'Reply' : nameOf(reply),
                  text: reply == null
                      ? 'An earlier message'
                      : reply['removed'] == true
                      ? 'Message unsent'
                      : '${reply['body']}',
                ),
          photos: [
            if (!removed)
              for (final photo in ApiJson.list(item['attachments']))
                PrivatePhoto(
                  load: ref.watch(
                    liveChatPhotoProvider((chat: chat, photo: photo as String)),
                  ),
                  label: 'Chat photo',
                ),
          ],
          reactions: [
            for (final reaction in ApiJson.list(item['reactions']))
              '${ApiJson.map(reaction)['emoji']}',
          ],
          onOptions: actions.isEmpty
              ? null
              : () => showChatMessageActions(context, actions),
          child: Text(
            removed ? 'Message unsent' : item['body'] as String,
            style: removed
                ? theme.textTheme.bodyLarge?.copyWith(
                    color: accents.caption,
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    for (final queued
        in (ref.watch(liveChatPendingProvider).asData?.value ??
                <Map<String, Object?>>[])
            .where((p) => p['chat'] == chat)) {
      final body = ApiJson.map(queued['body']);
      final photos = ApiJson.list(body['attachments']).length;
      final clientId = ApiJson.id(body['client_id']);
      thread.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ChatMessageBubble(
              mine: true,
              child: Text(
                [
                  if (photos > 0) '$photos photo(s)',
                  if ((body['body'] as String? ?? '').isNotEmpty)
                    body['body'] as String,
                ].join(' · '),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Text(
              queued['failed'] == true
                  ? 'Pending message needs review'
                  : 'Pending · will retry while Chats is open',
              style: theme.textTheme.bodySmall?.copyWith(
                color: accents.caption,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: Space.sm,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run((api) async {
                          await api.outbox.retry(clientId);
                          await api.flush();
                        }),
                  child: const Text('Retry pending message'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run((api) => api.outbox.discard(clientId)),
                  child: const Text('Cancel pending send'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (!active && !pending) {
      thread.add(
        ChatNoticeChip(
          group
              ? 'You’re no longer in this group. Earlier messages stay here.'
              : 'You can’t reply to this conversation.',
        ),
      );
    }

    final replying = _reply == null ? null : byId['$_reply'];
    final composer = <Widget>[
      if (_reply != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accents.chatIncoming,
              borderRadius: BorderRadius.circular(CircleRadius.small),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
                    child: ChatQuote(
                      author: replying == null
                          ? 'Reply'
                          : 'Replying to ${nameOf(replying)}',
                      text: replying == null
                          ? 'Replying to message $_reply'
                          : '${replying['body']}',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _reply = null),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel reply',
                ),
              ],
            ),
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
      ChatComposerBar(
        expanded: inline,
        photo: group || data['request_state'] == 'accepted'
            ? IconButton(
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
                icon: const Icon(Icons.photo_camera_outlined),
                tooltip: _busy ? 'Please wait…' : 'Add photo',
              )
            : null,
        field: TextField(
          controller: _text,
          enabled: !_busy,
          minLines: 1,
          maxLines: 5,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Message',
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: Space.md),
          ),
        ),
        send: IconButton.filled(
          style: IconButton.styleFrom(
            minimumSize: const Size.square(Space.large),
          ),
          onPressed: _busy ? null : () => _send(chat),
          icon: const Icon(Icons.send_rounded),
          tooltip: _busy ? 'Sending…' : 'Send',
        ),
      ),
    ];

    final pinned = active && !inline;
    return Column(
      children: [
        ChatTopBar(
          name: data['name'] as String? ?? 'Conversation',
          subtitle: pending
              ? 'Message request'
              : !active
              ? 'Read only'
              : group
              ? 'Group chat'
              : 'Direct message',
          group: group,
          groupId: data['group_id']?.toString(),
          person: data['other_id']?.toString(),
          onBack: _back,
          onOptions: () => _options(chat, data),
        ),
        Expanded(
          child: ColoredBox(
            color: accents.chatWallpaper,
            // Reversed, so the newest message sits just above the composer.
            child: ListView(
              controller: _thread,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.sm,
                Space.sm,
                Space.sm,
              ),
              children: [
                if (active && inline) ...composer.reversed,
                ...thread.reversed,
              ],
            ),
          ),
        ),
        if (pinned)
          ColoredBox(
            color: accents.chatWallpaper,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 3,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  0,
                  Space.sm,
                  Space.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: composer,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _send(String chat) async {
    final api = ref.read(liveChatApiProvider), body = _text.text;
    if (body.trim().isEmpty && _photos.isEmpty) return;
    final signature = '$chat\n$body\n$_reply\n${_photos.join(',')}';
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
        if (_photos.isNotEmpty) 'attachments': List<String>.of(_photos),
        if (_reply != null) 'reply_to_id': _reply,
      });
      return true;
    });
    if (!mounted) return;
    if (ok == true && identical(ref.read(liveChatApiProvider), api)) {
      _text.clear();
      _photos.clear();
      _retryKey = null;
      _retrySignature = null;
      _reply = null;
      _before = null;
    }
    setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveChatApiProvider, (_, _) {
      _text.clear();
      _photos.clear();
      _reply = null;
      _before = null;
      _offset = 0;
      _earlier.clear();
      _loadingMore = false;
      _retryKey = null;
      _retrySignature = null;
      _readMarked = null;
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
        // While a further page loads, keep showing the rows already here.
        loading: () => id == null && _earlier.isNotEmpty
            ? (contacts
                  ? _contactsList(_earlier, const {'has_more': false})
                  : _inbox(const {'has_more': false}, _earlier))
            : const CircleStatePanel(
                child: CircleSkeleton(
                  shape: CircleSkeletonShape.cards,
                  count: 3,
                  label: 'Loading chats',
                ),
              ),
        error: (_, _) => CircleStatePanel(
          child: Column(
            children: [
              if (id != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackButton(onPressed: _back),
                ),
              CircleEmpty(
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
            ],
          ),
        ),
        data: (data) {
          final items = ApiJson.list(data['items']).map(ApiJson.map).toList();
          if (_loadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loadingMore = false);
            });
          }
          if (contacts) return _contactsList([..._earlier, ...items], data);
          if (id == null) return _inbox(data, [..._earlier, ...items]);
          return _conversation(ApiJson.id(data['id']), data, items);
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
