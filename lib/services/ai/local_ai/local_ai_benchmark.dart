import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local record of how the built-in model performs here (plan v2.6
/// P4.1 "benchmark ... on supported devices"). Counts and timings only,
/// kept on this device, never sent anywhere.
class LocalAiBenchmark {
  const LocalAiBenchmark({
    this.runs = 0,
    this.failures = 0,
    this.recentMs = const [],
  });

  final int runs;
  final int failures;

  /// The last few summary times in milliseconds (newest last).
  final List<int> recentMs;

  static const _key = 'local_ai_benchmark_v1';
  static const _keep = 10;

  int? get medianMs {
    if (recentMs.isEmpty) return null;
    final sorted = [...recentMs]..sort();
    return sorted[sorted.length ~/ 2];
  }

  LocalAiBenchmark recordSuccess(Duration took) => LocalAiBenchmark(
    runs: runs + 1,
    failures: failures,
    recentMs: [...recentMs, took.inMilliseconds].reversed
        .take(_keep)
        .toList()
        .reversed
        .toList(),
  );

  LocalAiBenchmark recordFailure() => LocalAiBenchmark(
    runs: runs + 1,
    failures: failures + 1,
    recentMs: recentMs,
  );

  Map<String, Object> toJson() => {
    'runs': runs,
    'failures': failures,
    'recent_ms': recentMs,
  };

  static LocalAiBenchmark fromJson(Object? json) {
    if (json is! Map) return const LocalAiBenchmark();
    final recent = json['recent_ms'];
    return LocalAiBenchmark(
      runs: json['runs'] is int ? json['runs'] as int : 0,
      failures: json['failures'] is int ? json['failures'] as int : 0,
      recentMs: recent is List ? recent.whereType<int>().toList() : const [],
    );
  }

  static Future<LocalAiBenchmark> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return raw == null ? const LocalAiBenchmark() : fromJson(jsonDecode(raw));
    } catch (_) {
      return const LocalAiBenchmark();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }
}
