/// Central registry of Hive `typeId` values.
///
/// The values below reflect the REAL persisted `typeId` baked into each
/// registered adapter. They are part of the on-disk data format: changing a
/// value requires a data migration, never a casual edit.
///
/// When adding a new Hive model:
///   1. Pick the next value from [freeIds] and add a named constant below.
///   2. Annotate the model with `@HiveType(typeId: HiveTypeIds.yourModel)`.
///   3. Register its adapter in `registerHiveAdapters()` guarded by the same id.
///
/// ⚠️ Legacy landmine: id **3** is used by BOTH the custom `ConceptAdapter`
/// (`concept_adapter.dart`, the one actually registered) and the generated
/// `QuestionAdapter` (`question.g.dart`). Only the concept adapter is
/// registered, so there is no runtime collision today, but do NOT register
/// `QuestionAdapter` without first reassigning one of them via a migration.
/// `Concept` is also annotated `@HiveType(7)` yet serialized through the custom
/// id-3 adapter, so id 7 currently has no live adapter.
class HiveTypeIds {
  HiveTypeIds._();

  static const int lesson = 0; // LessonAdapter (hive_service.dart)
  static const int userProgress = 1; // UserProgressAdapter (hive_service.dart)
  static const int lessonContent = 2; // LessonContent (abstract base)
  static const int concept = 3; // custom ConceptAdapter (concept_adapter.dart)
  static const int mcq = 4; // McqAdapter
  static const int questionContent = 5; // QuestionContentAdapter
  static const int conceptContent = 6; // ConceptContentAdapter
  static const int termContent = 8; // TermContentAdapter
  static const int localLesson = 9; // LocalLessonAdapter
  static const int audioSettings = 20; // AudioSettingsAdapter
  static const int audioLessonSettings = 21; // AudioLessonSettingsAdapter

  /// Ids that are free for new models (gaps in the sequence above).
  static const List<int> freeIds = [7, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
}
