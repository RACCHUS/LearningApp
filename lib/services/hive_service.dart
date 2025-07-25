import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_pwa/models/lesson.dart';

class HiveService {
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LessonAdapter());
  }

  Future<void> cacheLesson(Lesson lesson) async {
    final box = await Hive.openBox<Lesson>('lessons');
    await box.put(lesson.id, lesson);
  }

  Future<Lesson?> getLesson(String lessonId) async {
    final box = await Hive.openBox<Lesson>('lessons');
    return box.get(lessonId);
  }
}

class LessonAdapter extends TypeAdapter<Lesson> {
  @override
  final int typeId = 0;

  @override
  Lesson read(BinaryReader reader) {
    return Lesson.fromJson(Map<String, dynamic>.from(reader.read()));
  }

  @override
  void write(BinaryWriter writer, Lesson obj) {
    // This is not ideal, but it's a simple way to serialize for now.
    // A proper implementation would serialize each field.
    writer.write({
      'id': obj.id,
      'title': obj.title,
      'description': obj.description,
      'tags': obj.tags,
      'created_by': obj.createdBy,
      'created_at': obj.createdAt.toIso8601String(),
    });
  }
}
