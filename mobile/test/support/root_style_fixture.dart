import '../live_chat_events_test.dart' show LiveFixture;

/// Populated, fictional data shared by the root-page design captures.
class RootStyleFixture extends LiveFixture {
  RootStyleFixture() {
    messages.add({
      'id': 1,
      'author_id': member,
      'display_name': 'Fictional Member',
      'body': 'Looking forward to seeing everyone this weekend.',
      'created_at': '2026-11-03T09:30:00Z',
      'removed': false,
      'edited': false,
      'reactions': [],
    });
  }
}
