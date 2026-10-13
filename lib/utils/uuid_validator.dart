/// Utility to validate standard RFC 4122 UUID strings before sending them
/// to remote PostgreSQL/Supabase queries with UUID typed columns.
final RegExp _uuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Returns true if [value] is a valid non-null UUID string.
bool isValidUuid(String? value) {
  if (value == null || value.length != 36) return false;
  return _uuidRegex.hasMatch(value);
}
