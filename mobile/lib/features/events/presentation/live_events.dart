import '../../../core/form_exit_guard.dart';
import '../../../core/viewport_load.dart';
import '../../profile/application/profile_providers.dart'
    show profilePhotoPickerProvider;
import '../../../core/private_photo.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import 'event_visuals.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../notifications/application/push_settings.dart'
    show deviceTimezoneProvider;
import '../application/live_events.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

void refreshLiveEvents(WidgetRef ref) {
  ref.invalidate(liveEventsProvider);
  ref.invalidate(liveEventProvider);
  ref.invalidate(liveAttendeesProvider);
}

class LiveEventsScreen extends ConsumerStatefulWidget {
  const LiveEventsScreen({super.key, this.id, this.group});
  final String? id, group;
  @override
  ConsumerState<LiveEventsScreen> createState() => _LiveEventsState();
}

class _LiveEventsState extends ConsumerState<LiveEventsScreen> {
  int _offset = 0;
  bool _busy = false;

  /// Events from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];

  String _filter = 'All';
  bool _loadingMore = false;

  void _more(Map<String, Object?> page) {
    if (_loadingMore || page['has_more'] != true) return;
    setState(() {
      _earlier.addAll(ApiJson.list(page['items']).map(ApiJson.map));
      _offset += 30;
      _loadingMore = true;
    });
  }

  @override
  void didUpdateWidget(covariant LiveEventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group != widget.group || oldWidget.id != widget.id) {
      _offset = 0;
      _earlier.clear();
      _loadingMore = false;
      _filter = 'All';
    }
  }

  Widget _eventList(List<Map<String, Object?>> items, {Widget? end}) {
    final now = DateTime.now().toUtc();
    bool upcoming(Map<String, Object?> item) =>
        DateTime.parse(item['start_at'] as String).isAfter(now);
    final visible =
        items
            .where(
              (item) =>
                  _filter == 'All' ||
                  (_filter == 'Upcoming' ? upcoming(item) : !upcoming(item)),
            )
            .toList()
          ..sort((a, b) {
            final futureA = upcoming(a), futureB = upcoming(b);
            if (futureA != futureB) return futureA ? -1 : 1;
            final compare = DateTime.parse(
              a['start_at'] as String,
            ).compareTo(DateTime.parse(b['start_at'] as String));
            return futureA ? compare : -compare;
          });
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _offset = 0;
          _earlier.clear();
          _loadingMore = false;
        });
        refreshLiveEvents(ref);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const CircleCollapsingHeader(),
          SliverPadding(
            padding: CircleInsets.rootPage,
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final filter in ['All', 'Upcoming', 'Past'])
                        ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                ),
                if (visible.isEmpty)
                  CircleEmpty(
                    icon: LucideIcons.calendar_days,
                    title: items.isEmpty
                        ? 'Something to look forward to'
                        : 'No ${_filter.toLowerCase()} events loaded',
                    message: items.isEmpty
                        ? 'Plan the first event for one of your circles.'
                        : 'Choose All or load more events to keep looking.',
                    action: items.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => setState(() => _filter = 'All'),
                            child: const Text('Show all events'),
                          ),
                  ),
                for (final (i, item) in visible.indexed) ...[
                  if (i == 0 || upcoming(visible[i - 1]) != upcoming(item))
                    CircleSectionTitle(
                      upcoming(item) ? 'Upcoming' : 'Past events',
                    ),
                  CircleFadeIn(
                    delay: CircleMotion.staggerDelay * i.clamp(0, 5),
                    child: LiveEventCard(
                      item: item,
                      onTap: () => context.go('/events/e/${item['id']}'),
                    ),
                  ),
                ],
                ?end,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveEventsApiProvider, (_, _) {
      _offset = 0;
      _earlier.clear();
      _loadingMore = false;
    });
    final id = widget.id;
    final load = id == null
        ? ref.watch(liveEventsProvider((offset: _offset, group: widget.group)))
        : ref.watch(liveEventProvider(id));
    return ReadingPane(
      child: load.when(
        skipLoadingOnRefresh: true,
        loading: () => id == null && _earlier.isNotEmpty
            ? _eventList(
                _earlier,
                end: const Padding(
                  padding: EdgeInsets.all(Space.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            : const CircleStatePanel(
                child: CircleSkeleton(
                  shape: CircleSkeletonShape.cards,
                  count: 3,
                  label: 'Loading events',
                ),
              ),
        error: (_, _) => CircleStatePanel(
          child: CircleEmpty(
            icon: LucideIcons.wifi_off,
            title: 'Events couldn’t load',
            message: 'Check your connection and group access.',
            action: TextButton(
              onPressed: () => refreshLiveEvents(ref),
              child: const Text('Try again'),
            ),
          ),
        ),
        data: (e) {
          if (id == null) {
            final items = ApiJson.list(e['items']).map(ApiJson.map).toList();
            if (_loadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loadingMore = false);
              });
            }
            return _eventList(
              [..._earlier, ...items],
              end: e['has_more'] == true
                  ? Column(
                      children: [
                        const CircleNote(
                          'Showing loaded events. Load more to include the rest in these date groups.',
                        ),
                        if (_filter == 'All')
                          CircleLoadMore(
                            key: ValueKey('more-$_offset'),
                            onLoad: () => _more(e),
                          )
                        else
                          TextButton(
                            onPressed: _loadingMore ? null : () => _more(e),
                            child: Text(
                              _loadingMore
                                  ? 'Loading events…'
                                  : 'Load more events',
                            ),
                          ),
                      ],
                    )
                  : null,
            );
          }
          final mine = e['my_rsvp'],
              active = e['status'] == 'active',
              manage = e['can_manage'] == true;
          final canRsvp =
              active &&
              DateTime.parse(
                e['start_at'] as String,
              ).isAfter(DateTime.now().toUtc());
          final chosen = mine is Map ? mine['status'] : null;
          Widget choiceButton(MapEntry<String, String> choice) {
            // One line that shrinks rather than wrapping a word.
            final label = FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(choice.value, maxLines: 1, softWrap: false),
            );
            return chosen == choice.key
                ? FilledButton(onPressed: null, child: label)
                : OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final api = ref.read(liveEventsApiProvider);
                            setState(() => _busy = true);
                            await runCalmly(
                              context,
                              () => api.rsvp(
                                id,
                                choice.key,
                                choice.key == 'going' && mine is Map
                                    ? (mine['guest_count'] as int? ?? 0)
                                    : 0,
                                mine is Map
                                    ? (mine['note'] as String? ?? '')
                                    : '',
                              ),
                              success: 'RSVP saved.',
                            );
                            if (mounted) {
                              setState(() => _busy = false);
                              refreshLiveEvents(ref);
                              ref.invalidate(memoryTimelineProvider);
                              if (context.mounted) {
                                await runCalmly(
                                  context,
                                  () => ref
                                      .read(circleWorkspaceProvider.notifier)
                                      .refresh(),
                                );
                              }
                            }
                          },
                    child: label,
                  );
          }

          final theme = Theme.of(context);
          final caption = theme.textTheme.bodySmall?.copyWith(
            color: CircleAccents.of(context).caption,
          );
          final zone = e['timezone'] as String;
          final venue = e['venue'] as String? ?? '';
          final link = e['online_link'] as String? ?? '';
          Future<void> busy(Future<void> Function() work) async {
            setState(() => _busy = true);
            await work();
            if (!mounted) return;
            setState(() => _busy = false);
            refreshLiveEvents(ref);
            ref.invalidate(memoryTimelineProvider);
            if (context.mounted) {
              await runCalmly(
                context,
                () => ref.read(circleWorkspaceProvider.notifier).refresh(),
              );
            }
          }

          Future<void> manageAction(String action) async {
            final api = ref.read(liveEventsApiProvider);
            final version = e['version'] as int;
            switch (action) {
              case 'cover':
                final picker = ref.read(profilePhotoPickerProvider);
                await busy(
                  () =>
                      runCalmly(context, () => api.cover(id, version, picker)),
                );
              case 'remove-cover':
                await busy(
                  () => runCalmly(context, () => api.removeCover(id, version)),
                );
              case 'edit':
                context.go('/events/e/$id/edit');
              case 'cancel':
                if (!await confirmCircleAction(
                  context,
                  title: 'Cancel this event?',
                  message:
                      'The group will see the cancellation. Existing RSVPs stay on record.',
                  confirm: 'Cancel event',
                )) {
                  return;
                }
                if (!context.mounted) return;
                await busy(
                  () => runCalmly(
                    context,
                    () => api.update(id, {
                      'version': version,
                      'status': 'cancelled',
                    }),
                    success: 'Event cancelled.',
                  ),
                );
            }
          }

          Widget row(
            IconData icon,
            String title, {
            String? subtitle,
            VoidCallback? onTap,
          }) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: onTap == null
                ? null
                : const Icon(CircleIcons.chevronRight),
            onTap: onTap,
          );
          final going = (e['going_count'] as num?)?.toInt() ?? 0;
          final details = RefreshIndicator(
            onRefresh: () async => refreshLiveEvents(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: CircleInsets.form,
              children: [
                if (e['cover_id'] case final String cover)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(CircleRadius.card),
                      child: PrivatePhoto(
                        load: ref.watch(
                          liveEventCoverProvider((event: id, cover: cover)),
                        ),
                        label: 'Event cover',
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EventDateBlock(
                      wall: liveEventWall(e['start_at'] as String, zone),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          e['title'] as String,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (manage && active)
                      PopupMenuButton<String>(
                        tooltip: 'Event options',
                        enabled: !_busy,
                        onSelected: manageAction,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'cover',
                            child: Text(
                              e['cover_id'] == null
                                  ? 'Add cover photo'
                                  : 'Change cover photo',
                            ),
                          ),
                          if (e['cover_id'] != null)
                            const PopupMenuItem(
                              value: 'remove-cover',
                              child: Text('Remove cover'),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit event'),
                          ),
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel event'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                if (!active)
                  const EventNotice(
                    icon: LucideIcons.calendar_x,
                    text: 'This event is cancelled.',
                  ),
                row(
                  LucideIcons.clock,
                  liveEventLabel(e),
                  subtitle: e['end_at'] == null
                      ? null
                      : 'Ends ${formatDay(liveEventWall(e['end_at'] as String, zone), today: DateTime.now())} · ${formatTime(liveEventWall(e['end_at'] as String, zone))}',
                ),
                if (venue.isNotEmpty) row(LucideIcons.map_pin, venue),
                if (link.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.link),
                    title: SelectableText(link),
                  ),
                if (e['rsvp_deadline'] != null)
                  row(
                    LucideIcons.calendar_check,
                    'RSVP by ${formatDay(liveEventWall(e['rsvp_deadline'] as String, zone), today: DateTime.now())} · ${formatTime(liveEventWall(e['rsvp_deadline'] as String, zone))}',
                  ),
                row(
                  LucideIcons.users,
                  'Who’s coming?',
                  subtitle:
                      '$going going${e['max_capacity'] == null ? '' : ' · room for ${e['max_capacity']}'}',
                  onTap: () => context.go('/events/e/$id/attendees'),
                ),
                row(
                  LucideIcons.chart_bar,
                  'Event polls',
                  onTap: () =>
                      context.push('/polls?group=${e['group_id']}&event=$id'),
                ),
                if (canRsvp && mine is Map)
                  row(
                    LucideIcons.pencil,
                    'Guests and RSVP note',
                    onTap: _busy
                        ? null
                        : () {
                            final api = ref.read(liveEventsApiProvider);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _RsvpSheet(
                                api: api,
                                id: id,
                                mine: Map<String, Object?>.from(mine),
                              ),
                            );
                          },
                  ),
                if ((e['description'] as String? ?? '').isNotEmpty) ...[
                  const CircleSectionTitle('About'),
                  Text(
                    e['description'] as String,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (!canRsvp)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: Text(
                      mine is Map
                          ? 'Your RSVP: ${_answerLabel(mine['status'])}'
                          : 'You haven’t replied yet.',
                      style: caption,
                    ),
                  ),
              ],
            ),
          );
          // Answers sit in the thumb zone, pinned below the details.
          return Column(
            children: [
              Expanded(child: details),
              if (canRsvp)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: CircleAccents.of(context).hairline,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.section,
                      Space.md,
                      Space.section,
                      Space.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chosen == null
                              ? 'Are you coming?'
                              : 'Your answer: ${_answerLabel(chosen)}',
                          style: CircleTextStyles.metadata(
                            CircleAccents.of(context).caption,
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            for (final (index, choice) in {
                              'going': 'Going',
                              'maybe': 'Maybe',
                              'not_going': 'Can’t go',
                            }.entries.indexed) ...[
                              if (index > 0) const SizedBox(width: Space.sm),
                              Expanded(child: choiceButton(choice)),
                            ],
                          ],
                        ),
                      ],
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

/// One upcoming event in the live list: optional cover, the date badge,
/// title and when/where, like the preview cards.
/// Shared event invitation, used by the Events list and every Memory timeline.
class LiveEventCard extends ConsumerWidget {
  const LiveEventCard({super.key, required this.item, required this.onTap});
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final caption = CircleAccents.of(context).caption;
    final cancelled = item['status'] == 'cancelled';
    final groupName =
        item['group_name'] as String? ??
        ref
            .watch(circleWorkspaceProvider)
            .value
            ?.group('${item['group_id']}')
            ?.name ??
        '';
    final wall = liveEventWall(
      item['start_at'] as String,
      item['timezone'] as String,
    );
    final going = (item['going_count'] as num?)?.toInt();
    final maybe = (item['maybe_count'] as num?)?.toInt();
    Widget info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: CircleSizes.iconInline, color: caption),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(text, style: CircleTextStyles.body(colors.onSurface)),
          ),
        ],
      ),
    );
    return CircleSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CircleRadius.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item['cover_id'] case final String cover)
                AspectRatio(
                  aspectRatio: CircleProfileLayout.coverAspectRatio,
                  child: CircleViewportLoad(
                    placeholder: ColoredBox(
                      color: CircleAccents.of(context).recessed,
                    ),
                    builder: (_) => Consumer(
                      builder: (context, ref, _) => PrivatePhoto(
                        load: ref.watch(
                          liveEventCoverProvider((
                            event: '${item['id']}',
                            cover: cover,
                          )),
                        ),
                        label: 'Event cover',
                      ),
                    ),
                  ),
                ),
              ColoredBox(
                color: colors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Builder(
                    builder: (context) {
                      final badge = Container(
                        padding: const EdgeInsets.all(Space.sm),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(
                            CircleRadius.tile,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              MaterialLocalizations.of(context)
                                  .formatMonthYear(wall)
                                  .split(' ')
                                  .first
                                  .characters
                                  .take(3)
                                  .toString()
                                  .toUpperCase(),
                              style: CircleTextStyles.homeShortcut(
                                colors.primary,
                              ),
                            ),
                            Text(
                              '${wall.day}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: colors.primary),
                            ),
                          ],
                        ),
                      );
                      final group = Text(
                        groupName,
                        style: CircleTextStyles.homeShortcut(caption),
                      );
                      final title = Text(
                        item['title'] as String,
                        style: CircleTextStyles.sectionTitle(colors.onSurface),
                      );
                      if (CircleLayout.stackDetails(
                        context,
                        MediaQuery.sizeOf(context).width,
                      )) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                badge,
                                const SizedBox(width: Space.md),
                                Expanded(child: group),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            title,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          badge,
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                group,
                                const SizedBox(height: Space.xs),
                                title,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cancelled)
                      Text(
                        'Cancelled',
                        style: CircleTextStyles.homeShortcut(colors.error),
                      ),
                    info(LucideIcons.clock, liveEventLabel(item)),
                    if ((item['venue'] as String? ?? '').isNotEmpty)
                      info(LucideIcons.map_pin, item['venue'] as String),
                    if ((item['venue'] as String? ?? '').isEmpty &&
                        (item['online_link'] as String? ?? '').isNotEmpty)
                      info(LucideIcons.video, 'Online event'),
                    const Divider(),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.sm,
                      children: [
                        if (going != null || maybe != null)
                          Text(
                            [
                              if (going != null) '$going going',
                              if (maybe != null) '$maybe maybe',
                            ].join(' · '),
                            style: CircleTextStyles.homeShortcut(caption),
                          ),
                        FilledButton(
                          onPressed: onTap,
                          child: const Text('View event'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveEventForm extends ConsumerWidget {
  const LiveEventForm({super.key, this.id, this.group});
  final String? id, group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(liveEventsApiProvider);
    if (id == null) {
      return _EventEditor(
        key: ValueKey('${api.scope.account}-${api.scope.session}'),
        group: group,
        api: api,
      );
    }
    return ref
        .watch(liveEventProvider(id!))
        .when(
          loading: () => const CircleSkeletonPage(label: 'Loading event'),
          error: (_, _) => CircleEmpty(
            icon: LucideIcons.wifi_off,
            title: 'Event couldn’t load',
            message: 'Refresh and try again.',
            action: TextButton(
              onPressed: () => ref.invalidate(liveEventProvider(id!)),
              child: const Text('Try again'),
            ),
          ),
          data: (e) => e['can_manage'] == true && e['status'] == 'active'
              ? _EventEditor(
                  key: ValueKey(
                    '${api.scope.account}-${api.scope.session}-$id-${e['version']}',
                  ),
                  id: id,
                  saved: e,
                  api: api,
                )
              : const CircleEmpty(
                  icon: LucideIcons.lock_keyhole,
                  title: 'Editing unavailable',
                  message:
                      'Only the organizer or current group admins can edit.',
                ),
        );
  }
}

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({
    super.key,
    this.id,
    this.group,
    this.saved,
    required this.api,
  });
  final String? id, group;
  final Map<String, Object?>? saved;
  final LiveEventsApi api;
  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  bool _submitted = false;
  final _requiredFields = GlobalKey();
  final _titleFocus = FocusNode();
  final _edits = FormExitController();
  final _title = TextEditingController(),
      _venue = TextEditingController(),
      _description = TextEditingController(),
      _link = TextEditingController(),
      _capacity = TextEditingController();
  String _zone = 'UTC', _type = 'other';
  String? _group, _key, _signature;
  DateTime? _start, _end, _deadline;
  bool _busy = false, _zoneTouched = false;
  @override
  void initState() {
    super.initState();
    final e = widget.saved;
    _group = widget.group;
    if (e != null) {
      _group = ApiJson.id(e['group_id']);
      _zone = e['timezone'] as String;
      _type = e['event_type'] as String;
      _title.text = e['title'] as String;
      _venue.text = e['venue'] as String? ?? '';
      _description.text = e['description'] as String? ?? '';
      _link.text = e['online_link'] as String? ?? '';
      _capacity.text = e['max_capacity']?.toString() ?? '';
      _start = liveEventWall(e['start_at'] as String, _zone);
      if (e['end_at'] != null) {
        _end = liveEventWall(e['end_at'] as String, _zone);
      }
      if (e['rsvp_deadline'] != null) {
        _deadline = liveEventWall(e['rsvp_deadline'] as String, _zone);
      }
    } else {
      Future.microtask(() async {
        final zone = await ref.read(deviceTimezoneProvider).read();
        if (mounted &&
            !_zoneTouched &&
            zone != null &&
            liveEventZones().contains(zone)) {
          setState(() => _zone = zone);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    for (final c in [_title, _venue, _description, _link, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final d = initial ?? DateTime.now().add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime(d.year, d.month, d.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2037, 12, 31),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: d.hour, minute: d.minute),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final groups =
        workspace?.groups
            .where(
              (g) =>
                  g.isMember(workspace.viewer) &&
                  (g.roles[workspace.viewer]?.isAdmin == true ||
                      g.settings.eventCreation == EventCreationPolicy.members),
            )
            .toList() ??
        [];
    final selected = groups.any((g) => g.id == _group)
        ? _group
        : groups.length == 1
        ? groups.single.id
        : null;
    Widget date(
      String label,
      DateTime? value,
      void Function(DateTime?) save, {
      bool optional = false,
    }) => Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(CircleRadius.input),
      child: ListTile(
        leading: const Icon(LucideIcons.calendar),
        contentPadding: CircleInsets.content,
        title: Text(label),
        subtitle: Text(
          value == null
              ? 'Choose date and time · $_zone'
              : '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))} · $_zone',
        ),
        trailing: optional
            ? IconButton(
                onPressed: _busy ? null : () => setState(() => save(null)),
                icon: const Icon(CircleIcons.close),
                tooltip: 'Clear $label',
              )
            : const Icon(LucideIcons.calendar),
        onTap: _busy
            ? null
            : () async {
                final d = await _pick(value);
                if (d != null && mounted) setState(() => save(d));
              },
      ),
    );
    Widget startPart({required bool time}) {
      final base =
          _start ??
          liveEventWall(
            DateTime.now()
                .toUtc()
                .add(const Duration(days: 1))
                .toIso8601String(),
            _zone,
          );
      return Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(CircleRadius.input),
        child: ListTile(
          leading: Icon(time ? LucideIcons.clock : LucideIcons.calendar),
          title: Text(time ? 'Time' : 'Date'),
          subtitle: Text(
            _start == null
                ? (time ? 'Choose a date first' : 'Choose date')
                : time
                ? MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(base))
                : MaterialLocalizations.of(context).formatMediumDate(base),
          ),
          trailing: const Icon(LucideIcons.chevron_down),
          enabled: !_busy && (!time || _start != null),
          onTap: _busy || (time && _start == null)
              ? null
              : () async {
                  if (time) {
                    final chosen = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(base),
                    );
                    if (chosen != null && mounted) {
                      setState(
                        () => _start = DateTime(
                          base.year,
                          base.month,
                          base.day,
                          chosen.hour,
                          chosen.minute,
                        ),
                      );
                    }
                  } else {
                    final chosen = await showDatePicker(
                      context: context,
                      initialDate: DateTime(base.year, base.month, base.day),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2037, 12, 31),
                    );
                    if (chosen != null && mounted) {
                      setState(
                        () => _start = DateTime(
                          chosen.year,
                          chosen.month,
                          chosen.day,
                          base.hour,
                          base.minute,
                        ),
                      );
                    }
                  }
                },
        ),
      );
    }

    return UnsavedForm(
      controller: _edits,
      fields: [_title, _venue, _description, _link, _capacity],
      fingerprint: () => jsonEncode([
        _title.text,
        _venue.text,
        _description.text,
        _link.text,
        _capacity.text,
        _group,
        _type,
        _zoneTouched ? _zone : null,
        _start?.toIso8601String(),
        _end?.toIso8601String(),
        _deadline?.toIso8601String(),
      ]),
      child: ReadingPane(
        child: CircleEditorLayout(
          children: [
            Text(
              widget.id == null ? 'Plan an event' : 'Edit event',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.id == null)
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                itemHeight: null,
                key: _requiredFields,
                decoration: InputDecoration(
                  labelText: 'Circle',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                  errorText: _submitted && selected == null
                      ? 'Choose a Circle.'
                      : null,
                ),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _group = v),
              ),
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              onChanged: (_) {
                if (_submitted) setState(() {});
              },
              enabled: !_busy,
              buildCounter: CircleFormMetrics.counter,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Event title',
                filled: true,
                fillColor: Theme.of(context).colorScheme.primaryContainer,
                errorText: _submitted && _title.text.trim().isEmpty
                    ? 'Enter an event title.'
                    : null,
              ),
            ),
            Text(
              'When',
              style: CircleTextStyles.sectionTitle(
                Theme.of(context).colorScheme.onSurface,
              ),
            ),
            startPart(time: false),
            startPart(time: true),
            Text(
              _zone,
              style: CircleTextStyles.homeShortcut(
                CircleAccents.of(context).caption,
              ),
            ),
            if (_submitted && _start == null)
              const Text('Choose a start date and time.'),
            Text(
              'Where',
              style: CircleTextStyles.sectionTitle(
                Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextField(
              controller: _venue,
              enabled: !_busy,
              buildCounter: CircleFormMetrics.counter,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Place',
                prefixIcon: const Icon(LucideIcons.map_pin),
                filled: true,
                fillColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            ExpansionTile(
              title: const Text('More options'),
              subtitle: const Text('Description, end time and more'),
              children: [
                TextField(
                  controller: _description,
                  enabled: !_busy,
                  buildCounter: CircleFormMetrics.counter,
                  maxLength: 10000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: _link,
                  enabled: !_busy,
                  buildCounter: CircleFormMetrics.counter,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Meeting link',
                    helperText:
                        'Optional HTTPS URL. Use instead of a place for online events.',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: [
                    for (final type in [
                      'function',
                      'wedding',
                      'reunion',
                      'meetup',
                      'birthday',
                      'trip',
                      'online',
                      'other',
                    ])
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _type = v!),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(_zone),
                  initialValue: _zone,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Event time zone',
                  ),
                  items: [
                    for (final zone in liveEventZones())
                      DropdownMenuItem(value: zone, child: Text(zone)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _zoneTouched = true;
                          _zone = v!;
                        }),
                ),
                date('End', _end, (v) => _end = v, optional: true),
                date(
                  'RSVP deadline',
                  _deadline,
                  (v) => _deadline = v,
                  optional: true,
                ),
                TextField(
                  controller: _capacity,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    helperText: 'Optional. Includes guests.',
                  ),
                ),
              ],
            ),
            if (selected != null)
              Text(
                'Shared only with ${groups.firstWhere((g) => g.id == selected).name}',
                style: CircleTextStyles.homeShortcut(
                  CircleAccents.of(context).caption,
                ),
              ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (selected == null ||
                          _start == null ||
                          _title.text.trim().isEmpty) {
                        setState(() => _submitted = true);
                        if (_title.text.trim().isEmpty) {
                          _titleFocus.requestFocus();
                        }
                        final target = _requiredFields.currentContext;
                        if (target != null) {
                          await Scrollable.ensureVisible(target);
                        }
                        return;
                      }
                      setState(() => _busy = true);
                      final result = await runCalmly(context, () async {
                        final capacity = _capacity.text.trim().isEmpty
                            ? null
                            : int.tryParse(_capacity.text.trim());
                        if (_capacity.text.trim().isNotEmpty &&
                            capacity == null) {
                          throw const CircleFailure(
                            'Capacity must be a whole number.',
                          );
                        }
                        final body = <String, Object?>{
                          'title': _title.text.trim(),
                          'description': _description.text.trim(),
                          'event_type': _type,
                          'venue': _venue.text.trim(),
                          'online_link': _link.text.trim(),
                          'timezone': _zone,
                          'start_at': liveEventInstant(_start!, _zone),
                          'end_at': _end == null
                              ? null
                              : liveEventInstant(_end!, _zone),
                          'rsvp_deadline': _deadline == null
                              ? null
                              : liveEventInstant(_deadline!, _zone),
                          'max_capacity': capacity,
                        };
                        if (widget.id != null) {
                          await widget.api.update(widget.id!, {
                            ...body,
                            'version': widget.saved!['version'],
                          });
                          return widget.id!;
                        }
                        final signature = jsonEncode([selected, body]);
                        if (signature != _signature) {
                          _signature = signature;
                          _key =
                              'event-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
                        }
                        return ApiJson.id(
                          (await widget.api.create(selected, {
                            ...body,
                            'client_id': _key,
                          }))['id'],
                        );
                      });
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (result != null) {
                        _edits.commit();
                        refreshLiveEvents(ref);
                        ref.invalidate(memoryTimelineProvider);
                        await runCalmly(
                          context,
                          () => ref
                              .read(circleWorkspaceProvider.notifier)
                              .refresh(),
                        );
                        if (!context.mounted) return;
                        context.go('/events/e/$result');
                      }
                    },
              child: Text(
                _busy
                    ? 'Saving…'
                    : widget.id == null
                    ? 'Create event'
                    : 'Save event',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpSheet extends ConsumerStatefulWidget {
  const _RsvpSheet({required this.api, required this.id, required this.mine});
  final LiveEventsApi api;
  final String id;
  final Map<String, Object?> mine;
  @override
  ConsumerState<_RsvpSheet> createState() => _RsvpState();
}

class _RsvpState extends ConsumerState<_RsvpSheet> {
  late final TextEditingController _note;
  late int _guests;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.mine['note'] as String? ?? '');
    _guests = widget.mine['guest_count'] as int? ?? 0;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ListView(
      shrinkWrap: true,
      padding: CircleInsets.form,
      children: [
        const CircleHeading(
          title: 'Guests and note',
          subtitle: 'Saving sets your RSVP to Going.',
        ),
        DropdownButtonFormField<int>(
          initialValue: _guests,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Guests'),
          items: [
            for (var i = 0; i <= 10; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: _busy ? null : (v) => setState(() => _guests = v!),
        ),
        TextField(
          controller: _note,
          enabled: !_busy,
          buildCounter: CircleFormMetrics.counter,
          maxLength: 500,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private note',
            helperText: 'Only you can view this note.',
          ),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await runCalmly(context, () async {
                    await widget.api.rsvp(
                      widget.id,
                      'going',
                      _guests,
                      _note.text,
                    );
                    return true;
                  }, success: 'RSVP saved.');
                  if (!context.mounted) return;
                  if (ok == true) {
                    refreshLiveEvents(ref);
                    ref.invalidate(memoryTimelineProvider);
                    await runCalmly(
                      context,
                      () =>
                          ref.read(circleWorkspaceProvider.notifier).refresh(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } else {
                    setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Saving…' : 'Save RSVP'),
        ),
      ],
    ),
  );
}

class LiveAttendeesScreen extends ConsumerStatefulWidget {
  const LiveAttendeesScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LiveAttendeesScreen> createState() => _AttendeesState();
}

class _AttendeesState extends ConsumerState<LiveAttendeesScreen> {
  int _offset = 0;

  /// People from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];

  Widget _list(List<Map<String, Object?>> people, {Widget? end}) => ListView(
    padding: CircleInsets.form,
    children: [
      const CircleHeading(
        title: 'Who’s coming?',
        subtitle: 'Notes and mobile numbers stay private.',
      ),
      if (people.isEmpty)
        const CircleEmpty(
          icon: LucideIcons.calendar_days,
          title: 'No answers yet',
          message:
              'When people answer Going, Maybe or Can’t go, they show up here.',
        ),
      for (final person in people)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleInitialAvatar(name: person['display_name'] as String),
          title: Text(person['display_name'] as String),
          subtitle: Text(
            [
              _answerLabel(person['status']),
              if (((person['guest_count'] as num?)?.toInt() ?? 0) > 0)
                '+${person['guest_count']} with them',
            ].join(' · '),
          ),
        ),
      ?end,
    ],
  );

  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ref
        .watch(liveAttendeesProvider((id: widget.id, offset: _offset)))
        .when(
          loading: () => _earlier.isNotEmpty
              ? _list(
                  _earlier,
                  end: const Padding(
                    padding: EdgeInsets.all(Space.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : const CircleSkeletonPage(label: 'Loading attendees'),
          error: (_, _) => CircleEmpty(
            icon: LucideIcons.wifi_off,
            title: 'Attendees couldn’t load',
            message: 'Check your connection and membership.',
            action: TextButton(
              onPressed: () => ref.invalidate(liveAttendeesProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (data) {
            final people = ApiJson.list(
              data['items'],
            ).map(ApiJson.map).toList();
            return _list(
              [..._earlier, ...people],
              end: data['has_more'] == true
                  ? CircleLoadMore(
                      key: ValueKey('more-$_offset'),
                      onLoad: () => setState(() {
                        _earlier.addAll(people);
                        _offset += 30;
                      }),
                    )
                  : null,
            );
          },
        ),
  );
}

/// "Going", "Maybe" or "Can’t go" for a saved RSVP status.
String _answerLabel(Object? status) => switch (status) {
  'going' => 'Going',
  'maybe' => 'Maybe',
  'not_going' => 'Can’t go',
  _ => '$status',
};
