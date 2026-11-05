import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/signed_media_url.dart';
import 'package:mobile/features/memories/application/media_providers.dart';
import 'package:mobile/features/memories/domain/memory_photo.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';

class UnavailableMedia extends ApiMediaRepository {
  UnavailableMedia()
    : super(
        api: ApiClient(
          config: ApiConfig.parse('https://circle.test/api/v1')!,
          tokens: MemoryTokenStore(),
        ),
      );
  int calls = 0;
  @override
  Future<SignedMediaUrl> link(String id, MediaSize size) async {
    calls++;
    throw const ApiError('Unavailable', code: 'unavailable', status: 503);
  }
}

void main() {
  testWidgets(
    'off-screen private photos neither fetch links nor animate spinners',
    (tester) async {
      final media = UnavailableMedia();
      addTearDown(() => media.api.dio.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaRepositoryProvider.overrideWithValue(media)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 1400),
                    const SizedBox(
                      width: 200,
                      height: 200,
                      child: MemoryPhotoTile(
                        photo: MemoryPhoto(
                          id: 'offscreen',
                          mediaId: 'offscreen',
                        ),
                        semanticsLabel: 'Fictional photo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(media.calls, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(media.calls, 1);
      expect(find.text('Retry photo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed photo links show retry without automatic request storms',
    (tester) async {
      final media = UnavailableMedia();
      addTearDown(() => media.api.dio.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaRepositoryProvider.overrideWithValue(media)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: MemoryPhotoTile(
                  photo: MemoryPhoto(id: 'fictional', mediaId: 'fictional'),
                  semanticsLabel: 'Fictional photo',
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(media.calls, 1);
      final retry = find.text('Retry photo');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(media.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
