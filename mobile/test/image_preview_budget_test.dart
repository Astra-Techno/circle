import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/signed_media_url.dart';
import 'package:mobile/core/circle_signed_image.dart';
import 'package:mobile/features/memories/application/media_providers.dart';
import 'package:mobile/features/memories/domain/memory_photo.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'high DPI ${large ? 'viewer preserves full detail' : 'preview avoids full download and decode'}',
      (tester) async {
        final sizes = <MediaSize>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              signedMediaUrlProvider.overrideWith((ref, photo) async {
                sizes.add(photo.size);
                return SignedMediaUrl.fromApi(
                  ApiConfig.parse('https://circle.test/api/v1')!,
                  '/media/files/fictional/${photo.size.name}?expires=1&sig=ff',
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                )!;
              }),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(devicePixelRatio: 3),
                child: Center(
                  child: SizedBox(
                    width: 500,
                    height: 300,
                    child: MemoryPhotoTile(
                      photo: const MemoryPhoto(id: '1', mediaId: 'fictional'),
                      semanticsLabel: 'Fictional photo',
                      large: large,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(sizes, [large ? MediaSize.full : MediaSize.medium]);
        final image = tester.widget<CircleSignedImage>(
          find.byType(CircleSignedImage),
        );
        expect(image.cacheWidth, large ? isNull : lessThanOrEqualTo(1080));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
