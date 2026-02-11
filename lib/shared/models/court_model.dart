class CourtModel {
  final String id;
  final String name;
  final String? surfaceType;
  final bool isCovered;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourtModel({
    required this.id,
    required this.name,
    this.surfaceType,
    this.isCovered = false,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  String get surfaceLabel => switch (surfaceType) {
        'saibro' => 'Saibro',
        'dura' => 'Quadra Dura',
        'grama' => 'Grama',
        'carpet' => 'Carpet',
        _ => surfaceType ?? 'N/A',
      };

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as String,
      name: json['name'] as String,
      surfaceType: json['surface_type'] as String?,
      isCovered: json['is_covered'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surface_type': surfaceType,
      'is_covered': isCovered,
      'is_active': isActive,
      'notes': notes,
    };
  }
}
