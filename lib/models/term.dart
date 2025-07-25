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
}
