import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/api/signed_media_url.dart';
import 'package:mobile/core/circle_signed_image.dart';
import 'package:mobile/core/design.dart';

class _StatusClient extends Fake implements HttpClient {
  _StatusClient(this.status);
  final int status;
  int requests = 0;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    return _StatusRequest(status);
  }
}

class _StatusRequest extends Fake implements HttpClientRequest {
  _StatusRequest(this.status);
  final int status;
  @override
  Future<HttpClientResponse> close() async => _StatusResponse(status);
}

class _StatusResponse extends Fake implements HttpClientResponse {
  _StatusResponse(this.statusCode);
  @override
  final int statusCode;
  @override
  Future<E> drain<E>([E? futureValue]) async => futureValue as E;
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    test('native family and regular reading weight on $platform', () {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final theme = circleTheme(Brightness.light);
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        platform == TargetPlatform.android ? 'Inter' : 'CupertinoSystemText',
      );
      expect(theme.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
      expect(theme.textTheme.labelLarge!.fontWeight, FontWeight.w500);
    });
  }
  for (final status in [403, 404]) {
    testWidgets('photo $status has bounded renewal and explicit recovery', (
      tester,
    ) async {
      final client = _StatusClient(status);
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() {
        debugNetworkImageHttpClientProvider = null;
        PaintingBinding.instance.imageCache.clear();
      });
      var attempts = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: circleTheme(Brightness.light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final url = SignedMediaUrl.fromApi(
                  ApiConfig.parse('https://circle.test/api/v1')!,
                  '/media/files/fictional/medium?expires=$attempts&sig=ff',
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                )!;
                return SizedBox(
                  width: 240,
                  height: 180,
                  child: CircleSignedImage(
                    url: url,
                    semanticsLabel: 'Fictional photo',
                    onRetry: () => update(() => attempts++),
                  ),
                );
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(attempts, status == 403 ? 1 : 0);
      expect(client.requests, status == 403 ? 2 : 1);
      expect(find.text('Retry photo'), findsOneWidget);
      expect(find.textContaining('Photo unavailable'), findsNothing);
      final previous = attempts;
      await tester.tap(find.text('Retry photo'));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(attempts, previous + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
    });
  }
}
