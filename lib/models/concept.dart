class Concept {
  final String id;
  final String conceptText;
  final String? exampleText;
  final String createdBy;

  Concept({
    required this.id,
    required this.conceptText,
    this.exampleText,
    required this.createdBy,
  });

  factory Concept.fromJson(Map<String, dynamic> json) {
    return Concept(
      id: json['id'],
      conceptText: json['concept_text'],
      exampleText: json['example_text'],
      createdBy: json['created_by'],
    );
  }
}
