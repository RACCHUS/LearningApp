import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'base_lesson.dart';

part 'local_lesson.g.dart';

@HiveType(typeId: 1)
class LocalLesson extends BaseLesson {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<String> tags;

  @HiveField(4)
  final bool isLocal;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final String userId;

  LocalLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.isLocal = true,
  }) : super(
          id: id,
          title: title,
          description: description,
          tags: tags,
          createdAt: createdAt,
          updatedAt: updatedAt,
          userId: userId,
        );

  factory LocalLesson.fromJson(Map<String, dynamic> json) {
    return LocalLesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userId: json['userId'] as String,
      isLocal: json['isLocal'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'isLocal': isLocal,
    };
  }

  @override
  LocalLesson copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    bool? isLocal,
  }) {
    return LocalLesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalLesson &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          listEquals(tags, other.tags) &&
          isLocal == other.isLocal &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      tags.hashCode ^
      isLocal.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode;
}
