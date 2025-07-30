// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcq.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Mcq _$McqFromJson(Map<String, dynamic> json) => Mcq(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctOptionIndex: json['correct_option_index'] as int,
      explanation: json['explanation'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$McqToJson(Mcq instance) => <String, dynamic>{
      'id': instance.id,
      'lesson_id': instance.lessonId,
      'question': instance.question,
      'options': instance.options,
      'correct_option_index': instance.correctOptionIndex,
      'explanation': instance.explanation,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
    };
