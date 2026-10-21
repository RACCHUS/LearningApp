// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'reference_practice_json_chunker.dart';

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


/// Builds the Blob from independently bounded UTF-8 chunks. The browser
/// request happens synchronously from the final user-confirmation click.
/// No click occurs if parsing/size/encoding fails while collecting chunks.
void requestDownloadChunks({
  required String filename,
  required Iterable<String> chunks,
}) {
  final parts = <Object>[];
  for (final bytes in ReferencePracticeJsonChunker.encode(chunks)) {
    parts.add(bytes);
  }
  final blob = html.Blob(parts, 'application/json;charset=utf-8');
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
