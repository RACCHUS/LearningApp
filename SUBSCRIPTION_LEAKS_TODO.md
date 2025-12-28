# Subscription Leaks Outside Voice System Scope

This document tracks potential subscription leaks identified during the voice system review that are outside the voice system scope.

## Overview

During the comprehensive voice system review, several `.listen()` calls were identified that don't store their subscriptions for proper cancellation. While not directly related to voice functionality, these represent potential memory leaks.

---

## Identified Issues

### 1. `lib/services/connectivity_service.dart` (Line ~40)

**Status:** ⚠️ Low Priority (Singleton pattern)

```dart
_connectivity.onConnectivityChanged.listen((result) async {
  await _checkConnectivityWithRetry();
});
```

**Analysis:** This is a singleton service that lives for the app's entire lifecycle. The subscription persists until app termination, so this is acceptable behavior.

**Action:** None required - intentional design for app-level singleton.

---

### 2. `lib/services/push_notification_service.dart` (Line ~20)

**Status:** ⚠️ Low Priority (Singleton pattern)

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // handle message
});
```

**Analysis:** Push notification service is typically a singleton that runs for the app's entire lifecycle.

**Action:** None required - intentional design for app-level singleton.

---

## Already Fixed

The following files were fixed as part of the voice system review:

| File | Issue | Fix Applied |
|------|-------|-------------|
| `lib/providers/offline_provider.dart` | Missing subscription storage | Added `_connectivitySubscription` with dispose |
| `lib/providers/audio_provider.dart` | 2 listeners without storage | Added `_audioSubscription`, `_voiceSubscription` |
| `lib/providers/audio_lesson_provider.dart` | 3 listeners without storage | Added subscriptions for all 3 notifiers |
| `lib/providers/global_voice_provider.dart` | 3 listeners without storage | Added 3 subscriptions with dispose |
| `lib/providers/hands_free_settings_provider.dart` | 2 listeners without storage | Added 2 subscriptions with dispose |
| `lib/services/voice_input_service.dart` | 1 listener without storage | Added `_providerChangesSubscription` |

---

## Best Practices

When adding new stream listeners in StateNotifier providers:

1. **Store the subscription:**
   ```dart
   StreamSubscription<T>? _subscription;
   ```

2. **Assign during listen:**
   ```dart
   _subscription = stream.listen((data) { ... });
   ```

3. **Cancel in dispose:**
   ```dart
   @override
   void dispose() {
     _subscription?.cancel();
     super.dispose();
   }
   ```

---

*Last Updated: December 27, 2025*
