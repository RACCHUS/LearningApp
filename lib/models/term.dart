import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/core/errors/model_parse_exception.dart';

class Term {
  final String id;
  final String term;
  final String definition;
  final String? example;
  final String? emoji;
  final String createdBy;

  Term({
    required this.id,
    required this.term,
    required this.definition,
    this.example,
    this.emoji,
    required this.createdBy,
  });

  factory Term.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final term = json['term']?.toString();
    final definition = json['definition']?.toString();
    final example = json['example']?.toString();
    final emoji = json['emoji']?.toString();
    // Accept both 'created_by' and 'user_id' for compatibility
    final createdBy = (json['created_by'] ?? json['user_id'])?.toString();
    final missing = <String>[
      if (id == null) 'id',
      if (term == null) 'term',
      if (definition == null) 'definition',
      if (createdBy == null) 'created_by',
    ];
    if (missing.isNotEmpty) {
      throw ModelParseException(
        'Term',
        'Missing required field(s)',
        fields: missing,
      );
    }
    return Term(
      id: id!,
      term: term!,
      definition: definition!,
      example: example,
      emoji: emoji,
      createdBy: createdBy!,
    );
  }
  
  factory Term.fromTermContent(TermContent content) {
    return Term(
      id: content.id,
      term: content.term,
      definition: content.definition,
      example: content.example,
      emoji: null,
      createdBy: 'system', // Default value since TermContent doesn't have createdBy
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'term': term,
    'definition': definition,
    'example': example,
    if (emoji != null) 'emoji': emoji,
    'created_by': createdBy,
  };
}
