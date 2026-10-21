/// Monotonic active-time source for a local practice countdown.
///
/// Pauses stop this clock. It does not persist across browser refreshes and
/// is not evidence of official examination timing or invigilation.
abstract class ExamPracticeElapsedClock {
  Duration get elapsed;
  void start();
  void stop();
  void reset();
}

/// Uses Stopwatch instead of counting periodic timer callbacks, which may
/// be delayed by tab suspension, background throttling or a busy event loop.
class StopwatchExamPracticeElapsedClock implements ExamPracticeElapsedClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();

  @override
  void reset() => _stopwatch.reset();
}
