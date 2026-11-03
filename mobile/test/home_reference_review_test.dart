import 'dart:io';
import 'dart:convert';
import 'package:mobile/features/memories/presentation/memory_card.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart';
import 'package:mobile/core/circle_brand.dart';

void main() {
  testWidgets('Home keeps header and dock clear of system safe areas', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetPadding);
    await openCircle(tester, size: const Size(393, 852));
    final logo = find.byWidgetPredicate(
      (w) => w is Image && w.semanticLabel == CircleIdentity.name,
    );
    expect(tester.getTopLeft(logo).dy, greaterThanOrEqualTo(24));
    expect(
      tester.getBottomRight(find.text('Profile')).dy,
      lessThanOrEqualTo(836),
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
      final tile = find
          .ancestor(of: find.text('Photo'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
      if (size.width >= 840) {
        expect(
          tester.getTopLeft(cards.at(0)).dy,
          tester.getTopLeft(cards.at(1)).dy,
        );
        expect(tester.getTopLeft(cards.at(1)).dx, greaterThan(size.width / 3));
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
              'photoAction': rect(tile),
              'composer': rect(
                find
                    .ancestor(
                      of: find.text('Share a memory with your Circle...'),
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
