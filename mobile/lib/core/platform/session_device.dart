import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../circle_failure.dart';

/// Optional display metadata only. Never reads hardware identifiers or tracks
/// background location; coordinates go only to the device's geocoder, never the CIRCLE API.
class SessionDevice {
  const SessionDevice();
  Future<Map<String, String>> details() async {
    try {
      final data = await const MethodChannel(
        'circle/session_device',
      ).invokeMapMethod<String, String>('details');
      return data ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<String> approximateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const CircleFailure('Turn on location services, then try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const CircleFailure(
          'Location was not shared. You can still manage your devices.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final places = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 10));
      final place = places.firstOrNull;
      final parts = <String>{
        if (place?.locality?.isNotEmpty == true) place!.locality!,
        if (place?.administrativeArea?.isNotEmpty == true)
          place!.administrativeArea!,
        if (place?.country?.isNotEmpty == true) place!.country!,
      };
      final label = parts.join(', ');
      if (label.isEmpty) {
        throw const CircleFailure(
          'Your approximate location could not be found.',
        );
      }
      return label;
    } on CircleFailure {
      rethrow;
    } catch (_) {
      throw const CircleFailure(
        'Location is unavailable. You can still manage your devices.',
      );
    }
  }
}

final sessionDeviceProvider = Provider<SessionDevice>(
  (ref) => const SessionDevice(),
);
