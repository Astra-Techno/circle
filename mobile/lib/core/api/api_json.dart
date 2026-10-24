import 'api_error.dart';

/// Defensive readers for API JSON. Ids are integers in the API and strings
/// in the app; timestamps are UTC `YYYY-MM-DD HH:MM:SS`.
abstract final class ApiJson {
  /// The calm error for a response that doesn't match the contract.
  static Never unexpected() => throw const ApiError(
    'The server sent something unexpected. Please try again later.',
    code: ApiError.badResponse,
  );

  static Never _bad() => unexpected();

  static Map<String, Object?> map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : _bad();

  static List<Object?> list(Object? value) =>
      value is List ? List<Object?>.of(value) : const [];

  /// A required id ("42" from 42 or "42"; UUIDs stay as they are).
  static String id(Object? value) => optionalId(value) ?? _bad();

  static String? optionalId(Object? value) => switch (value) {
    int() => '$value',
    String() when value.isNotEmpty => value,
    _ => null,
  };

  static int? integer(Object? value) => switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static String string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static String? optionalString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  /// MySQL booleans may arrive as 0/1 or "0"/"1".
  static bool boolean(Object? value) => switch (value) {
    bool() => value,
    num() => value != 0,
    String() => value == '1' || value == 'true',
    _ => false,
  };

  /// Parses `YYYY-MM-DD HH:MM:SS` (UTC) or ISO 8601.
  static DateTime? time(Object? value) {
    if (value is! String || value.isEmpty) return null;
    var text = value.trim().replaceFirst(' ', 'T');
    final zoned = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(text);
    if (!zoned && text.contains('T')) text = '${text}Z';
    return DateTime.tryParse(text)?.toUtc();
  }
}
