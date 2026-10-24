import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The group chosen in the Events filter; null means all circles. The
/// shell uses it so "New event" opens with that group in view.
final eventsGroupFilterProvider = NotifierProvider<EventsGroupFilter, String?>(
  EventsGroupFilter.new,
);

class EventsGroupFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? groupId) => state = groupId;
}

/// Create-event location with the group in view, if any.
String eventCreateLocation(String? groupId) => groupId == null
    ? '/events/new'
    : Uri(path: '/events/new', queryParameters: {'group': groupId}).toString();
