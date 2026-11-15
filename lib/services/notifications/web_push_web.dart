import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_push_types.dart';

const _scriptUrl = 'push_sw.js';
const _scope = './push/';

bool webPushSupported() {
  try {
    return web.window.navigator.has('serviceWorker') &&
        web.window.has('PushManager') &&
        web.window.has('Notification');
  } catch (_) {
    return false;
  }
}

String? browserTimeZone() {
  try {
    final intl = globalContext['Intl'] as JSObject;
    final format = intl.callMethod<JSObject>('DateTimeFormat'.toJS);
    final options = format.callMethod<JSObject>('resolvedOptions'.toJS);
    return (options['timeZone'] as JSString?)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<web.ServiceWorkerRegistration?> _existing() async {
  final reg = await web.window.navigator.serviceWorker
      .getRegistration(_scope)
      .toDart;
  return reg;
}

Future<WebPushSubscription?> currentWebPushSubscription() async {
  if (!webPushSupported()) return null;
  try {
    final reg = await _existing();
    if (reg == null) return null;
    final sub = await reg.pushManager.getSubscription().toDart;
    return sub == null ? null : _toDart(sub);
  } catch (_) {
    return null;
  }
}

Future<WebPushSubscribeResult> subscribeWebPush(String vapidPublicKey) async {
  if (!webPushSupported()) return const WebPushSubscribeResult.unsupported();
  try {
    final permission = await web.Notification.requestPermission().toDart;
    if (permission.toDart != 'granted') {
      return const WebPushSubscribeResult.denied();
    }
    final reg = await web.window.navigator.serviceWorker
        .register(_scriptUrl.toJS, web.RegistrationOptions(scope: _scope))
        .toDart;
    // pushManager.subscribe needs an active worker.
    for (var i = 0; i < 50 && reg.active == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final existing = await reg.pushManager.getSubscription().toDart;
    final sub = existing ??
        await reg.pushManager
            .subscribe(web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _base64UrlToBytes(vapidPublicKey).toJS,
            ))
            .toDart;
    final parsed = _toDart(sub);
    return parsed == null
        ? const WebPushSubscribeResult.failed()
        : WebPushSubscribeResult.subscribed(parsed);
  } catch (_) {
    return const WebPushSubscribeResult.failed();
  }
}

Future<String?> unsubscribeWebPush() async {
  try {
    final reg = await _existing();
    if (reg == null) return null;
    final sub = await reg.pushManager.getSubscription().toDart;
    if (sub == null) return null;
    final endpoint = sub.endpoint;
    await sub.unsubscribe().toDart;
    return endpoint;
  } catch (_) {
    return null;
  }
}

WebPushSubscription? _toDart(web.PushSubscription sub) {
  final p256dh = sub.getKey('p256dh');
  final auth = sub.getKey('auth');
  if (p256dh == null || auth == null) return null;
  return WebPushSubscription(
    endpoint: sub.endpoint,
    p256dh: _bytesToBase64Url(p256dh.toDart.asUint8List()),
    auth: _bytesToBase64Url(auth.toDart.asUint8List()),
  );
}

Uint8List _base64UrlToBytes(String value) =>
    base64Url.decode(base64Url.normalize(value.trim()));

String _bytesToBase64Url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
