import 'dart:convert';
import 'dart:typed_data';

/// Bounds encoded download size and buffers many small JSON fragments into
/// reasonably sized UTF-8 byte segments for a browser Blob.
///
/// This prevents a *second* full JSON string in the Dart heap, but a browser
/// still has to hold the Blob. Oversized data fails before any download starts.
class ReferencePracticeJsonChunker {
  static const int defaultPartBytes = 64 * 1024;
  static const int defaultMaxBytes = 64 * 1024 * 1024;

  static Iterable<Uint8List> encode(
    Iterable<String> chunks, {
    int partBytes = defaultPartBytes,
    int maxBytes = defaultMaxBytes,
  }) sync* {
    if (partBytes < 1 || maxBytes < 1 || partBytes > maxBytes) {
      throw const FormatException('Invalid private export byte limits');
    }
    var totalBytes = 0;
    final builder = BytesBuilder(copy: false);
    for (final fragment in chunks) {
      if (fragment.isEmpty) continue;
      final bytes = utf8.encode(fragment);
      if (totalBytes + bytes.length > maxBytes) {
        throw StateError('Reference-practice JSON exceeds the safe '
            'in-browser file size; no download was requested.');
      }
      totalBytes += bytes.length;
      var offset = 0;
      while (offset < bytes.length) {
        final room = partBytes - builder.length;
        final end = offset + room < bytes.length
            ? offset + room
            : bytes.length;
        builder.add(bytes.sublist(offset, end));
        offset = end;
        if (builder.length == partBytes) {
          yield builder.takeBytes();
        }
      }
    }
    if (totalBytes == 0) {
      throw const FormatException('Empty private export cannot be saved');
    }
    if (builder.isNotEmpty) yield builder.takeBytes();
  }
}
