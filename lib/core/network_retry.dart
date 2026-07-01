import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Retries an async operation with exponential backoff.
///
/// Retries on any exception except [ArgumentError] and [StateError],
/// which indicate programming errors rather than transient failures.
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  String? label,
}) async {
  assert(maxAttempts >= 1);
  var delay = initialDelay;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      // Don't retry programming errors
      if (e is ArgumentError || e is StateError) rethrow;

      if (attempt == maxAttempts) {
        debugPrint('❌ ${label ?? 'Operation'} failed after $maxAttempts attempts: $e');
        rethrow;
      }

      // Add jitter to prevent thundering herd
      final jitter = Duration(milliseconds: Random().nextInt(delay.inMilliseconds ~/ 2));
      final waitTime = delay + jitter;

      debugPrint('⚠️ ${label ?? 'Operation'} attempt $attempt failed, retrying in ${waitTime.inMilliseconds}ms: $e');
      await Future.delayed(waitTime);
      delay *= 2;
    }
  }

  // Unreachable, but satisfies the compiler
  throw StateError('retryWithBackoff: unreachable');
}
