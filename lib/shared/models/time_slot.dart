/// A computed time slot (not stored in DB).
/// Generated dynamically from court configuration.
class TimeSlot {
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"

  const TimeSlot({
    required this.startTime,
    required this.endTime,
  });

  String get timeRange => '$startTime - $endTime';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => startTime.hashCode ^ endTime.hashCode;
}
