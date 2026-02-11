import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/court_slot_model.dart';
import '../../../shared/models/reservation_model.dart';
import '../viewmodel/reservation_viewmodel.dart';

class CourtScheduleScreen extends ConsumerStatefulWidget {
  final CourtModel court;

  const CourtScheduleScreen({super.key, required this.court});

  @override
  ConsumerState<CourtScheduleScreen> createState() =>
      _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends ConsumerState<CourtScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    // Convert DateTime.weekday (1=Mon, 7=Sun) to DB format (0=Sun, 6=Sat)
    final dbDayOfWeek = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;

    final slotsAsync = ref.watch(courtSlotsProvider(
      (courtId: widget.court.id, dayOfWeek: dbDayOfWeek),
    ));
    final reservationsAsync = ref.watch(courtReservationsProvider(
      (courtId: widget.court.id, date: _selectedDate),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.court.name),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 7)),
            lastDay: DateTime.now().add(const Duration(days: 60)),
            focusedDay: _selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() => _selectedDate = selectedDay);
            },
            locale: 'pt_BR',
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withAlpha(60),
                shape: BoxShape.circle,
              ),
            ),
            availableCalendarFormats: const {
              CalendarFormat.week: 'Semana',
              CalendarFormat.twoWeeks: '2 Semanas',
              CalendarFormat.month: 'Mes',
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _formatDateLabel(_selectedDate),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  _dayOfWeekLabel(dbDayOfWeek),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: slotsAsync.when(
              data: (slots) {
                if (slots.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sem horarios disponiveis neste dia',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return reservationsAsync.when(
                  data: (reservations) => _SlotsGrid(
                    court: widget.court,
                    slots: slots,
                    reservations: reservations,
                    selectedDate: _selectedDate,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Erro ao carregar reservas'),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Erro ao carregar horarios'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _dayOfWeekLabel(int dow) {
    return switch (dow) {
      0 => 'Domingo',
      1 => 'Segunda-feira',
      2 => 'Terca-feira',
      3 => 'Quarta-feira',
      4 => 'Quinta-feira',
      5 => 'Sexta-feira',
      6 => 'Sabado',
      _ => '',
    };
  }
}

class _SlotsGrid extends ConsumerWidget {
  final CourtModel court;
  final List<CourtSlotModel> slots;
  final List<ReservationModel> reservations;
  final DateTime selectedDate;

  const _SlotsGrid({
    required this.court,
    required this.slots,
    required this.reservations,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final isPast = selectedDate.isBefore(DateTime(now.year, now.month, now.day));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final reservation = _findReservation(slot);
        final isReserved = reservation != null;

        final slotHour = int.tryParse(slot.startTime.split(':')[0]) ?? 0;
        final isSlotPast = isPast || (isToday && slotHour <= now.hour);

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isReserved
                    ? AppColors.error.withAlpha(20)
                    : isSlotPast
                        ? Colors.grey.shade100
                        : AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _formatTime(slot.startTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isReserved
                        ? AppColors.error
                        : isSlotPast
                            ? Colors.grey
                            : AppColors.success,
                  ),
                ),
              ),
            ),
            title: Text(
              slot.timeRange,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isReserved
                  ? 'Reservado - ${reservation.playerName ?? 'Jogador'}'
                  : isSlotPast
                      ? 'Horario passado'
                      : 'Disponivel',
              style: TextStyle(
                fontSize: 12,
                color: isReserved
                    ? AppColors.error
                    : isSlotPast
                        ? Colors.grey
                        : AppColors.success,
              ),
            ),
            trailing: !isReserved && !isSlotPast
                ? ElevatedButton(
                    onPressed: () =>
                        _confirmReservation(context, ref, slot),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Reservar',
                        style: TextStyle(fontSize: 13)),
                  )
                : isReserved
                    ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                    : null,
          ),
        );
      },
    );
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  ReservationModel? _findReservation(CourtSlotModel slot) {
    final slotTime = _formatTime(slot.startTime);
    for (final r in reservations) {
      if (_formatTime(r.startTime) == slotTime) {
        return r;
      }
    }
    return null;
  }

  void _confirmReservation(
    BuildContext context,
    WidgetRef ref,
    CourtSlotModel slot,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reserva'),
        content: Text(
          'Reservar ${court.name} em '
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')} '
          'das ${slot.timeRange}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(reservationActionProvider.notifier)
                  .createReservation(
                    courtSlotId: slot.id,
                    courtId: court.id,
                    date: selectedDate,
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                  );

              if (context.mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(context, 'Reserva confirmada!');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: court.id, date: selectedDate),
                  ));
                  ref.invalidate(myReservationsProvider);
                } else {
                  SnackbarUtils.showError(context, 'Erro ao reservar');
                }
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
