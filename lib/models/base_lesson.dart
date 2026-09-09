import 'package:flutter/foundation.dart';

/// Abstract base class for all lesson types
/// Note: Concrete implementations should have their own Hive type IDs
abstract class BaseLesson {
  final String id;
  final String title;
  final String? description;
  final String? emoji;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const BaseLesson({
    required this.id,
    required this.title,
    this.description,
    this.emoji,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  // Copy with method to be implemented by subclasses
  BaseLesson copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  });

  // Compare lessons for equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseLesson &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          emoji == other.emoji &&
          listEquals(tags, other.tags) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      emoji.hashCode ^
      tags.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode;
}
