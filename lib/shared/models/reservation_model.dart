import 'enums.dart';

class ReservationModel {
  final String id;
  final String courtSlotId;
  final String courtId;
  final String reservedBy;
  final DateTime reservationDate;
  final String startTime;
  final String endTime;
  final ReservationStatus status;
  final String? challengeId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? courtName;
  final String? playerName;

  const ReservationModel({
    required this.id,
    required this.courtSlotId,
    required this.courtId,
    required this.reservedBy,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.challengeId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.courtName,
    this.playerName,
  });

  bool get isConfirmed => status == ReservationStatus.confirmed;
  bool get isCancelled => status == ReservationStatus.cancelled;
  bool get isPast => reservationDate.isBefore(DateTime.now());

  String get timeRange {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '$start - $end';
  }

  String get formattedDate {
    final d = reservationDate;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final court = json['court'] as Map<String, dynamic>?;
    final player = json['player'] as Map<String, dynamic>?;

    return ReservationModel(
      id: json['id'] as String,
      courtSlotId: json['court_slot_id'] as String,
      courtId: json['court_id'] as String,
      reservedBy: json['reserved_by'] as String,
      reservationDate: DateTime.parse(json['reservation_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: ReservationStatus.fromString(json['status'] as String),
      challengeId: json['challenge_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      courtName: court?['name'] as String?,
      playerName: player?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'court_slot_id': courtSlotId,
      'court_id': courtId,
      'reserved_by': reservedBy,
      'reservation_date': '${reservationDate.year}-${reservationDate.month.toString().padLeft(2, '0')}-${reservationDate.day.toString().padLeft(2, '0')}',
      'start_time': startTime,
      'end_time': endTime,
      'status': status.name,
      if (challengeId != null) 'challenge_id': challengeId,
      if (notes != null) 'notes': notes,
    };
  }
}
