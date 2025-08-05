// This file contains the implementation for web sharing.
import 'dart:html' as html;

Future<bool> shareText(String text, {String? title}) async {
  try {
    await html.window.navigator.share({
      'title': title ?? '',
      'text': text,
    });
    return true;
  } catch (_) {
    // User cancelled or not supported
    return false;
  }
}
