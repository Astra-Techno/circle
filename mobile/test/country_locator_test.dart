import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_failure.dart';
import 'package:mobile/features/auth/data/device_country_locator.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';

class FakeCountryPlatform implements CountryPlatform {
  bool services = true;
  CountryPermission permission = CountryPermission.denied;
  CountryPermission answer = CountryPermission.allowed;
  String? iso = 'in';
  int requests = 0, lookups = 0;
  @override
  Future<bool> enabled() async => services;
  @override
  Future<CountryPermission> check() async => permission;
  @override
  Future<CountryPermission> request() async {
    requests++;
    return answer;
  }

  @override
  Future<String?> country() async {
    lookups++;
    return iso;
  }
}

void main() {
  test('India is the initial calling code independent of language', () {
    expect(AccessValidation.defaultDialCode.code, '+91');
    expect(AccessValidation.dialCodeForRegion('gb')?.code, '+44');
    expect(AccessValidation.dialCodeForRegion('XX'), isNull);
  });
  test(
    'no permission is requested until an explicit lookup; grant selects country',
    () async {
      final platform = FakeCountryPlatform();
      final locator = DeviceCountryLocator(platform: platform);
      expect(platform.requests, 0);
      expect(await locator.detectCountry(), 'IN');
      expect(platform.requests, 1);
      expect(platform.lookups, 1);
    },
  );
  test(
    'denied and permanently denied permission never look up a location',
    () async {
      final platform = FakeCountryPlatform()..answer = CountryPermission.denied;
      await expectLater(
        DeviceCountryLocator(platform: platform).detectCountry(),
        throwsA(isA<CircleFailure>()),
      );
      expect(platform.lookups, 0);
      platform.permission = CountryPermission.deniedForever;
      await expectLater(
        DeviceCountryLocator(platform: platform).detectCountry(),
        throwsA(isA<CircleFailure>()),
      );
      expect(platform.requests, 1);
      expect(platform.lookups, 0);
    },
  );
  test(
    'disabled services and an unknown country fall back to manual selection',
    () async {
      final platform = FakeCountryPlatform()..services = false;
      await expectLater(
        DeviceCountryLocator(platform: platform).detectCountry(),
        throwsA(isA<CircleFailure>()),
      );
      expect(platform.requests, 0);
      platform
        ..services = true
        ..iso = null;
      await expectLater(
        DeviceCountryLocator(platform: platform).detectCountry(),
        throwsA(isA<CircleFailure>()),
      );
    },
  );
}
