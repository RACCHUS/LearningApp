/// Thrown when a model fails to deserialize from JSON.
///
/// Carries the model name and the specific field(s) at fault so production
/// logs are actionable instead of a generic "null value" message.
class ModelParseException implements Exception {
  final String model;
  final String reason;
  final List<String> fields;

  const ModelParseException(
    this.model,
    this.reason, {
    this.fields = const [],
  });

  @override
  String toString() {
    final fieldPart = fields.isEmpty ? '' : ' (fields: ${fields.join(', ')})';
    return 'ModelParseException[$model]: $reason$fieldPart';
  }
}
