// This file provides a fallback implementation for non-web platforms.
Future<bool> shareText(String text, {String? title}) async {
  // Not supported on this platform
  return false;
}
