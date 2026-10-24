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

/// Input syntax only. Neither phone ownership nor credentials are verified here.
abstract final class AccessValidation {
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
    if (registering && (value.runes.length < 15 || value.runes.length > 128)) {
      return 'Use 15–128 characters. Spaces and passphrases are welcome.';
    }
    return null;
  }
}
