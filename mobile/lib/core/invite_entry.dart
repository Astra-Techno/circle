/// Converts supported invitations into internal routes, without changing the
/// configured API host or accepting arbitrary external destinations.
String? circleInviteDestination(Uri uri, {Uri? serverOrigin}) {
  if (uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.toString().contains(r'\')) {
    return null;
  }
  String? token;
  if (uri.scheme == 'circle' &&
      uri.host == 'invite' &&
      !uri.hasPort &&
      uri.pathSegments.length == 1) {
    token = uri.pathSegments.single;
  } else if (serverOrigin != null &&
      uri.scheme == 'https' &&
      uri.host == serverOrigin.host &&
      uri.port == serverOrigin.port &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'i') {
    token = uri.pathSegments.last;
  }
  return token != null && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(token)
      ? '/invite/$token'
      : null;
}
