class AmbulanceModel {
  final String id;
  final String playerId;
  final String reason;
  final DateTime activatedAt;
  final int positionAtActivation;
  final bool initialPenaltyApplied;
  final DateTime? protectionEndsAt;
  final DateTime? deactivatedAt;
  final bool isActive;
  final int dailyPenaltiesApplied;
  final DateTime? lastDailyPenaltyAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AmbulanceModel({
    required this.id,
    required this.playerId,
    required this.reason,
    required this.activatedAt,
    required this.positionAtActivation,
    this.initialPenaltyApplied = false,
    this.protectionEndsAt,
    this.deactivatedAt,
    this.isActive = true,
    this.dailyPenaltiesApplied = 0,
    this.lastDailyPenaltyAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProtected =>
      isActive &&
      protectionEndsAt != null &&
      protectionEndsAt!.isAfter(DateTime.now());

  int get daysActive => DateTime.now().difference(activatedAt).inDays;

  factory AmbulanceModel.fromJson(Map<String, dynamic> json) {
    return AmbulanceModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      reason: json['reason'] as String,
      activatedAt: DateTime.parse(json['activated_at'] as String),
      positionAtActivation: json['position_at_activation'] as int,
      initialPenaltyApplied:
          json['initial_penalty_applied'] as bool? ?? false,
      protectionEndsAt: json['protection_ends_at'] != null
          ? DateTime.parse(json['protection_ends_at'] as String)
          : null,
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.parse(json['deactivated_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      dailyPenaltiesApplied:
          json['daily_penalties_applied'] as int? ?? 0,
      lastDailyPenaltyAt: json['last_daily_penalty_at'] != null
          ? DateTime.parse(json['last_daily_penalty_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'reason': reason,
      'activated_at': activatedAt.toIso8601String(),
      'position_at_activation': positionAtActivation,
      'initial_penalty_applied': initialPenaltyApplied,
      'protection_ends_at': protectionEndsAt?.toIso8601String(),
      'deactivated_at': deactivatedAt?.toIso8601String(),
      'is_active': isActive,
      'daily_penalties_applied': dailyPenaltiesApplied,
      'last_daily_penalty_at': lastDailyPenaltyAt?.toIso8601String(),
    };
  }
}
