// Backwards-compatible import shim for the canonical lesson progress model.
//
// ANA-001B: `lesson_progress.dart` owns the single UserProgress/StudyMode
// implementation. Keep this export while legacy callers migrate their imports.
// Hive and remote JSON serialization remain distinct follow-up work.
export 'lesson_progress.dart' show UserProgress, StudyMode;
