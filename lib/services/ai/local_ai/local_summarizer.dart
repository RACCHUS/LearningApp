import 'local_summarizer_stub.dart'
    if (dart.library.js_interop) 'local_summarizer_web.dart'
    as impl;

/// On-device summarizing through the browser's built-in model (master plan
/// v2.6 P4.1 local AI experiment). Today that is Chrome's Summarizer API
/// (Chrome 138+ on desktop, Gemini Nano). Everywhere else it reports
/// [LocalAiAvailability.unsupported] and the app shows nothing.
enum LocalAiAvailability {
  /// No built-in model API in this browser or device.
  unsupported,

  /// The API exists but this device cannot run the model.
  unavailable,

  /// The model must be downloaded first (needs a tap from the learner).
  downloadable,

  /// The browser is downloading it.
  downloading,

  /// Ready on this device.
  available;

  bool get usable =>
      this == downloadable || this == downloading || this == available;

  static LocalAiAvailability parse(String? raw) => switch (raw) {
    'available' => available,
    'downloadable' => downloadable,
    'downloading' => downloading,
    'unavailable' => unavailable,
    _ => unsupported,
  };
}

abstract class LocalSummarizer {
  Future<LocalAiAvailability> availability();

  /// Up to 5 key points as plain text, one per line. [onDownloadProgress]
  /// gets 0..1 while the model downloads. Must be called from a learner's
  /// tap when the model is not yet downloaded.
  Future<String> keyPoints(
    String text, {
    void Function(double fraction)? onDownloadProgress,
  });
}

/// The browser's built-in summarizer, or a stub that is always unsupported.
LocalSummarizer createLocalSummarizer() => impl.createLocalSummarizer();
