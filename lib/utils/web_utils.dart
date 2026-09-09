// This file implements conditional exports for web and stub.
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
