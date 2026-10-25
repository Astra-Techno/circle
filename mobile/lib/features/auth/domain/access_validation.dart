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

/// A country with its dial code and flag emoji.
class DialCode {
  const DialCode(this.region, this.code, this.name, this.flag);
  final String region; // ISO 3166-1 alpha-2
  final String code;   // e.g. "+91"
  final String name;   // e.g. "India"
  final String flag;   // e.g. "🇮🇳"

  @override
  String toString() => '$flag $code';
}

/// Sorted by country name for the picker.
const dialCodes = <DialCode>[
  DialCode('AF', '+93', 'Afghanistan', '🇦🇫'),
  DialCode('AR', '+54', 'Argentina', '🇦🇷'),
  DialCode('AU', '+61', 'Australia', '🇦🇺'),
  DialCode('AT', '+43', 'Austria', '🇦🇹'),
  DialCode('BH', '+973', 'Bahrain', '🇧🇭'),
  DialCode('BD', '+880', 'Bangladesh', '🇧🇩'),
  DialCode('BE', '+32', 'Belgium', '🇧🇪'),
  DialCode('BR', '+55', 'Brazil', '🇧🇷'),
  DialCode('CA', '+1', 'Canada', '🇨🇦'),
  DialCode('CL', '+56', 'Chile', '🇨🇱'),
  DialCode('CN', '+86', 'China', '🇨🇳'),
  DialCode('CO', '+57', 'Colombia', '🇨🇴'),
  DialCode('CZ', '+420', 'Czech Republic', '🇨🇿'),
  DialCode('DK', '+45', 'Denmark', '🇩🇰'),
  DialCode('EC', '+593', 'Ecuador', '🇪🇨'),
  DialCode('EG', '+20', 'Egypt', '🇪🇬'),
  DialCode('FI', '+358', 'Finland', '🇫🇮'),
  DialCode('FR', '+33', 'France', '🇫🇷'),
  DialCode('DE', '+49', 'Germany', '🇩🇪'),
  DialCode('GH', '+233', 'Ghana', '🇬🇭'),
  DialCode('HU', '+36', 'Hungary', '🇭🇺'),
  DialCode('IN', '+91', 'India', '🇮🇳'),
  DialCode('ID', '+62', 'Indonesia', '🇮🇩'),
  DialCode('IE', '+353', 'Ireland', '🇮🇪'),
  DialCode('IL', '+972', 'Israel', '🇮🇱'),
  DialCode('IT', '+39', 'Italy', '🇮🇹'),
  DialCode('JP', '+81', 'Japan', '🇯🇵'),
  DialCode('KE', '+254', 'Kenya', '🇰🇪'),
  DialCode('KW', '+965', 'Kuwait', '🇰🇼'),
  DialCode('MY', '+60', 'Malaysia', '🇲🇾'),
  DialCode('MX', '+52', 'Mexico', '🇲🇽'),
  DialCode('NP', '+977', 'Nepal', '🇳🇵'),
  DialCode('NL', '+31', 'Netherlands', '🇳🇱'),
  DialCode('NZ', '+64', 'New Zealand', '🇳🇿'),
  DialCode('NG', '+234', 'Nigeria', '🇳🇬'),
  DialCode('NO', '+47', 'Norway', '🇳🇴'),
  DialCode('PK', '+92', 'Pakistan', '🇵🇰'),
  DialCode('PE', '+51', 'Peru', '🇵🇪'),
  DialCode('PH', '+63', 'Philippines', '🇵🇭'),
  DialCode('PL', '+48', 'Poland', '🇵🇱'),
  DialCode('PT', '+351', 'Portugal', '🇵🇹'),
  DialCode('QA', '+974', 'Qatar', '🇶🇦'),
  DialCode('RO', '+40', 'Romania', '🇷🇴'),
  DialCode('RU', '+7', 'Russia', '🇷🇺'),
  DialCode('SA', '+966', 'Saudi Arabia', '🇸🇦'),
  DialCode('SG', '+65', 'Singapore', '🇸🇬'),
  DialCode('ZA', '+27', 'South Africa', '🇿🇦'),
  DialCode('KR', '+82', 'South Korea', '🇰🇷'),
  DialCode('ES', '+34', 'Spain', '🇪🇸'),
  DialCode('LK', '+94', 'Sri Lanka', '🇱🇰'),
  DialCode('SE', '+46', 'Sweden', '🇸🇪'),
  DialCode('CH', '+41', 'Switzerland', '🇨🇭'),
  DialCode('TH', '+66', 'Thailand', '🇹🇭'),
  DialCode('TR', '+90', 'Turkey', '🇹🇷'),
  DialCode('AE', '+971', 'UAE', '🇦🇪'),
  DialCode('GB', '+44', 'United Kingdom', '🇬🇧'),
  DialCode('US', '+1', 'United States', '🇺🇸'),
  DialCode('UY', '+598', 'Uruguay', '🇺🇾'),
  DialCode('VE', '+58', 'Venezuela', '🇻🇪'),
  DialCode('VN', '+84', 'Vietnam', '🇻🇳'),
];

/// Input syntax only. Neither phone ownership nor credentials are verified here.
abstract final class AccessValidation {
  /// Returns the [DialCode] for the device's locale region, or India as default.
  static DialCode dialCodeForLocale(Locale locale) {
    final region = locale.countryCode?.toUpperCase() ?? '';
    return dialCodes.firstWhere(
      (d) => d.region == region,
      orElse: () => dialCodes.firstWhere((d) => d.region == 'IN'),
    );
  }

  /// "+91 98765 43210" → "+919876543210" (the API's E.164 form).
  static String normalizeMobile(String input) =>
      input.replaceAll(RegExp(r'[\s()\-]'), '');

  /// Validates the phone number portion (without dial code prefix).
  static String? phoneNumber(String? input) {
    final value = (input ?? '').replaceAll(RegExp(r'[\s()\-]'), '');
    if (value.isEmpty || value.length < 6 || value.length > 14) {
      return 'Enter your mobile number.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Only digits allowed.';
    }
    return null;
  }

  /// Validates full E.164 number (dial code + phone number combined).
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
