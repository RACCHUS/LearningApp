class CatalogCluster {
  final String id;
  final String slug;
  final String title;
  final String? description;
  final String? emoji;
  final String? icon;
  final String? accentColor;
  final int sortOrder;
  final bool isActive;

  const CatalogCluster({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.emoji,
    this.icon,
    this.accentColor,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CatalogCluster.fromJson(Map<String, dynamic> json) {
    return CatalogCluster(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      icon: json['icon'] as String?,
      accentColor: json['accent_color'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'description': description,
    'emoji': emoji,
    'icon': icon,
    'accent_color': accentColor,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}
