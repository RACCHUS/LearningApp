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
    print('DEBUG: Term.fromJson input: ' + json.toString());
    final id = json['id']?.toString();
    final term = json['term']?.toString();
    final definition = json['definition']?.toString();
    final example = json['example']?.toString();
    // Accept both 'created_by' and 'user_id' for compatibility
    final createdBy = (json['created_by'] ?? json['user_id'])?.toString();
    if (id == null || term == null || definition == null || createdBy == null) {
      print('ERROR: Null value in Term.fromJson fields. id: $id, term: $term, definition: $definition, createdBy: $createdBy');
      throw Exception('Null value in required Term field');
    }
    return Term(
      id: id,
      term: term,
      definition: definition,
      example: example,
      createdBy: createdBy,
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
