import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Result returned when evaluating submission rate limits and spam heuristics.
class RateLimitResult {
  final bool isAllowed;
  final String? rejectionReason;
  final int? retryAfterSeconds;

  const RateLimitResult.allowed()
      : isAllowed = true,
        rejectionReason = null,
        retryAfterSeconds = null;

  const RateLimitResult.rejected({
    required this.rejectionReason,
    this.retryAfterSeconds,
  }) : isAllowed = false;
}

/// Client-side and in-service rate limiter enforcing community spam protections (ECO-01, Invariant 4).
///
/// Prevents spam floods and prompt-stuffing by enforcing:
/// 1. Maximum 5 questions per rolling hour per user.
/// 2. Maximum 10 answers per rolling hour per user.
/// 3. Character boundaries: Minimum 20 chars, Maximum 1,000 characters.
/// 4. Duplicate submission fingerprinting via normalized SHA-256 content hashes.
class SpamRateLimiter {
  final int maxQuestionsPerHour;
  final int maxAnswersPerHour;
  final int minContentLength;
  final int maxContentLength;
  final Duration windowDuration;

  final Map<String, List<DateTime>> _questionTimestamps = {};
  final Map<String, List<DateTime>> _answerTimestamps = {};
  final Map<String, Set<String>> _recentContentHashes = {};

  SpamRateLimiter({
    this.maxQuestionsPerHour = 5,
    this.maxAnswersPerHour = 10,
    this.minContentLength = 20,
    this.maxContentLength = 1000,
    this.windowDuration = const Duration(hours: 1),
  });

  /// Validates a question submission against length, duplicate, and hourly limits.
  RateLimitResult validateQuestionSubmission({
    required String userId,
    required String title,
    required String body,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    // Check length bounds
    final combinedLength = (title.trim().length + body.trim().length);
    if (combinedLength < minContentLength) {
      return RateLimitResult.rejected(
        rejectionReason: 'Content too brief. Questions must contain at least $minContentLength characters.',
      );
    }
    if (combinedLength > maxContentLength) {
      return RateLimitResult.rejected(
        rejectionReason: 'Content exceeds character limit ($combinedLength / $maxContentLength characters).',
      );
    }

    // Check duplicate content
    final hash = _computeNormalizedHash('$title $body');
    final userHashes = _recentContentHashes[userId] ?? const {};
    if (userHashes.contains(hash)) {
      return const RateLimitResult.rejected(
        rejectionReason: 'Duplicate submission detected. Please do not submit identical content.',
      );
    }

    // Check hourly limit
    _pruneOldTimestamps(_questionTimestamps[userId], effectiveNow);
    final recentCount = _questionTimestamps[userId]?.length ?? 0;
    if (recentCount >= maxQuestionsPerHour) {
      final oldestInWindow = _questionTimestamps[userId]!.first;
      final retryAfter = windowDuration.inSeconds - effectiveNow.difference(oldestInWindow).inSeconds;
      return RateLimitResult.rejected(
        rejectionReason: 'Question rate limit exceeded ($maxQuestionsPerHour/hour). Please wait before posting again.',
        retryAfterSeconds: retryAfter > 0 ? retryAfter : 60,
      );
    }

    return const RateLimitResult.allowed();
  }

  /// Validates an answer submission against length, duplicate, and hourly limits.
  RateLimitResult validateAnswerSubmission({
    required String userId,
    required String body,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    // Check length bounds
    final trimmedLength = body.trim().length;
    if (trimmedLength < minContentLength) {
      return RateLimitResult.rejected(
        rejectionReason: 'Answer too brief. Please provide a substantive response (min $minContentLength chars).',
      );
    }
    if (trimmedLength > maxContentLength) {
      return RateLimitResult.rejected(
        rejectionReason: 'Answer exceeds character limit ($trimmedLength / $maxContentLength characters).',
      );
    }

    // Check duplicate content
    final hash = _computeNormalizedHash(body);
    final userHashes = _recentContentHashes[userId] ?? const {};
    if (userHashes.contains(hash)) {
      return const RateLimitResult.rejected(
        rejectionReason: 'Duplicate answer detected. You have already posted this response.',
      );
    }

    // Check hourly limit
    _pruneOldTimestamps(_answerTimestamps[userId], effectiveNow);
    final recentCount = _answerTimestamps[userId]?.length ?? 0;
    if (recentCount >= maxAnswersPerHour) {
      final oldestInWindow = _answerTimestamps[userId]!.first;
      final retryAfter = windowDuration.inSeconds - effectiveNow.difference(oldestInWindow).inSeconds;
      return RateLimitResult.rejected(
        rejectionReason: 'Answer rate limit exceeded ($maxAnswersPerHour/hour). Please wait before posting again.',
        retryAfterSeconds: retryAfter > 0 ? retryAfter : 60,
      );
    }

    return const RateLimitResult.allowed();
  }

  /// Records a successful question submission to advance rate limiting windows.
  void recordQuestionSubmission({
    required String userId,
    required String title,
    required String body,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    _questionTimestamps.putIfAbsent(userId, () => []).add(effectiveNow);
    final hash = _computeNormalizedHash('$title $body');
    _recentContentHashes.putIfAbsent(userId, () => {}).add(hash);
  }

  /// Records a successful answer submission to advance rate limiting windows.
  void recordAnswerSubmission({
    required String userId,
    required String body,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    _answerTimestamps.putIfAbsent(userId, () => []).add(effectiveNow);
    final hash = _computeNormalizedHash(body);
    _recentContentHashes.putIfAbsent(userId, () => {}).add(hash);
  }

  void _pruneOldTimestamps(List<DateTime>? timestamps, DateTime now) {
    if (timestamps == null) return;
    timestamps.removeWhere((t) => now.difference(t) > windowDuration);
  }

  String _computeNormalizedHash(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  void reset() {
    _questionTimestamps.clear();
    _answerTimestamps.clear();
    _recentContentHashes.clear();
  }
}
