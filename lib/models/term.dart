import 'package:learning_pwa/models/term_content.dart';

class Term {
  final String id;
  final String term;
  final String definition;
  final String? example;
  final String createdBy;

  Term({
    required this.id,
    required this.term,
    required this.definition,
    this.example,
    required this.createdBy,
  });

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      id: json['id'],
      term: json['term'],
      definition: json['definition'],
      example: json['example'],
      createdBy: json['created_by'],
    );
  }
  
  factory Term.fromTermContent(TermContent content) {
    return Term(
      id: content.id,
      term: content.term,
      definition: content.definition,
      example: content.example,
      createdBy: 'system', // Default value since TermContent doesn't have createdBy
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'term': term,
    'definition': definition,
    'example': example,
    'created_by': createdBy,
  };
}
