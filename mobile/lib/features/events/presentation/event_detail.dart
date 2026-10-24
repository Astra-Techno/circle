import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../albums/presentation/event_album.dart';
import '../../groups/domain/group_tree.dart';
import '../../memories/presentation/memory_poll_card.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'event_visuals.dart';
import 'rsvp_control.dart';

/// Shown for unknown events and events in groups the viewer isn't in.
class EventUnavailable extends StatelessWidget {
  const EventUnavailable({super.key});
  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: CircleInsets.form,
      children: const [
        CircleEmpty(
          title: 'This event is unavailable',
          message:
              'It may belong to a group you’re not in. Events are shared with one exact group only.',
        ),
      ],
    ),
  );
}

enum _EventAction { edit, cancel, report }

/// E2: everything about one event, the viewer's RSVP, the attendee
/// summary and an attached date poll. Opening maps and adding to a
/// calendar need a real device, so the place and link can only be copied.
class CircleEventDetail extends ConsumerWidget {
  const CircleEventDetail({super.key, required this.id});
  final String id;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmCircleAction(
      context,
      title: 'Cancel this event?',
      message:
          'RSVPs close and everyone sees it as cancelled. In the real app, people who answered would be told; in this preview nobody is notified. This can’t be undone.',
      confirm: 'Cancel event',
      dismiss: 'Keep event',
    );
    if (!confirmed || !context.mounted) return;
    await runCalmly(
      context,
      () => ref.read(circleWorkspaceProvider.notifier).cancelEvent(id),
      success: 'Event cancelled.',
    );
  }

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    showCircleMessage(context, '$what copied.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => EventPage(
    child: WorkspaceView(
      builder: (workspace) {
        final event = workspace.event(id);
        if (event == null) return const EventUnavailable();
        final group = workspace.group(event.groupId)!;
        final viewer = workspace.viewer;
        final now = ref.watch(circleClockProvider)().toUtc();
        final theme = Theme.of(context);
        final manage = EventRules.canManage(
          event,
          viewer,
          isMember: true,
          isAdmin: group.roles[viewer]?.isAdmin ?? false,
          now: now,
        ).allowed;
        final respond = EventRules.canRespond(event, isMember: true, now: now);
        final attendance = EventRules.attendance(event.rsvps);
        final today = eventToday(event, now);
        final end = event.endsAt;
        final left = EventRules.placesLeft(event);
        final controller = ref.read(circleWorkspaceProvider.notifier);
        final poll = event.datePoll;
        final hidden = workspace.isHidden(ReportKind.event, event.id);
        final report = ReportTarget.event(event.id, groupId: event.groupId);
        final canReport =
            event.createdBy != viewer &&
            !hidden &&
            !workspace.reported(ReportKind.event, event.id);
        Widget info(
          IconData icon,
          String title, {
          String? subtitle,
          Widget? trailing,
        }) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing,
        );
        return ReadingPane(
          child: SingleChildScrollView(
            padding: CircleInsets.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PreviewLabel(
                  'Preview: RSVPs stay on this device and nobody is notified.',
                ),
                if (hidden) ...[
                  HiddenByAdminsNotice(
                    groupId: event.groupId,
                    target: report,
                    what: 'event',
                  ),
                  const SizedBox(height: Space.md),
                ],
                SizedBox(
                  height: 140,
                  child: CircleSceneTile(
                    label: event.type.label,
                    icon: eventTypeIcon(event.type),
                    semanticsLabel:
                        'Fictional illustration for a ${event.type.label.toLowerCase()} event',
                  ),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          event.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    if (manage || canReport)
                      PopupMenuButton<_EventAction>(
                        tooltip: manage
                            ? 'Event options'
                            : 'More options for this event',
                        onSelected: (action) => switch (action) {
                          _EventAction.edit => context.push(
                            '/events/e/${event.id}/edit',
                          ),
                          _EventAction.cancel => _cancel(context, ref),
                          _EventAction.report => reportToAdmins(
                            context,
                            ref,
                            target: report,
                            what: 'this event',
                          ),
                        },
                        itemBuilder: (_) => [
                          if (manage) ...const [
                            PopupMenuItem(
                              value: _EventAction.edit,
                              child: Text('Edit event'),
                            ),
                            PopupMenuItem(
                              value: _EventAction.cancel,
                              child: Text('Cancel event'),
                            ),
                          ],
                          if (canReport)
                            const PopupMenuItem(
                              value: _EventAction.report,
                              child: Text('Report'),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    if (event.cancelled)
                      const CirclePill(
                        'Cancelled',
                        icon: Icons.event_busy_outlined,
                        tone: CircleTone.strong,
                      ),
                    CirclePill(
                      event.type.label,
                      icon: eventTypeIcon(event.type),
                    ),
                    CirclePill(
                      audiencePath(group, workspace.groupsById),
                      icon: Icons.lock_outline,
                      tone: circleTypeTone(group.type),
                      semanticsLabel: 'For ${group.name} only',
                    ),
                    if (event.edited) const CirclePill('Edited'),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (event.cancelled)
                  const EventNotice(
                    icon: Icons.event_busy_outlined,
                    text: 'This event was cancelled. RSVPs are closed.',
                  )
                else if (EventRules.hasEnded(event, now))
                  const EventNotice(
                    icon: Icons.history,
                    text: 'This event has ended.',
                  )
                else if (!respond.allowed)
                  EventNotice(
                    icon: Icons.lock_clock_outlined,
                    text: respond.reason!,
                  ),
                info(
                  Icons.schedule,
                  eventWhenLabel(event, now),
                  subtitle: end == null
                      ? null
                      : formatDuration(end.difference(event.startsAt)),
                ),
                if (event.hosts.isNotEmpty)
                  info(
                    Icons.person_outline,
                    'Hosted by ${joinNames([for (final host in event.hosts) workspace.nameOf(host)])}',
                  ),
                if (event.venue != null)
                  info(
                    Icons.place_outlined,
                    event.venue!,
                    trailing: IconButton(
                      tooltip: 'Copy place',
                      icon: const Icon(Icons.content_copy_outlined),
                      onPressed: () => _copy(context, event.venue!, 'Place'),
                    ),
                  ),
                if (event.onlineLink != null)
                  info(
                    Icons.videocam_outlined,
                    event.onlineLink!,
                    subtitle: 'Copy it into your video app.',
                    trailing: IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.content_copy_outlined),
                      onPressed: () =>
                          _copy(context, event.onlineLink!, 'Link'),
                    ),
                  ),
                if (event.rsvpDeadline != null)
                  info(
                    Icons.event_available_outlined,
                    'RSVP by ${EventRules.slotLabel(event.rsvpDeadline!, offset: event.utcOffset, zone: event.timeZoneLabel, today: today)}',
                  ),
                if (event.capacity != null)
                  info(
                    Icons.event_seat_outlined,
                    'Room for ${event.capacity} '
                    '${event.capacity == 1 ? 'person' : 'people'}',
                    subtitle: left == 0
                        ? 'Full — you can still answer Maybe.'
                        : '$left ${left == 1 ? 'place' : 'places'} left, counting guests',
                  ),
                if (event.description != null) ...[
                  const CircleSectionTitle('About'),
                  Text(event.description!),
                ],
                const CircleSectionTitle('Are you coming?'),
                RsvpControl(
                  key: ValueKey('rsvp-${event.id}'),
                  event: event,
                  viewer: viewer,
                  enabled: respond.allowed,
                ),
                const CircleSectionTitle('Who’s coming?'),
                Semantics(
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Going ${attendance.going} · Maybe ${attendance.maybe} · '
                        'Not going ${attendance.notGoing}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${attendance.expected} '
                        '${attendance.expected == 1 ? 'person' : 'people'} '
                        'expected, including guests',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/events/e/${event.id}/attendees'),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('See attendees'),
                  ),
                ),
                EventAlbumSection(event: event),
                if (poll != null) ...[
                  const CircleSectionTitle('Date poll'),
                  PollCard(
                    poll: poll,
                    onVote: (choices) => controller.voteEventPoll(id, choices),
                    onRetract: () => controller.retractEventPollVote(id),
                    onClose: () => controller.closeEventPoll(id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
