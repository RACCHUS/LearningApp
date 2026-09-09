import 'dart:js_interop';

@JS('learningPwa')
external _LearningPwaApi? get _learningPwa;

extension type _LearningPwaApi(JSObject _) implements JSObject {
  external JSBoolean canInstall();
  external JSPromise<JSBoolean> promptInstall();
  external void dismiss();
  external void resetDismissed();
}

Future<bool> canInstallPwa() async {
  final api = _learningPwa;
  if (api == null) return false;
  try {
    return api.canInstall().toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> promptPwaInstall() async {
  final api = _learningPwa;
  if (api == null) return false;
  try {
    final result = await api.promptInstall().toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

Future<void> dismissPwaInstallPrompt() async {
  final api = _learningPwa;
  if (api == null) return;
  try {
    api.dismiss();
  } catch (_) {
    // Best-effort only.
  }
}

Future<void> resetPwaInstallPromptPreference() async {
  final api = _learningPwa;
  if (api == null) return;
  try {
    api.resetDismissed();
  } catch (_) {
    // Best-effort only.
  }
}
