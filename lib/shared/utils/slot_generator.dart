import '../models/court_model.dart';
import '../models/time_slot.dart';

/// Generate time slots for a court on a given day of week.
/// Returns empty list if the court does not operate on that day.
List<TimeSlot> generateSlots(CourtModel court, int dayOfWeek) {
  if (!court.operatesOn(dayOfWeek)) return [];

  final openParts = court.openingTime.split(':');
  final closeParts = court.closingTime.split(':');
  final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
  final closeMinutes =
      int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
  final int duration = court.slotDurationMinutes;

  if (closeMinutes <= openMinutes || duration <= 0) return [];

  final slots = <TimeSlot>[];
  int current = openMinutes;
  while (current + duration <= closeMinutes) {
    final sH = current ~/ 60;
    final sM = current % 60;
    final eH = (current + duration) ~/ 60;
    final eM = (current + duration) % 60;
    slots.add(TimeSlot(
      startTime:
          '${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}',
      endTime:
          '${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}',
    ));
    current += duration;
  }
  return slots;
}
