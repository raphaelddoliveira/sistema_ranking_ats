import 'enums.dart';

class PlayerModel {
  final String id;
  final String authId;
  final String fullName;
  final String? nickname;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final PlayerRole role;
  final PlayerStatus status;
  final int? rankingPosition;
  final int challengesThisMonth;
  final DateTime? lastChallengeDate;
  final DateTime? challengerCooldownUntil;
  final DateTime? challengedProtectionUntil;
  final bool ambulanceActive;
  final DateTime? ambulanceStartedAt;
  final DateTime? ambulanceProtectionUntil;
  final bool mustBeChallengedFirst;
  final PaymentStatus feeStatus;
  final DateTime? feeDueDate;
  final DateTime? feeOverdueSince;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerModel({
    required this.id,
    required this.authId,
    required this.fullName,
    this.nickname,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.role = PlayerRole.player,
    this.status = PlayerStatus.active,
    this.rankingPosition,
    this.challengesThisMonth = 0,
    this.lastChallengeDate,
    this.challengerCooldownUntil,
    this.challengedProtectionUntil,
    this.ambulanceActive = false,
    this.ambulanceStartedAt,
    this.ambulanceProtectionUntil,
    this.mustBeChallengedFirst = false,
    this.feeStatus = PaymentStatus.pending,
    this.feeDueDate,
    this.feeOverdueSince,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == PlayerRole.admin;
  bool get isActive => status == PlayerStatus.active;
  bool get isOnAmbulance => status == PlayerStatus.ambulance;
  bool get hasFeeOverdue => feeStatus == PaymentStatus.overdue;

  bool get isOnCooldown =>
      challengerCooldownUntil != null &&
      challengerCooldownUntil!.isAfter(DateTime.now());

  bool get isProtected =>
      challengedProtectionUntil != null &&
      challengedProtectionUntil!.isAfter(DateTime.now());

  PlayerModel copyWith({
    String? id,
    String? authId,
    String? fullName,
    String? nickname,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    PlayerRole? role,
    PlayerStatus? status,
    int? rankingPosition,
    int? challengesThisMonth,
    DateTime? lastChallengeDate,
    DateTime? challengerCooldownUntil,
    DateTime? challengedProtectionUntil,
    bool? ambulanceActive,
    DateTime? ambulanceStartedAt,
    DateTime? ambulanceProtectionUntil,
    bool? mustBeChallengedFirst,
    PaymentStatus? feeStatus,
    DateTime? feeDueDate,
    DateTime? feeOverdueSince,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      status: status ?? this.status,
      rankingPosition: rankingPosition ?? this.rankingPosition,
      challengesThisMonth: challengesThisMonth ?? this.challengesThisMonth,
      lastChallengeDate: lastChallengeDate ?? this.lastChallengeDate,
      challengerCooldownUntil:
          challengerCooldownUntil ?? this.challengerCooldownUntil,
      challengedProtectionUntil:
          challengedProtectionUntil ?? this.challengedProtectionUntil,
      ambulanceActive: ambulanceActive ?? this.ambulanceActive,
      ambulanceStartedAt: ambulanceStartedAt ?? this.ambulanceStartedAt,
      ambulanceProtectionUntil:
          ambulanceProtectionUntil ?? this.ambulanceProtectionUntil,
      mustBeChallengedFirst:
          mustBeChallengedFirst ?? this.mustBeChallengedFirst,
      feeStatus: feeStatus ?? this.feeStatus,
      feeDueDate: feeDueDate ?? this.feeDueDate,
      feeOverdueSince: feeOverdueSince ?? this.feeOverdueSince,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      fullName: json['full_name'] as String,
      nickname: json['nickname'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      role: PlayerRole.fromString(json['role'] as String),
      status: PlayerStatus.fromString(json['status'] as String),
      rankingPosition: json['ranking_position'] as int?,
      challengesThisMonth: json['challenges_this_month'] as int? ?? 0,
      lastChallengeDate: json['last_challenge_date'] != null
          ? DateTime.parse(json['last_challenge_date'] as String)
          : null,
      challengerCooldownUntil: json['challenger_cooldown_until'] != null
          ? DateTime.parse(json['challenger_cooldown_until'] as String)
          : null,
      challengedProtectionUntil: json['challenged_protection_until'] != null
          ? DateTime.parse(json['challenged_protection_until'] as String)
          : null,
      ambulanceActive: json['ambulance_active'] as bool? ?? false,
      ambulanceStartedAt: json['ambulance_started_at'] != null
          ? DateTime.parse(json['ambulance_started_at'] as String)
          : null,
      ambulanceProtectionUntil: json['ambulance_protection_until'] != null
          ? DateTime.parse(json['ambulance_protection_until'] as String)
          : null,
      mustBeChallengedFirst:
          json['must_be_challenged_first'] as bool? ?? false,
      feeStatus:
          PaymentStatus.fromString(json['fee_status'] as String? ?? 'pending'),
      feeDueDate: json['fee_due_date'] != null
          ? DateTime.parse(json['fee_due_date'] as String)
          : null,
      feeOverdueSince: json['fee_overdue_since'] != null
          ? DateTime.parse(json['fee_overdue_since'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'full_name': fullName,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'role': role.name,
      'status': status.name,
      'ranking_position': rankingPosition,
      'challenges_this_month': challengesThisMonth,
      'last_challenge_date': lastChallengeDate?.toIso8601String(),
      'challenger_cooldown_until': challengerCooldownUntil?.toIso8601String(),
      'challenged_protection_until':
          challengedProtectionUntil?.toIso8601String(),
      'ambulance_active': ambulanceActive,
      'ambulance_started_at': ambulanceStartedAt?.toIso8601String(),
      'ambulance_protection_until':
          ambulanceProtectionUntil?.toIso8601String(),
      'must_be_challenged_first': mustBeChallengedFirst,
      'fee_status': feeStatus.name,
      'fee_due_date': feeDueDate?.toIso8601String().split('T').first,
      'fee_overdue_since': feeOverdueSince?.toIso8601String().split('T').first,
    };
  }

  /// Fields allowed for player self-update
  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'nickname': nickname,
      'phone': phone,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
    };
  }
}
