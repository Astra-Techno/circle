import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/features/chat/presentation/live_chat_design.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';
import 'support/fake_api.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final mine in [false, true]) {
      testWidgets('chat body scales once at $scale, mine=$mine', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final rich in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: circleTheme(Brightness.light),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: ChatMessageBubble(
                    mine: mine,
                    sender: mine ? null : 'Fictional Member',
                    edited: rich,
                    sentAt: DateTime.utc(2026, 11, 6, 10, 15),
                    quote: rich
                        ? const ChatQuote(
                            author: 'Fictional reply',
                            text: 'A quoted message',
                          )
                        : null,
                    photos: rich ? [const SizedBox(height: 48, width: 48)] : [],
                    reactions: rich ? ['❤️'] : [],
                    child: Text(
                      rich
                          ? 'Fictional reply with photo'
                          : 'Fictional queued message',
                    ),
                  ),
                ),
              ),
            ),
          );
          final text = find.text(
            rich ? 'Fictional reply with photo' : 'Fictional queued message',
          );
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.textScaler.scale(16), 16 * scale);
          final transform = paragraph.getTransformTo(null);
          // Accessibility text scaling belongs to the paragraph, never to a
          // second ancestor transform (the previous WidgetSpan doubled it).
          expect(transform.entry(0, 0), closeTo(1, 0.001));
          expect(transform.entry(1, 1), closeTo(1, 0.001));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  test('incoming bubbles are distinct from the light page', () {
    expect(
      CircleAccents.light.chatIncoming,
      isNot(CircleAccents.light.chatWallpaper),
    );
  });

  testWidgets('photo viewer has working Memory actions and one toolbar', (
    tester,
  ) async {
    final c = await openCircle(tester);
    await go(tester, c, '/home/memory/table/photos');
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'React'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '😂'));
    await tester.pumpAndSettle();
    expect(
      c
          .read(circleWorkspaceProvider)
          .requireValue
          .memories
          .firstWhere((m) => m.id == 'table')
          .reactions
          .mine,
      '😂',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Comment'));
    await tester.pumpAndSettle();
    expect(currentUri(c).path, '/home/memory/table');
    expect(currentUri(c).queryParameters['comment'], 'true');
    final composer = tester.widget<TextField>(find.byType(TextField).last);
    expect(composer.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo reaction picker cannot cross a changed session', (
    tester,
  ) async {
    final c = await openCircle(tester);
    await go(tester, c, '/home/memory/table/photos');
    final original = c
        .read(circleWorkspaceProvider)
        .requireValue
        .memories
        .firstWhere((m) => m.id == 'table')
        .reactions
        .mine;
    await tester.tap(find.widgetWithText(TextButton, 'React'));
    await tester.pumpAndSettle();
    await c.read(apiClientProvider)!.clearTokens();
    await tester.tap(find.widgetWithText(ChoiceChip, '😂'));
    await tester.pumpAndSettle();
    expect(
      c
          .read(circleWorkspaceProvider)
          .requireValue
          .memories
          .firstWhere((m) => m.id == 'table')
          .reactions
          .mine,
      original,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('event title retains reading width at 320px and 200% text', (
    tester,
  ) async {
    final f = RootStyleFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
      size: const Size(320, 1000),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    c.read(circleRouterProvider).go('/events');
    await settle(tester);
    expect(
      tester.getSize(find.text('Fictional picnic')).width,
      greaterThan(200),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'populated inbox keeps link entry and Accepted matches its data',
    (tester) async {
      final f = RootStyleFixture();
      f.server.adapter.handler = (r) async {
        if (r.path == '/me/group-invitations') {
          return FakeResponse.page(
            [
              for (final (id, status) in [(12, 'pending'), (13, 'accepted')])
                {
                  'id': id,
                  'recipient_id': f.owner,
                  'group_id': f.group,
                  'group_name': status == 'pending'
                      ? 'Fictional pending Circle'
                      : 'Fictional accepted Circle',
                  'inviter_id': f.member,
                  'inviter_name': 'Fictional Member',
                  'status': status,
                  'approval_required': true,
                  'expires_at': '2030-11-01T00:00:00Z',
                },
            ],
            {'total': 2, 'limit': 20, 'offset': 0},
          );
        }
        return f.handle(r);
      };
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/you/invitations');
      await settle(tester);
      expect(find.text('Fictional pending Circle'), findsOneWidget);
      expect(find.text('Open an invite link'), findsOneWidget);
      expect(find.textContaining('Sent'), findsNothing);
      await tester.tap(find.text('Accepted (1)'));
      await settle(tester);
      expect(find.text('Fictional accepted Circle'), findsOneWidget);
      expect(find.text('Fictional pending Circle'), findsNothing);
      await tester.tap(find.text('Open an invite link'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
