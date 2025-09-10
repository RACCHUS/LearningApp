/// Stub implementation for browser compatibility when dart:html is not available
/// Used during testing on non-web platforms

class _Window {
  _Navigator get navigator => _Navigator();
  _Location get location => _Location();
  bool? get isSecureContext => true;
  _MediaQueryList matchMedia(String query) => _MediaQueryList();
}

class _Navigator {
  String get userAgent => 'test-user-agent';
}

class _Location {
  String get protocol => 'https:';
  String get hostname => 'localhost';
}

class _MediaQueryList {
  bool get matches => false;
}

final window = _Window();
