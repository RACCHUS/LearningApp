import 'web_push_types.dart';

/// Non-web builds (VM tests, desktop): web push is unavailable.
bool webPushSupported() => false;

String? browserTimeZone() => null;

Future<WebPushSubscription?> currentWebPushSubscription() async => null;

Future<WebPushSubscribeResult> subscribeWebPush(String vapidPublicKey) async =>
    const WebPushSubscribeResult.unsupported();

Future<String?> unsubscribeWebPush() async => null;
