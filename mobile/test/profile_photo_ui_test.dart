import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/application/profile_providers.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

class ProfilePicker implements ProfilePhotoPicker {
  ProfilePickedPhoto? result;
  @override
  Future<ProfilePickedPhoto?> pick() async => result;
}

void main() {
  testWidgets('cancel, replace and remove avatar without losing cover', (
    tester,
  ) async {
    final server = FakeCircleServer(mediaAvailable: true);
    final user = server.addUser(
      '+9995550000781',
      'fictional password',
      'Fictional Person',
    );
    final picker = ProfilePicker();
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
      profilePicker: picker,
    );
    await tester.tap(find.text('Profile'));
    await settle(tester);
    await tester.tap(find.byTooltip('Add profile photo'));
    await settle(tester);
    await tester.tap(find.text('Choose a photo'));
    await settle(tester);
    expect(server.adapter.count('PUT', '/me/photos/avatar'), 0);
    picker.result = ProfilePickedPhoto(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR4nGNocFhAEmIY1TCqYfhqAAACpWAQ99uwLAAAAABJRU5ErkJggg==',
      ),
      mimeType: 'image/png',
    );
    await tester.tap(find.byTooltip('Add profile photo'));
    await settle(tester);
    await tester.tap(find.text('Choose a photo'));
    await settle(tester);
    final original = container.read(serverAccountProvider)!.avatarVersion;
    expect(original, isNotNull);
    await tester.tap(find.byTooltip('Add cover'));
    await settle(tester);
    await tester.tap(find.text('Choose a photo'));
    await settle(tester);
    final cover = container.read(serverAccountProvider)!.coverVersion;
    expect(cover, isNotNull);
    await tester.tap(find.byTooltip('Change profile photo'));
    await settle(tester);
    await tester.tap(find.text('Replace photo'));
    await settle(tester);
    expect(
      container.read(serverAccountProvider)!.avatarVersion,
      isNot(original),
    );
    await tester.tap(find.byTooltip('Change profile photo'));
    await settle(tester);
    await tester.tap(find.text('Remove photo'));
    await settle(tester);
    expect(container.read(serverAccountProvider)!.avatarVersion, isNull);
    expect(container.read(serverAccountProvider)!.coverVersion, cover);
    expect(tester.takeException(), isNull);
  });
}
