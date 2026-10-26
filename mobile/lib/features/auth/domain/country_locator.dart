/// One-shot country selection. Implementations never return/store coordinates.
abstract interface class CountryLocator {
  Future<String> detectCountry();
}
