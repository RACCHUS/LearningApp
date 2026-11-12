/// Validation for identifiers and pointers stored in learning-support
/// records (master plan v2.6 §10.5). These records must hold opaque IDs
/// and short cursors only: never answer keys, user text, secrets or URLs
/// with query strings.
class SupportIdentifiers {
  const SupportIdentifiers._();

  static const int maxIdLength = 128;
  static const int maxTokenLength = 64;
  static const int maxRouteLength = 256;

  static final RegExp _id = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:\-]*$');
  static final RegExp _token = RegExp(r'^[A-Za-z0-9._:\-]+$');
  static final RegExp _route = RegExp(r'^(/[A-Za-z0-9._\-]+)+/?$|^/$');

  /// An opaque record identifier, e.g. a UUID or `lesson_12`.
  static bool isId(Object? v) =>
      v is String && v.length <= maxIdLength && _id.hasMatch(v);

  /// A short cursor such as a step token or `step:3`.
  static bool isToken(Object? v) =>
      v is String && v.length <= maxTokenLength && _token.hasMatch(v);

  /// An in-app path such as `/lesson/abc`. Rejects schemes, hosts, query
  /// strings, fragments, `.`/`..` segments and empty segments.
  static bool isRoute(Object? v) {
    if (v is! String || v.length > maxRouteLength || !_route.hasMatch(v)) {
      return false;
    }
    for (final segment in v.split('/')) {
      if (segment == '.' || segment == '..') return false;
    }
    return true;
  }
}
