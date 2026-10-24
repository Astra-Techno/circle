import 'package:dio/dio.dart';
import '../circle_failure.dart';

/// A failed API call, already translated into calm, user-facing words.
///
/// [code] is the contract's stable `error.code` (see
/// `docs/api-contracts/openapi.yaml`) or one of the client-side codes below.
/// Raw server text is never shown, except the short human-readable message
/// of a `422 validation_error` (it names the field that needs attention).
class ApiError extends CircleFailure {
  const ApiError(
    super.message, {
    required this.code,
    this.status,
    this.retryAfter,
    this.details = const {},
  });

  /// Client-side codes (not sent by the server).
  static const offline = 'network_offline',
      timeout = 'network_timeout',
      untrusted = 'network_untrusted',
      badResponse = 'bad_response',
      sessionExpired = 'session_expired';

  final String code;
  final int? status;

  /// From `Retry-After` on `429 rate_limited`.
  final Duration? retryAfter;
  final Map<String, Object?> details;

  bool get isNetwork => code == offline || code == timeout;

  /// Anything that looks like code or a stack trace is never shown.
  static final _technical = RegExp(
    r'[\[\]{}<>\\\n]|SQL|Exception|Error:|::|\.php',
  );

  /// Builds the error for an HTTP error response.
  factory ApiError.fromResponse(
    int status,
    Object? body, {
    String? retryAfterHeader,
  }) {
    final error = body is Map ? body['error'] : null;
    final code = error is Map && error['code'] is String
        ? error['code'] as String
        : (status >= 500 ? 'server_error' : badResponse);
    final serverMessage = error is Map && error['message'] is String
        ? error['message'] as String
        : null;
    final details = error is Map && error['details'] is Map
        ? Map<String, Object?>.from(error['details'] as Map)
        : const <String, Object?>{};
    final seconds = int.tryParse(retryAfterHeader?.trim() ?? '');
    final retryAfter = seconds == null || seconds < 0
        ? null
        : Duration(seconds: seconds);
    return ApiError(
      messageFor(
        code,
        status: status,
        serverMessage: serverMessage,
        retryAfter: retryAfter,
        details: details,
      ),
      code: code,
      status: status,
      retryAfter: retryAfter,
      details: details,
    );
  }

  /// Translates a Dio failure (no response, timeout, or an error status).
  factory ApiError.fromDio(DioException error) {
    final inner = error.error;
    if (inner is ApiError) return inner;
    final response = error.response;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiError(
          'The server is taking too long to answer. Try again in a moment.',
          code: timeout,
        );
      case DioExceptionType.connectionError:
        return const ApiError(
          'You seem to be offline. Check your connection and try again.',
          code: offline,
        );
      case DioExceptionType.badCertificate:
        return const ApiError(
          'This server’s security certificate isn’t trusted, so CIRCLE won’t connect.',
          code: untrusted,
        );
      case DioExceptionType.badResponse:
        if (response != null) {
          return ApiError.fromResponse(
            response.statusCode ?? 0,
            response.data,
            retryAfterHeader: response.headers.value('retry-after'),
          );
        }
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
    }
    if (inner is FormatException) {
      return const ApiError(
        'The server sent something unexpected. Please try again later.',
        code: badResponse,
      );
    }
    return const ApiError(
      'You seem to be offline. Check your connection and try again.',
      code: offline,
    );
  }

  /// Calm words for each contract error code.
  static String messageFor(
    String code, {
    int? status,
    String? serverMessage,
    Duration? retryAfter,
    Map<String, Object?> details = const {},
  }) {
    switch (code) {
      case 'validation_error':
        final text = serverMessage?.trim() ?? '';
        // Field messages are short and written for people; anything else
        // gets the general wording.
        return text.isNotEmpty &&
                text.length <= 160 &&
                !_technical.hasMatch(text)
            ? text
            : 'Please check what you entered and try again.';
      case 'invalid_cursor':
        return 'Your list changed. Pull down to refresh it.';
      case 'unauthorized':
      case 'invalid_token':
      case sessionExpired:
        return 'Your session ended. Please log in again.';
      case 'invalid_credentials':
        return 'That mobile number and password didn’t work. Check them and try again.';
      case 'account_inactive':
        return 'This account can’t be used right now.';
      case 'forbidden':
        return 'Only admins of this group can do that.';
      case 'not_member':
        return 'This group isn’t shared with you.';
      case 'not_found':
        return 'That’s no longer available.';
      case 'member_not_found':
        return 'That person isn’t in this group any more.';
      case 'owner_protected':
        return 'The owner stays in the group. Transfer ownership first.';
      case 'last_admin':
        return 'Make someone else an admin first.';
      case 'subgroup_handover_required':
        final names = [
          for (final group in (details['groups'] as List?) ?? const [])
            if (group is Map && group['name'] is String) group['name'],
        ];
        return names.isEmpty
            ? 'Hand over the subgroups they look after first.'
            : 'Hand over ${names.join(', ')} first: you own or are the only admin there.';
      case 'depth_limit':
        return 'Groups can nest up to 10 levels.';
      case 'already_member':
        return 'You’re already in this group.';
      case 'not_parent_member':
        return 'Join the group it belongs to first.';
      case 'join_not_allowed':
        return 'You can’t join this group with this link. Ask an admin for help.';
      case 'link_revoked':
        return 'This invite link was turned off.';
      case 'link_expired':
        return 'This invite link has expired.';
      case 'link_exhausted':
        return 'This invite link has been used up.';
      case 'conflict':
        return 'This changed in the meantime. Refresh and try again.';
      case 'rate_limited':
        final seconds = retryAfter?.inSeconds;
        return seconds == null || seconds <= 0
            ? 'You’re going a little fast. Try again in a moment.'
            : 'You’re going a little fast. Try again in '
                  '${seconds == 1 ? '1 second' : '$seconds seconds'}.';
      case 'media_too_large':
        return 'This photo is too large. Photos can be up to 15 MB.';
      case 'media_type_not_allowed':
        return 'This kind of photo isn’t supported. Use a JPEG, PNG or WebP photo.';
      case 'media_invalid':
        return 'This photo couldn’t be read. Try another one.';
      case 'media_limit_reached':
        return 'You have many photos waiting to be shared. Share or remove some first.';
      case 'upload_expired':
        return 'The upload took too long. Try again.';
      case 'media_link_invalid':
        return 'This photo link expired. Reopen the Memory.';
      case 'server_error':
        return status == 503
            ? 'The server can’t do this right now. Please try again later.'
            : 'Something went wrong on the server. Please try again later.';
      default:
        return 'That didn’t work. Please try again.';
    }
  }
}
