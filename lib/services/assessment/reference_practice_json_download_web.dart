// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

const bool isSupported = true;

/// Browser download is requested synchronously within the original user
/// gesture. Neither the app nor the browser API confirms that the user saved
/// the file. Keep the object URL briefly to allow the browser to read it.
void requestDownload({required String filename, required String json}) {
  final bytes = Uint8List.fromList(utf8.encode(json));
  final blob = html.Blob(<Object>[bytes], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement? anchor;
  try {
    anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
  } finally {
    anchor?.remove();
    Timer(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
  }
}
