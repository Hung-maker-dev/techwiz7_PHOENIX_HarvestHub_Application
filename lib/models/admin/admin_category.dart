class AdminCategory {
  final String id;
  final String name;
  final String? nameEn;
  final int displayOrder;
  final bool isActive;

  const AdminCategory({
    required this.id,
    required this.name,
    this.nameEn,
    required this.displayOrder,
    required this.isActive,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) => AdminCategory(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        nameEn: (json['nameEn'] ?? json['name_en']) as String?,
        displayOrder:
            (json['displayOrder'] ?? json['display_order'] ?? 0) as int,
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'nameEn': nameEn,
        'displayOrder': displayOrder,
        'isActive': isActive,
      };

  AdminCategory copyWith({int? displayOrder}) => AdminCategory(
        id: id,
        name: name,
        nameEn: nameEn,
        displayOrder: displayOrder ?? this.displayOrder,
        isActive: isActive,
      );
}
