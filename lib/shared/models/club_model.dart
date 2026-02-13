class ClubModel {
  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClubModel({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      inviteCode: json['invite_code'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'invite_code': inviteCode,
      'avatar_url': avatarUrl,
      'created_by': createdBy,
    };
  }
}
