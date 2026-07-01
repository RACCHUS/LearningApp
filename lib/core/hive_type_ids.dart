/// Central registry of Hive `typeId` values.
///
/// Every `@HiveType(typeId: N)` in the app MUST use a value listed here, and
/// each value must be unique. Keeping them in one place prevents the silent
/// data-corruption that happens when two adapters share an id.
///
/// When adding a new Hive model:
///   1. Add a new constant below with the next free id.
///   2. Annotate the model with `@HiveType(typeId: HiveTypeIds.yourModel)`.
///   3. Register its adapter in `registerHiveAdapters()`.
class HiveTypeIds {
  HiveTypeIds._();

  static const int lesson = 0;
  static const int concept = 1; // custom ConceptAdapter
  static const int mcq = 2;
  static const int question = 3;
  static const int termContent = 4;
  static const int questionContent = 5;
  static const int conceptContent = 6;
  static const int conceptModel = 7; // Concept model (@HiveType 7)
  static const int termContentAlt = 8;
  static const int localLesson = 9;
  static const int audioSettings = 20;
  static const int audioLessonSettings = 21;

  /// Ids that are currently free for new models (gaps in the sequence above).
  static const List<int> freeIds = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
}
