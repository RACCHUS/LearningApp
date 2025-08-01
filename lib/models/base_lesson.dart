import 'package:flutter/foundation.dart';

/// Abstract base class for all lesson types
/// Note: Concrete implementations should have their own Hive type IDs
abstract class BaseLesson {
  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const BaseLesson({
    required this.id,
    required this.title,
    this.description,
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
          listEquals(tags, other.tags) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      tags.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode;
}
