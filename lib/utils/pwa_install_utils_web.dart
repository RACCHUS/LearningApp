import 'dart:js_util' as js_util;
import 'dart:html' as html;

Object? _pwaApi() {
  if (!js_util.hasProperty(html.window, 'learningPwa')) return null;
  return js_util.getProperty(html.window, 'learningPwa');
}

Future<bool> canInstallPwa() async {
  final api = _pwaApi();
  if (api == null) return false;
  try {
    return js_util.callMethod<bool>(api, 'canInstall', const []) ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> promptPwaInstall() async {
  final api = _pwaApi();
  if (api == null) return false;
  try {
    final result = js_util.callMethod<Object?>(api, 'promptInstall', const []);
    if (result == null) return false;
    final resolved = await js_util.promiseToFuture<Object?>(result);
    return resolved == true;
  } catch (_) {
    return false;
  }
}

Future<void> dismissPwaInstallPrompt() async {
  final api = _pwaApi();
  if (api == null) return;
  try {
    js_util.callMethod<void>(api, 'dismiss', const []);
  } catch (_) {
    // Best-effort only.
  }
}

Future<void> resetPwaInstallPromptPreference() async {
  final api = _pwaApi();
  if (api == null) return;
  try {
    js_util.callMethod<void>(api, 'resetDismissed', const []);
  } catch (_) {
    // Best-effort only.
  }
}
