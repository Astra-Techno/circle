import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_brand.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

void main() {
  testWidgets(
    'welcome offers open registration and an explicit fictional tour',
    (tester) async {
      await openCircle(tester, entered: false);
      await tapText(tester, 'Explore fictional circles');
      expect(find.byType(CircleBrand), findsOneWidget);
      expect(find.text('Memories'), findsOneWidget);
      for (final label in ['Home', 'Chats', 'Groups', 'Events', 'You']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
        );
      }
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Shared with The Sunday table only')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'mobile/password preview grants no sample memberships; first group and Memory work',
    (tester) async {
      final container = await openCircle(tester, entered: false);
      await tapText(tester, 'Create account');
      await tester.enterText(
        find.byKey(const ValueKey('access-mobile')),
        '9876543210',
      );
      await tester.enterText(
        find.byKey(const ValueKey('access-password')),
        'a fictional passphrase',
      );
      await tapText(tester, 'Preview registration');
      expect(workspaceOf(container).groups, isEmpty);
      expect(workspaceOf(container).invitations, isEmpty);
      await tapText(tester, 'Create a group');
      await tester.enterText(find.byType(TextField), 'Our weekend circle');
      await tapText(tester, 'Create private group');
      expect(workspaceOf(container).groups.single.name, 'Our weekend circle');
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Memory'));
      await tester.pumpAndSettle();
      // With a single group the only possible audience is shown.
      expect(find.text('Our weekend circle'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Our first shared moment.',
      );
      await tapText(tester, 'Share Memory');
      expect(find.text('Our first shared moment.'), findsOneWidget);
    },
  );

  group('compose audience', () {
    testWidgets('no silent default when several groups exist', (tester) async {
      final container = await openCircle(tester);
      await tester.tap(find.text('Create Memory'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your Memory'),
        'Who sees this?',
      );
      await tapText(tester, 'Share Memory');
      expect(find.text('Choose who will see this Memory.'), findsOneWidget);
      expect(
        workspaceOf(container).memories.any((m) => m.text == 'Who sees this?'),
        isFalse,
      );
    });

    testWidgets('Home filter opens compose for that group', (tester) async {
      final container = await openCircle(tester);
      await reveal(tester, find.widgetWithText(ChoiceChip, 'Sunday miles'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sunday miles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Memory'));
      await tester.pumpAndSettle();
      expect(currentUri(container).queryParameters['group'], 'club');
      await tester.enterText(
        find.widgetWithText(TextField, 'Your Memory'),
        'Only for the riders.',
      );
      await tapText(tester, 'Share Memory');
      final memory = workspaceOf(
        container,
      ).memories.firstWhere((m) => m.text == 'Only for the riders.');
      expect(memory.groupId, 'club');
    });

    testWidgets('group detail opens compose for that exact group', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/cse');
      await tapText(tester, 'Share a Memory here');
      expect(currentUri(container).toString(), '/compose?group=cse');
      expect(find.text('Computer science · in Northbank 2009'), findsWidgets);
    });

    testWidgets('a group the viewer is not in is never preselected', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/compose?group=private-plans');
      expect(find.text('Choose a group'), findsOneWidget);
    });
  });

  testWidgets(
    'group detail stack survives tab switches and hidden content stays denied',
    (tester) async {
      final container = await openCircle(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'window-seat');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Northbank 2009 › Computer science › Section A'),
        findsOneWidget,
      );
      await tester.tap(find.text('The window-seat crew'));
      await tester.pumpAndSettle();
      expect(find.text('Computer science'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Computer science'), findsOneWidget);
      await go(tester, container, '/groups/g/private-plans');
      expect(find.text('This circle is private'), findsOneWidget);
      expect(find.text('A private planning note.'), findsNothing);
    },
  );

  testWidgets('groups list is a real tree with collapsible branches', (
    tester,
  ) async {
    await openCircle(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
    await tester.pumpAndSettle();
    final names = [
      'Northbank 2009',
      'Computer science',
      'Section A',
      'The window-seat crew',
      'Studio North',
    ];
    double? previousY;
    double? previousX;
    for (final (index, name) in names.indexed) {
      await reveal(tester, find.text(name));
      final y = tester.getTopLeft(find.text(name)).dy;
      final x = tester.getTopLeft(find.text(name)).dx;
      if (previousY != null && index < 4) {
        // Scrolling can move items; compare against the previous on screen.
        expect(x, greaterThan(previousX!), reason: '$name is nested deeper');
      }
      previousY = y;
      previousX = x;
    }
    expect(find.textContaining('Level 4 · in Section A'), findsOneWidget);
    await reveal(tester, find.byTooltip('Collapse Northbank 2009'));
    await tester.tap(find.byTooltip('Collapse Northbank 2009'));
    await tester.pumpAndSettle();
    expect(find.text('Computer science'), findsNothing);
    await tester.tap(find.byTooltip('Expand Northbank 2009'));
    await tester.pumpAndSettle();
    expect(find.text('Computer science'), findsOneWidget);
  });

  testWidgets(
    'love, save, comments, RSVP and ending preview persist then clear',
    (tester) async {
      final container = await openCircle(tester);
      await reveal(
        tester,
        find.byTooltip('Save Memory from Mira in The Sunday table'),
      );
      await tester.tap(
        find.byTooltip('Save Memory from Mira in The Sunday table'),
      );
      await tester.pumpAndSettle();
      expect(workspaceOf(container).memories.first.saved, isTrue);
      await go(tester, container, '/home/memory/table');
      await tapText(tester, 'Love');
      expect(workspaceOf(container).memories.first.loved, isTrue);
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'See you next Sunday.');
      await tapText(tester, 'Send comment');
      final comment = workspaceOf(container).memories.first.comments.last;
      expect(comment.text, 'See you next Sunday.');
      expect(comment.authorName, 'You');
      await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
      await tester.pumpAndSettle();
      await tapText(tester, 'A Sunday well spent');
      await tapText(tester, 'Going');
      expect(
        workspaceOf(container).event('lunch')!.rsvpOf('you')?.status,
        Attendance.going,
      );
      await tapText(tester, 'Clear my answer');
      expect(workspaceOf(container).event('lunch')!.rsvpOf('you'), isNull);
      await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Same table'), findsOneWidget);
      // Ending the preview lives under You › Account (H5).
      await tapText(tester, 'Account');
      await tapText(tester, 'End preview and clear local changes');
      expect(container.read(circlePreviewSessionProvider), false);
      await container
          .read(circlePreviewSessionProvider.notifier)
          .enter(showcase: false);
      await tester.pumpAndSettle();
      expect(workspaceOf(container).memories, isEmpty);
    },
  );

  testWidgets(
    'protected route resumes after entry without granting unauthorized access',
    (tester) async {
      final container = await openCircle(tester, entered: false);
      await go(tester, container, '/groups/g/private-plans');
      expect(find.text('Good to have\nyou back.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('access-mobile')),
        '9876543210',
      );
      await tester.enterText(
        find.byKey(const ValueKey('access-password')),
        'fictional password',
      );
      await tapText(tester, 'Preview log in');
      expect(find.text('This circle is private'), findsOneWidget);
    },
  );

  group('members and requests', () {
    Future<void> openMembers(
      WidgetTester tester,
      ProviderContainer container,
      String id,
    ) async {
      await go(tester, container, '/groups/g/$id');
      await openTab(tester, 'Members');
    }

    testWidgets('admins approve requests and manage roles with undo', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/family');
      await tapText(tester, '1 request');
      expect(find.text('Asking to join (1)'), findsOneWidget);
      expect(find.text('Used the invite link'), findsOneWidget);
      await tapText(tester, 'Approve');
      expect(find.text('Arjun joined The Sunday table.'), findsOneWidget);
      expect(workspaceOf(container).group('family')!.isMember('arjun'), true);
      await reveal(tester, find.byTooltip('Manage Dev'));
      await tester.tap(find.byTooltip('Manage Dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin'));
      await tester.pumpAndSettle();
      expect(
        workspaceOf(container).group('family')!.roles['dev'],
        CircleRole.admin,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        workspaceOf(container).group('family')!.roles['dev'],
        CircleRole.member,
      );
      // The owner has no management menu and cannot be removed.
      expect(find.byTooltip('Manage You'), findsNothing);
    });

    testWidgets('removal warns about every visible subgroup it cascades to', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await openMembers(tester, container, 'college');
      expect(find.byTooltip('Manage Mira'), findsNothing, reason: 'owner');
      await reveal(tester, find.byTooltip('Manage Sam'));
      await tester.tap(find.byTooltip('Manage Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Northbank 2009'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Sam?'), findsOneWidget);
      expect(find.text('• Computer science'), findsOneWidget);
      expect(find.text('• Electronics'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      final workspace = workspaceOf(container);
      expect(workspace.group('college')!.isMember('sam'), isFalse);
      expect(workspace.group('cse')!.isMember('sam'), isFalse);
    });

    testWidgets('owner transfers ownership from settings with confirmation', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/riders/settings');
      await tapText(tester, 'Transfer ownership');
      await tester.tap(find.text('Mira'));
      await tester.pumpAndSettle();
      expect(find.text('Make Mira the owner?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Make owner'));
      await tester.pumpAndSettle();
      final riders = workspaceOf(container).group('riders')!;
      expect(riders.ownerId, 'mira');
      expect(riders.roles['you'], CircleRole.admin);
    });
  });

  group('invitations and links', () {
    testWidgets('invite screen labels the preview link; reset retires it', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/club');
      await tapText(tester, 'Invite people');
      expect(
        find.text(
          'Preview link — not shareable. It only works inside this preview.',
        ),
        findsOneWidget,
      );
      expect(find.text('circle://invite/sunday-miles-preview'), findsOneWidget);
      expect(find.textContaining('3 of 25 uses'), findsOneWidget);
      await tapText(tester, 'More options');
      await tapText(tester, 'Reset link');
      expect(find.text('Reset the invite link?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reset link'));
      await tester.pumpAndSettle();
      expect(
        workspaceOf(container).group('club')!.inviteLink!.token,
        isNot('sunday-miles-preview'),
      );
      await go(tester, container, '/invite/sunday-miles-preview');
      expect(find.text('This invite link no longer works'), findsOneWidget);
    });

    testWidgets('direct add creates a pending invitation needing consent', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/cse/invite');
      expect(find.text('Add people from Northbank 2009'), findsOneWidget);
      await reveal(tester, find.bySemanticsLabel('Invite Noor'));
      await tester.tap(find.bySemanticsLabel('Invite Noor'));
      await tester.pumpAndSettle();
      expect(
        find.text('Invitation sent. Noor needs to accept.'),
        findsOneWidget,
      );
      expect(workspaceOf(container).group('cse')!.isMember('noor'), isFalse);
      expect(
        workspaceOf(container).sentInvitations.map((i) => i.invitee),
        contains('noor'),
      );
      expect(find.bySemanticsLabel('Invite Noor'), findsNothing);
    });

    testWidgets('invitations inbox accepts and declines', (tester) async {
      final container = await openCircle(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Invitations for you'), findsOneWidget);
      expect(
        find.text('Dev invited you · 2 members · in Studio North'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsLabel('Accept invitation to Board games'),
      );
      await tester.pumpAndSettle();
      expect(find.text('You joined Board games.'), findsOneWidget);
      expect(workspaceOf(container).group('board'), isNotNull);
      await tester.tap(
        find.bySemanticsLabel('Decline invitation to Cousins’ corner'),
      );
      await tester.pumpAndSettle();
      expect(workspaceOf(container).invitations, isEmpty);
      expect(find.text('Invitations for you'), findsNothing);
      expect(workspaceOf(container).group('cousins'), isNull);
    });

    testWidgets('opening a link previews, asks to join and shows pending', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Open an invite link');
      await tester.tap(find.text('chapter-verse-preview'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter & verse'), findsOneWidget);
      expect(find.text('Club · 2 members'), findsOneWidget);
      expect(find.text('Link shared by Noor'), findsOneWidget);
      await tapText(tester, 'Ask to join');
      expect(currentUri(container).path, '/groups/g/book');
      expect(find.textContaining('Waiting for approval'), findsOneWidget);
      expect(find.text('Members'), findsNothing);
      await tapText(tester, 'Cancel request');
      expect(workspaceOf(container).pending.map((p) => p.groupId), ['meetup']);
    });

    testWidgets('pasted links join directly when approval is off', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Open an invite link');
      await tester.enterText(
        find.widgetWithText(TextField, 'Invite link or code'),
        ' circle://invite/garden-plot-preview ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Open'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Join group');
      expect(workspaceOf(container).group('garden'), isNotNull);
      expect(find.text('Welcome to Garden plot 14.'), findsOneWidget);
    });

    testWidgets('subgroup, expired and unknown links fail with clear copy', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/invite/quiz-night-preview');
      expect(find.text('Join Studio social first'), findsOneWidget);
      expect(find.text('Ask to join'), findsNothing);
      await go(tester, container, '/invite/hill-trip-preview');
      expect(find.text('This invite link has expired'), findsOneWidget);
      await go(tester, container, '/invite/nothing-here');
      expect(find.text('We couldn’t find that invite'), findsOneWidget);
    });
  });

  group('subgroups, pending and settings', () {
    testWidgets('listed subgroups can be joined; hidden ones never appear', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/college');
      await openTab(tester, 'Subgroups');
      expect(find.text('More in Northbank 2009'), findsOneWidget);
      expect(find.text('Organising committee'), findsNothing);
      expect(find.text('Meetup helpers'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Cancel request to join Meetup helpers'),
        findsOneWidget,
      );
      await reveal(tester, find.bySemanticsLabel('Ask to join Electronics'));
      await tester.tap(find.bySemanticsLabel('Ask to join Electronics'));
      await tester.pumpAndSettle();
      expect(
        find.text('Request sent to the admins of Electronics.'),
        findsOneWidget,
      );
      expect(
        workspaceOf(container).pending.map((p) => p.groupId),
        contains('ece'),
      );
    });

    testWidgets('pending groups reveal only the name', (tester) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/meetup');
      expect(find.text('Meetup helpers'), findsOneWidget);
      expect(find.textContaining('Waiting for approval'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.textContaining('2 members'), findsNothing);
      expect(find.text('Noor'), findsNothing);
    });

    testWidgets('leaving warns about cascade; owners get guidance instead', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/family/settings');
      // Admins also see "Reports and admin actions", so the page is longer.
      await reveal(tester, find.textContaining('Owners can’t leave'));
      expect(find.textContaining('Owners can’t leave'), findsOneWidget);
      expect(find.text('Leave The Sunday table'), findsNothing);
      await go(tester, container, '/groups/g/college/settings');
      await tapText(tester, 'Leave Northbank 2009');
      expect(find.text('Leave Northbank 2009?'), findsOneWidget);
      for (final name in [
        'Computer science',
        'Section A',
        'The window-seat crew',
      ]) {
        expect(find.text('• $name'), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/groups');
      final ids = workspaceOf(container).groups.map((g) => g.id);
      expect(ids, isNot(contains(anyOf('college', 'cse', 'friends'))));
    });

    testWidgets('admins change approval with undo; members see read-only', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/groups/g/family/settings');
      await tapText(tester, 'Ask before people join');
      expect(workspaceOf(container).group('family')!.approvalRequired, false);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(workspaceOf(container).group('family')!.approvalRequired, true);
      await go(tester, container, '/groups/g/work/settings');
      expect(
        find.text('Only admins can change these settings.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Group name'), findsNothing);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNull);
    });
  });

  testWidgets('accessibility: photo is read once; Love has context', (
    tester,
  ) async {
    await openCircle(tester);
    final handle = tester.ensureSemantics();
    try {
      expect(
        find.bySemanticsLabel(
          'Photo 1 of 4: fictional illustration, Sunday lunch. '
          'Room for one more',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Room for one more'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp('Love Memory from Mira in The Sunday table'),
        ),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('navigation bar stays compact at 200% text', (tester) async {
    await openCircle(tester, scale: 2);
    final bar = tester.getSize(find.byType(NavigationBar));
    expect(
      bar.height,
      lessThanOrEqualTo(68 + 12 * navigationMaxTextScale + 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  for (final route in ['/home', '/groups', '/groups/g/family']) {
    testWidgets('$route has accessible labels and touch targets', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, route);
      final handle = tester.ensureSemantics();
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  }

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('screens support dark, 200% text at $size', (tester) async {
      final container = await openCircle(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      for (final route in [
        '/home',
        '/chats',
        '/groups',
        '/events',
        '/you',
        '/groups/g/friends',
        '/groups/new',
        '/groups/new?parent=cse',
        '/compose',
        '/home/memory/table',
        '/groups/g/college/settings',
        '/groups/g/family/settings',
        '/groups/g/club/invite',
        '/groups/g/cse/invite',
        '/groups/g/meetup',
        '/invite/chapter-verse-preview',
        '/invite/quiz-night-preview',
        '/invite/hill-trip-preview',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await go(tester, container, '/groups/g/college');
      for (final tab in [
        'Memories',
        'Subgroups',
        'Members',
        'Events',
        'Chat',
        'Albums',
      ]) {
        await openTab(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Members');
      await reveal(tester, find.byTooltip('Manage Dev'));
      await tester.tap(find.byTooltip('Manage Dev'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'member sheet');
    });
  }

  for (final route in [
    '/home',
    '/chats',
    '/groups',
    '/events',
    '/you',
    '/groups/g/friends',
    '/groups/new',
    '/compose',
  ]) {
    testWidgets('original circle golden $route', (tester) async {
      final container = await openCircle(
        tester,
        now: route == '/events' || route == '/groups/g/friends'
            ? DateTime(2026, 10, 24, 12)
            : null,
      );
      await go(tester, container, route);
      if (route == '/home') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(CircleIdentity.artwork),
            tester.element(find.byType(CircleBrand)),
          ),
        );
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/circle_${route.substring(1).replaceAll('/', '_')}.png',
        ),
      );
    });
  }

  testWidgets('original circle golden dark home', (tester) async {
    await openCircle(tester, brightness: Brightness.dark);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(CircleIdentity.artwork),
        tester.element(find.byType(CircleBrand)),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/circle_home_dark.png'),
    );
  });
}
