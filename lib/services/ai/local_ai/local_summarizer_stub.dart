import 'local_summarizer.dart';

/// Non-web builds: no built-in browser model.
LocalSummarizer createLocalSummarizer() => _Unsupported();

class _Unsupported implements LocalSummarizer {
  @override
  Future<LocalAiAvailability> availability() async =>
      LocalAiAvailability.unsupported;

  @override
  Future<String> keyPoints(
    String text, {
    void Function(double fraction)? onDownloadProgress,
  }) => throw UnsupportedError('No on-device model in this build');
}
