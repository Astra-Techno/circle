import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_country_locator.dart';
import '../domain/country_locator.dart';

final countryLocatorProvider = Provider<CountryLocator>(
  (ref) => DeviceCountryLocator(),
);
