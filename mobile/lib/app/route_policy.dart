/// Local prototype navigation policy, not a production authorization boundary.
/// Return destinations are restricted to known in-app routes.
String? safeReturnDestination(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.path.contains(r'\')) {
    return null;
  }
  const pages = {
    '/feed',
    '/create',
    '/groups',
    '/memories',
    '/friends',
    '/events',
    '/profile',
  };
  final detail = RegExp(r'^/(post|group|album|friend|event)/[A-Za-z0-9_-]+$');
  return pages.contains(uri.path) || detail.hasMatch(uri.path)
      ? uri.toString()
      : null;
}

String? invitationRedirect({required bool entered, required Uri location}) {
  final public = location.path == '/' || location.path == '/invite';
  if (!entered && !public) {
    final destination = safeReturnDestination(location.toString());
    return Uri(
      path: '/invite',
      queryParameters: destination == null ? null : {'next': destination},
    ).toString();
  }
  if (entered && public) {
    return safeReturnDestination(location.queryParameters['next']) ?? '/feed';
  }
  return null;
}
