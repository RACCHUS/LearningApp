// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Concept _$ConceptFromJson(Map<String, dynamic> json) => Concept(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      conceptText: json['concept_text'] as String,
      exampleText: json['example_text'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ConceptToJson(Concept instance) => <String, dynamic>{
      'id': instance.id,
      'lesson_id': instance.lessonId,
      'concept_text': instance.conceptText,
      'example_text': instance.exampleText,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
    };
