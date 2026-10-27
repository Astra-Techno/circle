import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/domain/circle_workspace.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'event_detail.dart';
import 'event_visuals.dart';

/// E4: who answered, in Going / Maybe / Not going tabs, with the people
/// coming with them and their notes. Visible to the group's members only.
class EventAttendees extends ConsumerWidget {
  const EventAttendees({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => EventPage(
    child: WorkspaceView(
      builder: (workspace) {
        final event = workspace.event(id);
        if (event == null) return const EventUnavailable();
        final attendance = EventRules.attendance(event.rsvps);
        final theme = Theme.of(context);
        List<MapEntry<String, Rsvp>> answered(Attendance status) =>
            event.rsvps.entries
                .where((entry) => entry.value.status == status)
                .toList()
              ..sort(
                (a, b) => workspace
                    .nameOf(a.key)
                    .toLowerCase()
                    .compareTo(workspace.nameOf(b.key).toLowerCase()),
              );
        final counts = {
          Attendance.going: attendance.going,
          Attendance.maybe: attendance.maybe,
          Attendance.notGoing: attendance.notGoing,
        };
        return ReadingPane(
          child: DefaultTabController(
            length: Attendance.values.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md,
                    Space.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          event.title,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(attendanceLine(attendance)),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final status in Attendance.values)
                      Tab(text: '${status.label} (${counts[status]})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final status in Attendance.values)
                        _AttendeeList(
                          entries: answered(status),
                          nameOf: workspace.nameOf,
                          empty: switch (status) {
                            Attendance.going => 'Nobody has said Going yet.',
                            Attendance.maybe => 'Nobody has said Maybe yet.',
                            Attendance.notGoing =>
                              'Nobody has said Not going yet.',
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _AttendeeList extends StatelessWidget {
  const _AttendeeList({
    required this.entries,
    required this.nameOf,
    required this.empty,
  });
  final List<MapEntry<String, Rsvp>> entries;
  final String Function(String person) nameOf;
  final String empty;
  @override
  Widget build(BuildContext context) => ListView(
    padding: CircleInsets.form,
    children: [
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.lg),
          child: Text(empty),
        ),
      for (final entry in entries)
        CircleRow(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(
              person: entry.key,
              name: nameOf(entry.key),
              size: CircleAvatarSize.small,
            ),
            title: Text(nameOf(entry.key)),
            subtitle: _details(entry.value) == null
                ? null
                : Text(_details(entry.value)!),
          ),
        ),
    ],
  );

  static String? _details(Rsvp rsvp) {
    final parts = [
      if (rsvp.guests > 0)
        '+${rsvp.guests} ${rsvp.guests == 1 ? 'person' : 'people'} with them',
      if (rsvp.note != null) '“${rsvp.note}”',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
