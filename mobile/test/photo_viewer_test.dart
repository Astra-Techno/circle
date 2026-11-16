import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/memories/application/media_providers.dart';
import 'package:mobile/features/memories/domain/memory_photo.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';

const _photo = MemoryPhoto(id: 'fictional-hill', scene: MemoryScene.hillTrip);
const _secondPhoto = MemoryPhoto(
  id: 'fictional-birthday',
  scene: MemoryScene.birthdayCake,
);

void main() {
  testWidgets('photo gallery uses a black uncropped canvas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo])),
    );

    final scene = find.byType(CircleSceneTile);
    expect(scene, findsOneWidget);
    final frame = tester.widget<DecoratedBox>(
      find.descendant(of: scene, matching: find.byType(DecoratedBox)).first,
    );
    expect((frame.decoration as BoxDecoration).color, CircleOverlay.background);
    expect(
      tester
          .widget<Material>(
            find.descendant(of: scene, matching: find.byType(Material)),
          )
          .borderRadius,
      BorderRadius.zero,
    );
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch zoom owns page drags and double-tap resets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo])),
    );

    final finder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(finder);
    final zoom = viewer.transformationController!;
    expect(zoom.value.getMaxScaleOnAxis(), 1);
    expect(viewer.maxScale, 4);
    expect(viewer.panEnabled, isFalse);

    final center = tester.getCenter(finder);
    final left = await tester.startGesture(center + const Offset(-30, 0));
    final right = await tester.startGesture(center + const Offset(30, 0));
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(zoom.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(tester.widget<InteractiveViewer>(finder).panEnabled, isTrue);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await left.up();
    await right.up();

    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unzoomed photos still swipe to the next page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo, _secondPhoto])),
    );
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.fling(
      find.byType(InteractiveViewer),
      const Offset(-320, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single tap fades both scrims and viewer chrome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo])),
    );
    expect(
      tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)),
      everyElement(
        isA<AnimatedOpacity>().having(
          (opacity) => opacity.opacity,
          'opacity',
          1,
        ),
      ),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    final chrome = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(chrome, isNotEmpty);
    expect(
      chrome,
      everyElement(
        isA<AnimatedOpacity>().having(
          (opacity) => opacity.opacity,
          'opacity',
          0,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset zoom works with chrome visible and hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo])),
    );
    final finder = find.byType(InteractiveViewer);
    final zoom = tester
        .widget<InteractiveViewer>(finder)
        .transformationController!;

    Future<void> doubleTap() async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await doubleTap();
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(2, 0.001));
    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pumpAndSettle();
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1, 0.001));

    await doubleTap();
    await tester.tap(finder);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('Reset zoom'), findsOneWidget);
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reset zoom'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filmstrip selects a photo and marks the current thumbnail', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhotoPager(photos: [_photo, _secondPhoto])),
    );
    final first = find.byKey(const ValueKey('filmstrip-photo-fictional-hill'));
    final second = find.byKey(
      const ValueKey('filmstrip-photo-fictional-birthday'),
    );
    BoxDecoration decoration(Finder finder) =>
        tester.widget<AnimatedContainer>(finder).decoration! as BoxDecoration;
    expect(decoration(first).border!.top.color, CircleOverlay.foreground);
    expect(decoration(second).border!.top.color, Colors.transparent);

    await tester.tap(second);
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    expect(decoration(first).border!.top.color, Colors.transparent);
    expect(decoration(second).border!.top.color, CircleOverlay.foreground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share and download await explicit export completion', (
    tester,
  ) async {
    final actions = <PhotoExportAction>[];
    var completed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoPager(
            photos: const [_photo],
            onExport: (photo, action) async {
              actions.add(action);
              return completed;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(actions, [PhotoExportAction.share]);
    expect(find.text('Photo saved.'), findsNothing);

    completed = false;
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(actions, [PhotoExportAction.share, PhotoExportAction.download]);
    expect(find.text('Photo saved.'), findsNothing);

    completed = true;
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Photo saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('illustrated placeholders omit export actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPager(
          photos: const [_secondPhoto],
          onExport: (_, _) async => true,
        ),
      ),
    );

    expect(find.text('Share'), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
