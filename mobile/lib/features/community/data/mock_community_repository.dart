import '../../feed/data/mock_feed_repository.dart';
import '../domain/entry.dart';

class MockCommunityRepository implements CommunityRepository {
  static const _entries = [
    CircleEntry(
      'theatre',
      EntryKind.group,
      'The backstage crew',
      'Invite-only · 8 fictional members',
      'For the people who painted sets, forgot lines, and stayed for the final bow. You are a demo member of this group. Group posting comes in a later phase.',
    ),
    CircleEntry(
      'walks',
      EntryKind.group,
      'Sunday wanderers',
      'Invite-only · 12 fictional members',
      'Slow walks and long conversations. You are a demo member. Next walk: the old lakeside route.',
    ),
    CircleEntry(
      'campus',
      EntryKind.album,
      'The campus years',
      '2002–2006 · Illustrated archive',
      'The courtyard, the library steps, and a thousand ordinary afternoons. Fictional illustrations stand in for private photos; uploads and tagging are not enabled.',
    ),
    CircleEntry(
      'farewell',
      EntryKind.album,
      'One last afternoon',
      '2006 · Illustrated archive',
      'A farewell that turned out to be the beginning of a much longer friendship.',
    ),
    CircleEntry(
      'mira',
      EntryKind.friend,
      'Mira Sen',
      'Mimi · Design · Pune',
      'Marigold College · Class of 2006. Fictional profile visible inside this demo community. Collects books, postcards and stories.',
    ),
    CircleEntry(
      'dev',
      EntryKind.friend,
      'Dev Rao',
      'Dev · Engineering · Chennai',
      'Marigold College · Class of 2006. Fictional profile. Still volunteers to organise the annual gathering.',
    ),
    CircleEntry(
      'arun',
      EntryKind.friend,
      'Arun Iyer',
      'Ari · Literature · Bengaluru',
      'Marigold College · Class of 2006. Fictional profile. Always has time for one more cup of tea.',
    ),
    CircleEntry(
      'twenty',
      EntryKind.event,
      'Twenty years, together',
      '19 Dec 2026 · 4 PM IST · Old campus lawn',
      'An easy afternoon of familiar faces, shared stories and tea. Fictional reunion. RSVP is stored only in this session; no invitations are sent.',
    ),
  ];
  @override
  List<CircleEntry> entries(String communityId, EntryKind kind) {
    if (communityId != demoCommunity) {
      throw StateError('Community access denied');
    }
    return List.unmodifiable(_entries.where((entry) => entry.kind == kind));
  }
}
