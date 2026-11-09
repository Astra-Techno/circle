import 'dart:io';
import 'dart:convert';
import 'package:mobile/features/memories/presentation/memory_card.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart';
import 'support/reference_home_repository.dart';
import 'package:mobile/core/circle_brand.dart';
import 'package:mobile/core/design/circle_action_icons.dart';

void main() {
  testWidgets('normalized Home visual fixture', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    if (Platform.environment['CIRCLE_REVIEW_BOLD'] == 'true') {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    addTearDown(tester.view.resetPadding);
    await openCircle(
      tester,
      size: const Size(393, 852),
      now: ReferenceHomeRepository.clock,
      repository: ReferenceHomeRepository(),
      scale: double.parse(Platform.environment['CIRCLE_REVIEW_SCALE'] ?? '1'),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final phase = Platform.environment['CIRCLE_COMPONENT_CAPTURE'];
    if (phase != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final geometry = <String, Object>{};
      void measure(String name, Finder finder) {
        final r = tester.getRect(finder);
        geometry[name] = {
          'x': r.left,
          'y': r.top,
          'width': r.width,
          'height': r.height,
        };
      }

      measure(
        'logo',
        find.byWidgetPredicate(
          (w) => w is Image && w.semanticLabel == CircleIdentity.name,
        ),
      );
      measure(
        'composer',
        find
            .ancestor(
              of: find.text('Share a memory…'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      measure(
        'quickAction',
        find
            .ancestor(of: find.text('Photo'), matching: find.byType(InkWell))
            .first,
      );
      measure('card', find.byType(CircleMemoryCard).first);
      measure('author', find.text('Priya'));
      measure('media', find.byType(PhotoGrid).first);
      measure(
        'actions',
        find
            .ancestor(
              of: find.byTooltip(
                'Comment on Memory from Priya in College Friends',
              ),
              matching: find.byType(Row),
            )
            .first,
      );
      measure(
        'dock',
        find
            .ancestor(
              of: find.byTooltip('Home'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      measure(
        'postText',
        find.text(
          'Remember our college trip? Can’t believe it’s been 10 years! ❤️',
        ),
      );
      measure('commentCount', find.text('8 comments'));
      measure('navigationItem', find.byTooltip('Home'));
      await tester.runAsync(() async {
        final frame = await boundary.toImage();
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../docs/design-previews/home-refinement/$phase.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        await File(
          '../docs/design-previews/home-refinement/$phase.json',
        ).writeAsString(jsonEncode(geometry));
        frame.dispose();
      });
    }
  });
  testWidgets('Home keeps header safe and compact dock clearance', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await openCircle(tester, size: const Size(393, 852));
    final logo = find.byWidgetPredicate(
      (w) => w is Image && w.semanticLabel == CircleIdentity.name,
    );
    expect(tester.getTopLeft(logo).dy, greaterThanOrEqualTo(24));
    expect(
      tester.getBottomRight(find.byTooltip('Profile')).dy,
      lessThanOrEqualTo(840),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(393, 852),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    testWidgets('Home reference layout ${size.width}x${size.height}', (
      tester,
    ) async {
      await openCircle(tester, size: size, now: DateTime(2026, 10, 15, 14, 30));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MaterialApp));
        await precacheImage(const AssetImage(CircleIdentity.artwork), context);
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cards = find.byType(CircleMemoryCard);
      // Verify that the action icon strip has adequate touch targets.
      final actionIcons = find.byType(CircleActionIcon);
      expect(actionIcons, findsWidgets);
      final firstAction = find
          .ancestor(of: actionIcons.first, matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(firstAction).height, greaterThanOrEqualTo(42));
      if (size.width >= 840) {
        final first = tester.getRect(cards.first);
        expect(first.width, closeTo(720, 0.01));
        expect(first.left, closeTo((size.width - 720) / 2, 0.01));
      }
      final phase = Platform.environment['CIRCLE_REVIEW_CAPTURE'];
      if (phase != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final frame = await boundary.toImage();
          final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../docs/design-previews/home-reference/$phase-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          Map<String, double> rect(Finder target) {
            final r = tester.getRect(target);
            return {
              'x': r.left,
              'y': r.top,
              'width': r.width,
              'height': r.height,
            };
          }

          await File(
            '../docs/design-previews/home-reference/$phase-${size.width.toInt()}x${size.height.toInt()}.json',
          ).writeAsString(
            jsonEncode({
              'viewport': {'width': size.width, 'height': size.height},
              'photoAction': rect(firstAction),
              'composer': rect(
                find
                    .ancestor(
                      of: find.text('Share a memory…'),
                      matching: find.byType(InkWell),
                    )
                    .first,
              ),
              'firstMemory': rect(cards.first),
            }),
          );
          frame.dispose();
        });
      }
    });
  }
}
