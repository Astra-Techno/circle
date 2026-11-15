import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/memories/domain/memory_photo.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';

const _photo = MemoryPhoto(id: 'fictional-hill', scene: MemoryScene.hillTrip);

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
    expect(
      (frame.decoration as BoxDecoration).color,
      CircleOverlay.background,
    );
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

    final center = tester.getCenter(finder);
    final left = await tester.startGesture(center + const Offset(-30, 0));
    final right = await tester.startGesture(center + const Offset(30, 0));
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(zoom.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await left.up();
    await right.up();

    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(finder);
    await tester.pump();
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });
}
