import 'api_config.dart';

/// A short-lived link to photo bytes, issued by `GET /media/{id}` (ADR 0007).
///
/// It can only be made from a path the media API returned, on the same
/// scheme, host and port as the configured API, under `/media/files/`. This
/// is the only kind of URL the app ever loads images from (see
/// `CircleSignedImage` and `test/design_system_guard_test.dart`).
class SignedMediaUrl {
  const SignedMediaUrl._(this.uri, this.expiresAt);

  /// Builds the link from the API's relative [path]; null when the path
  /// isn't a signed media file path of [config]'s server.
  static SignedMediaUrl? fromApi(
    ApiConfig config,
    String path, {
    required DateTime expiresAt,
  }) {
    if (!path.startsWith('/media/files/') ||
        path.contains('..') ||
        path.contains(r'\') ||
        path.contains('//') ||
        path.contains('@')) {
      return null;
    }
    final uri = Uri.tryParse(config.resolve(path).toString());
    final base = config.baseUrl;
    if (uri == null ||
        uri.scheme != base.scheme ||
        uri.host != base.host ||
        uri.port != base.port ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('${base.path}/media/files/') ||
        uri.pathSegments.any((segment) => segment == '..' || segment == '.')) {
      return null;
    }
    return SignedMediaUrl._(uri, expiresAt.toUtc());
  }

  final Uri uri;
  final DateTime expiresAt;

  /// Still usable for at least [margin] (default 30 seconds) at [now].
  bool usableAt(
    DateTime now, {
    Duration margin = const Duration(seconds: 30),
  }) => expiresAt.difference(now.toUtc()) > margin;

  @override
  String toString() => uri.toString();

  @override
  bool operator ==(Object other) => other is SignedMediaUrl && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}
