/// Stub implementation for non-web platforms
/// This file is used when running on non-web platforms (VM tests, mobile, etc.)

/// Check if SpeechRecognition API is available - always false on non-web
bool get isSpeechRecognitionSupported => false;

/// Stub wrapper class for Web Speech API
class WebSpeechRecognition {
  bool get isListening => false;
  String? get lastResult => null;
  double get confidence => 0.0;
  String? get errorMessage => 'Web Speech API is only available on web platforms';

  Stream<SpeechResult> get onResult => const Stream.empty();
  Stream<String> get onError => const Stream.empty();
  Stream<void> get onEnd => const Stream.empty();

  bool initialize({String language = 'en-US', bool continuous = false}) {
    return false;
  }

  Future<bool> start() async => false;
  Future<void> stop() async {}
  void abort() {}
  void dispose() {}
}

/// Result from speech recognition
class SpeechResult {
  final String transcript;
  final double confidence;
  final bool isFinal;

  const SpeechResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
  });

  @override
  String toString() =>
      'SpeechResult(transcript: "$transcript", confidence: $confidence, isFinal: $isFinal)';
}
