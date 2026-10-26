import 'package:flutter/foundation.dart';

/// Where the CIRCLE API lives. Server mode is chosen at build time:
///
/// ```sh
/// flutter run --dart-define=CIRCLE_API_BASE_URL=http://10.0.2.2:8080/api/v1
/// ```
///
/// Debug builds default to the local preview. Release builds connect to the
/// deployed API. CIRCLE_PREVIEW=true explicitly selects a fictional build.
class ApiConfig {
  ApiConfig._(this.baseUrl);

  /// Parses [input] (for example `https://api.example.org/api/v1`). Returns
  /// null for anything that is not an absolute http(s) URL without query,
  /// fragment or credentials.
  static ApiConfig? parse(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    // No trailing slash: request paths start with "/".
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return ApiConfig._(uri.replace(path: path));
  }

  /// The build-time configuration, or null in preview builds.
  static const deployedApi = 'https://circle.cloudkart24.com/api/v1';

  /// Release installations connect to the deployed API unless explicitly
  /// built as a fictional preview. Tests/debug retain their local default.
  static ApiConfig? fromEnvironment() {
    const explicit = String.fromEnvironment('CIRCLE_API_BASE_URL');
    return forBuild(
      release: kReleaseMode,
      preview: const bool.fromEnvironment('CIRCLE_PREVIEW'),
      baseUrl: explicit.isEmpty ? null : explicit,
    );
  }

  static ApiConfig? forBuild({
    required bool release,
    bool preview = false,
    String? baseUrl,
  }) => preview ? null : parse(baseUrl ?? (release ? deployedApi : ''));

  /// The API base, e.g. `http://10.0.2.2:8080/api/v1` (no trailing slash).
  final Uri baseUrl;

  /// Shown to people as "Connected to `host`".
  String get host => baseUrl.hasPort && baseUrl.port != _defaultPort
      ? '${baseUrl.host}:${baseUrl.port}'
      : baseUrl.host;

  int get _defaultPort => baseUrl.scheme == 'https' ? 443 : 80;

  /// Plain HTTP is only for local development; production needs HTTPS.
  bool get secure => baseUrl.scheme == 'https';

  /// An absolute URL for a path relative to the API base ("/groups").
  Uri resolve(String relativePath) => Uri.parse(
    '$baseUrl${relativePath.startsWith('/') ? '' : '/'}'
    '$relativePath',
  );

  @override
  String toString() => baseUrl.toString();
}
