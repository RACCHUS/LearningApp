/// A browser push subscription, keys base64url-encoded as the Web Push
/// protocol and `register_push_subscription` expect.
class WebPushSubscription {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

enum WebPushSubscribeStatus { subscribed, denied, unsupported, failed }

class WebPushSubscribeResult {
  const WebPushSubscribeResult._(this.status, this.subscription);

  const WebPushSubscribeResult.subscribed(WebPushSubscription subscription)
      : this._(WebPushSubscribeStatus.subscribed, subscription);
  const WebPushSubscribeResult.denied()
      : this._(WebPushSubscribeStatus.denied, null);
  const WebPushSubscribeResult.unsupported()
      : this._(WebPushSubscribeStatus.unsupported, null);
  const WebPushSubscribeResult.failed()
      : this._(WebPushSubscribeStatus.failed, null);

  final WebPushSubscribeStatus status;
  final WebPushSubscription? subscription;
}
