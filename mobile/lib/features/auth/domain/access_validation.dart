import 'dart:ui' show Locale;

/// What the access form sends in server mode. The password is exactly as
/// typed (never trimmed); the mobile number has spacing removed.
class AccessDetails {
  const AccessDetails({
    required this.registering,
    required this.mobile,
    required this.password,
    this.name,
  });
  final bool registering;
  final String mobile, password;
  final String? name;

  /// Never print credentials.
  @override
  String toString() => 'AccessDetails(<redacted>)';
}

/// Common country calling codes keyed by ISO 3166-1 alpha-2 locale region.
const _dialCodes = <String, String>{
  'IN': '+91', 'US': '+1', 'GB': '+44', 'CA': '+1', 'AU': '+61',
  'DE': '+49', 'FR': '+33', 'IT': '+39', 'ES': '+34', 'BR': '+55',
  'JP': '+81', 'KR': '+82', 'CN': '+86', 'RU': '+7', 'MX': '+52',
  'ZA': '+27', 'NG': '+234', 'KE': '+254', 'EG': '+20', 'GH': '+233',
  'PK': '+92', 'BD': '+880', 'LK': '+94', 'NP': '+977', 'ID': '+62',
  'MY': '+60', 'SG': '+65', 'PH': '+63', 'TH': '+66', 'VN': '+84',
  'AE': '+971', 'SA': '+966', 'QA': '+974', 'KW': '+965', 'BH': '+973',
  'NZ': '+64', 'IE': '+353', 'NL': '+31', 'BE': '+32', 'CH': '+41',
  'AT': '+43', 'SE': '+46', 'NO': '+47', 'DK': '+45', 'FI': '+358',
  'PL': '+48', 'PT': '+351', 'CZ': '+420', 'RO': '+40', 'HU': '+36',
  'IL': '+972', 'TR': '+90', 'AR': '+54', 'CL': '+56', 'CO': '+57',
  'PE': '+51', 'VE': '+58', 'EC': '+593', 'UY': '+598',
};

/// Input syntax only. Neither phone ownership nor credentials are verified here.
abstract final class AccessValidation {
  /// Returns the dial prefix (e.g. "+91") for the device's locale region,
  /// or an empty string if the region is unknown.
  static String dialCodeForLocale(Locale locale) =>
      _dialCodes[locale.countryCode?.toUpperCase() ?? ''] ?? '';

  /// "+91 98765 43210" → "+919876543210" (the API's E.164 form).
  static String normalizeMobile(String input) =>
      input.replaceAll(RegExp(r'[\s()\-]'), '');

  static String? mobile(String? input) {
    final value = (input ?? '').replaceAll(RegExp(r'[\s()\-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value)) {
      return 'Include the country code, for example +91, and your mobile number.';
    }
    return null;
  }

  static String? password(String? input, {required bool registering}) {
    final value = input ?? '';
    if (value.isEmpty) return 'Enter your password.';
    if (registering && (value.runes.length < 6 || value.runes.length > 128)) {
      return 'Use 6–128 characters.';
    }
    return null;
  }
}
