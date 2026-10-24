import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_json.dart';
import 'package:mobile/features/workspace/data/api/api_mappers.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

/// Fixtures copied from the contract's shapes (openapi.yaml 0.3.1) and the
/// running backend's answers.
void main() {
  test('timestamps are UTC "YYYY-MM-DD HH:MM:SS" (or ISO 8601)', () {
    expect(
      ApiJson.time('2026-10-23 13:02:59'),
      DateTime.utc(2026, 10, 23, 13, 2, 59),
    );
    expect(
      ApiJson.time('2026-10-23T13:02:59+00:00'),
      DateTime.utc(2026, 10, 23, 13, 2, 59),
    );
    expect(ApiJson.time(''), isNull);
    expect(ApiJson.time(null), isNull);
    expect(ApiJson.boolean(1), isTrue);
    expect(ApiJson.boolean('0'), isFalse);
    expect(ApiJson.id(42), '42');
  });

  test('group: ids become strings; owner, nesting and settings map', () {
    final group = ApiMappers.group(
      {
        'id': 7,
        'parent_id': 3,
        'root_id': 1,
        'depth': 3,
        'type': 'college',
        'name': 'Sec A',
        'description': '',
        'visibility': 'hidden',
        'approval_mode': 'auto',
        'owner_user_id': 9,
        'created_at': '2026-10-23 13:02:59',
        'role': 'admin',
      },
      roles: {
        '9': ApiMappers.role('admin', owner: true),
        '12': ApiMappers.role('member'),
      },
      linkSharing: 'members',
      eventCreation: 'admins',
    );
    expect(group.id, '7');
    expect(group.parentId, '3');
    expect(group.depth, 3);
    expect(group.type, CircleType.college);
    expect(group.ownerId, '9');
    expect(group.roles['12'], CircleRole.member);
    expect(group.hidden, isTrue);
    expect(group.approvalRequired, isFalse);
    expect(group.settings.invitePolicy, InvitePolicy.allMembers);
    expect(group.settings.eventCreation, EventCreationPolicy.admins);
    final root = ApiMappers.group({
      'id': 1,
      'parent_id': null,
      'depth': 1,
      'type': 'mystery',
      'name': 'R',
      'visibility': 'hidden',
      'approval_mode': 'manual',
    }, roles: const {});
    expect(root.isSubgroup, isFalse);
    expect(root.hidden, isFalse, reason: 'only subgroups can be hidden');
    expect(root.type, CircleType.other);
    expect(root.approvalRequired, isTrue);
    expect(root.settings.invitePolicy, InvitePolicy.adminsOnly);
  });

  test('members: the owner is told apart by is_owner', () {
    final owner = ApiMappers.member({
      'id': 1,
      'display_name': 'Asha',
      'about': '',
      'avatar_path': null,
      'role': 'admin',
      'joined_at': '2026-10-23 13:02:59',
      'is_owner': true,
    });
    expect(owner, (id: '1', name: 'Asha', role: CircleRole.owner));
    final member = ApiMappers.member({
      'id': 2,
      'display_name': 'Dev',
      'role': 'member',
      'is_owner': 0,
    });
    expect(member.role, CircleRole.member);
    expect(ApiMappers.roleName(CircleRole.owner), 'admin');
  });

  test('invite links: token shown once; status from the list', () {
    final now = DateTime.utc(2026, 10, 23, 10);
    final created = ApiMappers.newInviteLink(
      {
        'id': 5,
        'token': 'L2u6H2F3gioorfo2gnBgcljGOy2idhYk',
        'expires_at': '2026-10-30 10:00:00',
        'max_uses': 25,
        'link': '/i/L2u6H2F3gioorfo2gnBgcljGOy2idhYk',
      },
      createdBy: '1',
      now: now,
    );
    expect(created.id, '5');
    expect(created.link.token, 'L2u6H2F3gioorfo2gnBgcljGOy2idhYk');
    expect(created.link.expiresAt, DateTime.utc(2026, 10, 30, 10));
    expect(created.link.maxUses, 25);
    final used = ApiMappers.linkStatus(created.link, {
      'id': 5,
      'created_by': 1,
      'created_at': '2026-10-23 10:00:00',
      'expires_at': '2026-10-30 10:00:00',
      'max_uses': 25,
      'use_count': 3,
      'revoked_at': null,
      'status': 'active',
    });
    expect(used?.uses, 3);
    expect(used?.token, created.link.token);
    expect(ApiMappers.linkStatus(created.link, {'status': 'revoked'}), isNull);
  });

  test('invite preview and server tokens keep their case', () {
    final preview = ApiMappers.invitePreview({
      'group_name': 'Sunday Cyclists',
      'group_type': 'club',
      'cover_path': null,
      'is_subgroup': false,
      'approval_required': true,
      'member_count': 12,
    }, 'AbCdEfGhIjKlMnOpQr');
    expect(preview.status, InviteLinkStatus.valid);
    expect(preview.group?.name, 'Sunday Cyclists');
    expect(preview.group?.type, CircleType.club);
    expect(preview.group?.memberCount, 12);
    expect(preview.group?.approvalRequired, isTrue);
    expect(
      serverInviteToken('circle://invite/AbCdEfGhIjKlMnOpQr'),
      'AbCdEfGhIjKlMnOpQr',
    );
    expect(
      serverInviteToken(' https://x.org/i/AbCdEfGhIjKlMnOpQr/?utm=1 '),
      'AbCdEfGhIjKlMnOpQr',
    );
    expect(serverInviteToken('short'), isNull);
    expect(serverInviteToken('has spaces in it here'), isNull);
  });

  test('join requests', () {
    final request = ApiMappers.joinRequest({
      'id': 3,
      'user_id': 8,
      'status': 'pending',
      'message': '',
      'created_at': '2026-10-23 09:00:00',
      'display_name': 'Mira',
      'avatar_path': null,
    }, groupId: '7');
    expect(request.id, '3');
    expect(request.person, '8');
    expect(request.groupId, '7');
    expect(request.createdAt, DateTime.utc(2026, 10, 23, 9));
  });

  final listItem = {
    'id': 11,
    'group_id': 7,
    'author_id': 2,
    'body': 'Rain at the reunion',
    'memory_date': '2007-01-01',
    'place': 'Kodaikanal',
    'created_at': '2026-10-23 08:00:00',
    'updated_at': '2026-10-23 09:30:00',
    'author_name': 'Dev',
    'author_avatar': null,
    'group_name': 'Sec A',
    'group_type': 'college',
    'reaction_count': 4,
    'comment_count': 2,
    'user_reacted': 1,
    'user_saved': 0,
    'media': [
      {
        'id': 'b1946ac9-2e6b-4c3f-9f5e-0e8f8b0f1a11',
        'width': 2048,
        'height': 1536,
      },
    ],
  };

  test('memory list item: counts until opened, photos by media id', () {
    final memory = ApiMappers.memory(listItem, viewer: '1', myReaction: '😂');
    expect(memory.id, '11');
    expect(memory.groupId, '7');
    expect(memory.author, 'Dev');
    expect(memory.edited, isTrue);
    expect(memory.takenYear, 2007);
    expect(memory.place, 'Kodaikanal');
    expect(memory.commentTotal, 2);
    expect(memory.comments, isEmpty);
    expect(memory.reactions.total, 4);
    expect(memory.reactions.mine, '😂');
    expect(memory.reactions.unsorted, 3);
    expect(memory.saved, isFalse);
    final photo = memory.photos.single;
    expect(photo.mediaId, 'b1946ac9-2e6b-4c3f-9f5e-0e8f8b0f1a11');
    expect(photo.scene, isNull);
    expect(photo.width, 2048);
    expect(photo.description, 'photo');
  });

  test('memory with details: comments, replies and every reaction', () {
    final memory = ApiMappers.memory(
      {...listItem, 'author_id': 1, 'updated_at': listItem['created_at']},
      viewer: '1',
      comments: [
        ApiMappers.comment({
          'id': 21,
          'parent_id': null,
          'author_id': 1,
          'body': 'So wet!',
          'created_at': '2026-10-23 08:10:00',
          'author_name': 'Asha',
        }, viewer: '1'),
        ApiMappers.comment({
          'id': 22,
          'parent_id': 21,
          'author_id': 2,
          'body': 'Ha',
          'created_at': '2026-10-23 08:11:00',
          'author_name': 'Dev',
        }, viewer: '1'),
      ],
      reactions: ApiMappers.reactions([
        {'user_id': 1, 'emoji': '❤️', 'display_name': 'Asha'},
        {'user_id': 2, 'emoji': '🎉', 'display_name': 'Dev'},
        {'user_id': 3, 'emoji': '🎉', 'display_name': 'Mira'},
      ]),
    );
    expect(memory.author, 'You');
    expect(memory.edited, isFalse);
    expect(memory.comments.first.authorName, 'You');
    expect(memory.comments.last.parentId, '21');
    expect(CommentRules.threads(memory.comments).single.replies, hasLength(1));
    expect(memory.loved, isTrue);
    expect(memory.reactions.countOf('🎉'), 2);
    expect(memory.reactions.unsorted, 0);
    expect(memory.reactions.describe(), '3 reactions: 2 Celebrate, 1 Love');
  });

  test('unexpected shapes become a calm error', () {
    expect(
      () => ApiMappers.member('nope'),
      throwsA(
        isA<CircleFailure>().having(
          (e) => e.message,
          'message',
          contains('unexpected'),
        ),
      ),
    );
  });
}
