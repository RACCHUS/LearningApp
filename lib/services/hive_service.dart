import 'package:hive/hive.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:path_provider/path_provider.dart';

class HiveService {
  Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    Hive.registerAdapter(LessonAdapter());
    Hive.registerAdapter(UserProgressAdapter());
  }

  Future<void> cacheLesson(Lesson lesson) async {
    final box = await Hive.openBox<Lesson>('lessons');
    await box.put(lesson.id, lesson);
  }

  Future<Lesson?> getLesson(String lessonId) async {
    final box = await Hive.openBox<Lesson>('lessons');
    return box.get(lessonId);
  }

  Future<void> cacheProgress(UserProgress progress) async {
    final box = await Hive.openBox<UserProgress>('progress');
    await box.put(progress.id, progress);
  }

  Future<List<UserProgress>> getProgress() async {
    final box = await Hive.openBox<UserProgress>('progress');
    return box.values.toList();
  }

  Future<void> clearProgress() async {
    final box = await Hive.openBox<UserProgress>('progress');
    await box.clear();
  }
}

class LessonAdapter extends TypeAdapter<Lesson> {
  @override
  final int typeId = 0;

  @override
  Lesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lesson(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      tags: (fields[3] as List).cast<String>(),
      createdBy: fields[4] as String,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Lesson obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.createdBy)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}

class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 1;

  @override
  UserProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgress(
      id: fields[0] as String,
      userId: fields[1] as String,
      lessonId: fields[2] as String,
      date: fields[3] as DateTime,
      questionsAnswered: fields[4] as int,
      correctCount: fields[5] as int,
      lessonCompleted: fields[6] as bool,
      studyTimeMinutes: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.lessonId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.questionsAnswered)
      ..writeByte(5)
      ..write(obj.correctCount)
      ..writeByte(6)
      ..write(obj.lessonCompleted)
      ..writeByte(7)
      ..write(obj.studyTimeMinutes);
  }
}
