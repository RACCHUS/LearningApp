import 'reference_practice_json_download_stub.dart'
    if (dart.library.html) 'reference_practice_json_download_web.dart'
    as download_platform;

/// Requests a browser-owned .json file download after an explicit user action.
/// The browser, not the app, controls the destination and final save outcome.
/// Non-web targets deliberately keep the clipboard-only fallback.
class ReferencePracticeJsonDownload {
  bool get isSupported => download_platform.isSupported;

  static String filenameAt(DateTime timestamp) {
    final t = timestamp.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'learningapp-exm-reference-practice-'
        '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z.json';
  }

  /// Call directly from a real user click. Throws synchronously if unsupported
  /// or if browser initiation failed; success only means a download REQUEST.
  void requestDownload({
    required String filename,
    required String json,
  }) {
    if (!isSupported) {
      throw UnsupportedError('Native download not supported on this platform');
    }
    if (!RegExp(r'^learningapp-exm-reference-practice-\d{8}T\d{6}Z\.json$')
        .hasMatch(filename)) {
      throw const FormatException('Invalid non-sensitive export filename');
    }
    if (json.isEmpty) {
      throw const FormatException('Empty reference-practice export');
    }
    download_platform.requestDownload(filename: filename, json: json);
  }
}
