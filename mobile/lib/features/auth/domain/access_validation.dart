/// Input syntax only. Neither phone ownership nor credentials are verified here.
abstract final class AccessValidation {
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
