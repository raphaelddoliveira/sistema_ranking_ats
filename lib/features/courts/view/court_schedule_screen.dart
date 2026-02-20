import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/models/time_slot.dart';
import '../../../shared/utils/slot_generator.dart';
import '../data/court_repository.dart';
import '../viewmodel/reservation_viewmodel.dart';

/// Provider to load a single court by ID
final _courtProvider =
    FutureProvider.autoDispose.family<CourtModel, String>((ref, courtId) async {
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getCourtById(courtId);
});

class CourtScheduleScreen extends ConsumerStatefulWidget {
  final String courtId;

  const CourtScheduleScreen({super.key, required this.courtId});

  @override
  ConsumerState<CourtScheduleScreen> createState() =>
      _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends ConsumerState<CourtScheduleScreen> {
  late DateTime _selectedDate;
  late final ScrollController _dateScrollController;

  // Generate 60 days starting from today
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _dates = List.generate(
      60,
      (i) => DateTime(today.year, today.month, today.day + i),
    );
    _dateScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courtAsync = ref.watch(_courtProvider(widget.courtId));

    return courtAsync.when(
      data: (court) => _buildContent(context, court),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CourtModel court) {
    // Convert DateTime.weekday (1=Mon, 7=Sun) to DB format (0=Sun, 6=Sat)
    final dbDayOfWeek =
        _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;

    final slots = generateSlots(court, dbDayOfWeek);
    final reservationsAsync = ref.watch(courtReservationsProvider(
      (courtId: court.id, date: _selectedDate),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(court.name),
        actions: [
          IconButton(
            onPressed: _openDatePicker,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Escolher data',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  style:
                      const TextStyle(color: AppColors.onBackgroundLight, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: slots.isEmpty
                ? const Center(
                    child: Text(
                      'Quadra fechada neste dia',
                      style: TextStyle(color: AppColors.onBackgroundLight),
                    ),
                  )
                : reservationsAsync.when(
                    data: (reservations) => _buildSlotsList(slots, reservations),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text('Erro ao carregar reservas: $err'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = index == 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withAlpha(20)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary.withAlpha(80))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayShort(date.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.onBackgroundLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : AppColors.onBackground,
                    ),
                  ),
                  Text(
                    _monthShort(date.month),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white
                          : AppColors.onBackgroundLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsList(
    List<TimeSlot> slots,
    List<ReservationModel> reservations,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _selectedDate.isAtSameMomentAs(today);
    final isPast = _selectedDate.isBefore(today);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final reservation = _findReservation(slot, reservations);
        final isReserved = reservation != null;

        final slotHour = int.tryParse(slot.startTime.split(':')[0]) ?? 0;
        final isSlotPast = isPast || (isToday && slotHour <= now.hour);

        final statusColor = isReserved
            ? AppColors.error
            : isSlotPast
                ? AppColors.onBackgroundLight
                : AppColors.success;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      slot.startTime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.timeRange,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isReserved
                            ? 'Reservado - ${reservation.playerName ?? 'Jogador'}'
                            : isSlotPast
                                ? 'Horário passado'
                                : 'Disponível',
                        style:
                            TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (!isReserved && !isSlotPast)
                  ElevatedButton(
                    onPressed: () => _confirmReservation(slot),
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Reservar',
                        style: TextStyle(fontSize: 13)),
                  )
                else if (isReserved)
                  const Icon(Icons.lock, color: AppColors.onBackgroundLight, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      final dayIndex = _dates.indexWhere((d) =>
          d.year == picked.year &&
          d.month == picked.month &&
          d.day == picked.day);
      if (dayIndex >= 0) {
        _dateScrollController.animateTo(
          dayIndex * 60.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _confirmReservation(TimeSlot slot) {
    final courtName =
        ref.read(_courtProvider(widget.courtId)).valueOrNull?.name ?? 'Quadra';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reserva'),
        content: Text(
          'Reservar $courtName em '
          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')} '
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
                    courtId: widget.courtId,
                    date: _selectedDate,
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                  );

              if (mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(context, 'Reserva confirmada!');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: widget.courtId, date: _selectedDate),
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

  ReservationModel? _findReservation(
    TimeSlot slot,
    List<ReservationModel> reservations,
  ) {
    for (final r in reservations) {
      if (_normalizeTime(r.startTime) == slot.startTime) return r;
    }
    return null;
  }

  static String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  String _formatDateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _dayShort(int weekday) {
    return switch (weekday) {
      1 => 'Seg',
      2 => 'Ter',
      3 => 'Qua',
      4 => 'Qui',
      5 => 'Sex',
      6 => 'Sab',
      7 => 'Dom',
      _ => '',
    };
  }

  static String _monthShort(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Fev',
      3 => 'Mar',
      4 => 'Abr',
      5 => 'Mai',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Ago',
      9 => 'Set',
      10 => 'Out',
      11 => 'Nov',
      12 => 'Dez',
      _ => '',
    };
  }

  String _dayOfWeekLabel(int dow) {
    return switch (dow) {
      0 => 'Domingo',
      1 => 'Segunda-feira',
      2 => 'Terça-feira',
      3 => 'Quarta-feira',
      4 => 'Quinta-feira',
      5 => 'Sexta-feira',
      6 => 'Sábado',
      _ => '',
    };
  }
}
