class CanonicalField {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String fieldKind;
  final String? parentId;
  final int sortOrder;
  final bool isActive;

  const CanonicalField({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.fieldKind = 'broad_series',
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CanonicalField.fromJson(Map<String, dynamic> json) {
    return CanonicalField(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      fieldKind: json['field_kind'] as String? ?? 'broad_series',
      parentId: json['parent_id'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'icon': icon,
    'field_kind': fieldKind,
    'parent_id': parentId,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}
