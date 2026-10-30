import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';

void main() {
  testWidgets(
    'list header has one title and create action, hides down and returns up',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircleTabHeaderData(
              title: 'Chats',
              titleStyle: null,
              logo: null,
              actions: const [],
              fab: (label: 'New chat', location: '/chats/new'),
              child: CustomScrollView(
                slivers: [
                  const CircleCollapsingHeader(),
                  SliverFixedExtentList(
                    itemExtent: 80,
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => Text('Conversation $index'),
                      childCount: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Chats'), findsOneWidget);
      expect(find.byTooltip('New chat'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Chats').hitTestable(), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(find.text('Chats').hitTestable(), findsOneWidget);
      expect(find.byTooltip('New chat').hitTestable(), findsOneWidget);
    },
  );
}
