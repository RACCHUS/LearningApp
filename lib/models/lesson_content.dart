import 'package:hive/hive.dart';

/// Base class for all types of lesson content
@HiveType(typeId: 2)
abstract class LessonContent {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String lessonId;

  @HiveField(2)
  final int order;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  const LessonContent({
    required this.id,
    required this.lessonId,
    required this.order,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonContent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          lessonId == other.lessonId &&
          order == other.order &&
          type == type &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      lessonId.hashCode ^
      order.hashCode ^
      type.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
