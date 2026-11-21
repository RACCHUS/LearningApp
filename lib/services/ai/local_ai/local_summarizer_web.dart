import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'local_summarizer.dart';

/// Chrome's built-in Summarizer API (developer.chrome.com/docs/ai/
/// summarizer-api). The same options go to availability() and create(), as
/// the docs require. The text never leaves the device: Chrome runs the
/// model locally and the app sends nothing anywhere.
LocalSummarizer createLocalSummarizer() => _ChromeSummarizer();

class _ChromeSummarizer implements LocalSummarizer {
  JSObject? get _api {
    try {
      if (!globalContext.has('Summarizer')) return null;
      return globalContext.getProperty<JSObject?>('Summarizer'.toJS);
    } catch (_) {
      return null;
    }
  }

  JSObject _options({void Function(double)? onProgress}) {
    final options = <String, Object>{
      'type': 'key-points',
      'format': 'plain-text',
      'length': 'medium',
      'expectedInputLanguages': ['en'],
      'outputLanguage': 'en',
      'sharedContext': 'A section of a study lesson for a learner.',
    }.jsify()! as JSObject;
    if (onProgress != null) {
      options.setProperty(
        'monitor'.toJS,
        ((JSObject monitor) {
          monitor.callMethod(
            'addEventListener'.toJS,
            'downloadprogress'.toJS,
            ((JSObject event) {
              final loaded = event.getProperty<JSAny?>('loaded'.toJS);
              final total = event.getProperty<JSAny?>('total'.toJS);
              var fraction = loaded is JSNumber ? loaded.toDartDouble : 0.0;
              // Older builds reported bytes with a total; newer ones 0..1.
              if (total is JSNumber && total.toDartDouble > 1) {
                fraction = fraction / total.toDartDouble;
              }
              onProgress(fraction.clamp(0.0, 1.0));
            }).toJS,
          );
        }).toJS,
      );
    }
    return options;
  }

  @override
  Future<LocalAiAvailability> availability() async {
    final api = _api;
    if (api == null) return LocalAiAvailability.unsupported;
    try {
      final result = await api
          .callMethod<JSPromise<JSString>>('availability'.toJS, _options())
          .toDart;
      return LocalAiAvailability.parse(result.toDart);
    } catch (_) {
      return LocalAiAvailability.unsupported;
    }
  }

  @override
  Future<String> keyPoints(
    String text, {
    void Function(double fraction)? onDownloadProgress,
  }) async {
    final api = _api;
    if (api == null) throw UnsupportedError('No built-in summarizer');
    final summarizer = await api
        .callMethod<JSPromise<JSObject>>(
          'create'.toJS,
          _options(onProgress: onDownloadProgress ?? (_) {}),
        )
        .toDart;
    try {
      final out = await summarizer
          .callMethod<JSPromise<JSString>>('summarize'.toJS, text.toJS)
          .toDart;
      return out.toDart;
    } finally {
      try {
        if (summarizer.has('destroy')) summarizer.callMethod('destroy'.toJS);
      } catch (_) {}
    }
  }
}
