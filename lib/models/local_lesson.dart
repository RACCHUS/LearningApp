import 'package:learning_pwa/models/base_lesson.dart';

class LocalLesson implements BaseLesson {
  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final List<Map<String, dynamic>> content;
  @override
  final bool isLocal;
  @override
  final DateTime createdAt;

  LocalLesson({
    required this.id,
    required this.title,
    this.description,
    required this.tags,
    required this.content,
    this.isLocal = true,
    required this.createdAt,
  });

  factory LocalLesson.fromJson(Map<String, dynamic> json) {
    return LocalLesson(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      content: List<Map<String, dynamic>>.from(json['content'] ?? []),
      isLocal: json['isLocal'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'tags': tags,
      'content': content,
      'isLocal': isLocal,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
