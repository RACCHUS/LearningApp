import 'base_lesson.dart';

class Lesson implements BaseLesson {
  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final String createdBy;
  @override
  final DateTime createdAt;
  
  @override
  bool get isLocal => false;

  Lesson({
    required this.id,
    required this.title,
    this.description,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      tags: List<String>.from(json['tags']),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
