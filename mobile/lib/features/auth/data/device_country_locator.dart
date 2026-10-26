import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/circle_failure.dart';
import '../domain/country_locator.dart';

enum CountryPermission { denied, deniedForever, allowed }

/// Injectable native boundary for deterministic permission and failure tests.
abstract interface class CountryPlatform {
  Future<bool> enabled();
  Future<CountryPermission> check();
  Future<CountryPermission> request();
  Future<String?> country();
}

class DeviceCountryLocator implements CountryLocator {
  DeviceCountryLocator({CountryPlatform? platform})
    : _platform = platform ?? _NativeCountryPlatform();
  final CountryPlatform _platform;
  @override
  Future<String> detectCountry() async {
    try {
      if (_platform is _NativeCountryPlatform && !_platform.supported) {
        throw const CircleFailure(
          'Country detection is available on Android and iPhone. Choose your country manually here.',
        );
      }
      if (!await _platform.enabled()) {
        throw const CircleFailure(
          'Turn on location services, or choose your country manually.',
        );
      }
      var permission = await _platform.check();
      if (permission == CountryPermission.denied) {
        permission = await _platform.request();
      }
      if (permission != CountryPermission.allowed) {
        throw const CircleFailure(
          'Location was not allowed. You can choose your country manually.',
        );
      }
      final code = await _platform.country().timeout(
        const Duration(seconds: 25),
      );
      if (code == null || !RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
        throw const CircleFailure(
          'Your country could not be detected. Choose it manually.',
        );
      }
      return code.toUpperCase();
    } on CircleFailure {
      rethrow;
    } catch (_) {
      throw const CircleFailure(
        'Your country could not be detected. Choose it manually.',
      );
    }
  }
}

class _NativeCountryPlatform implements CountryPlatform {
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Future<bool> enabled() async =>
      supported && await Geolocator.isLocationServiceEnabled();
  CountryPermission _map(LocationPermission value) => switch (value) {
    LocationPermission.always ||
    LocationPermission.whileInUse => CountryPermission.allowed,
    LocationPermission.deniedForever => CountryPermission.deniedForever,
    _ => CountryPermission.denied,
  };
  @override
  Future<CountryPermission> check() async =>
      _map(await Geolocator.checkPermission());
  @override
  Future<CountryPermission> request() async =>
      _map(await Geolocator.requestPermission());
  @override
  Future<String?> country() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final places = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    return places.firstOrNull?.isoCountryCode;
  }
}
