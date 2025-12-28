/// Web Speech API conditional exports
///
/// This file conditionally exports the appropriate implementation based on platform:
/// - web_speech_api_web.dart for web platforms (uses dart:js_interop)
/// - web_speech_api_stub.dart for non-web platforms (VM tests, mobile, etc.)

export 'web_speech_api_stub.dart'
    if (dart.library.js_interop) 'web_speech_api_web.dart';
