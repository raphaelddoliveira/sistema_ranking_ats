import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/utils/slot_generator.dart';
import '../data/court_repository.dart';

/// Provider to load a single court by ID
final _courtByIdProvider =
    FutureProvider.autoDispose.family<CourtModel, String>((ref, courtId) async {
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getCourtById(courtId);
});

class CourtSlotsScreen extends ConsumerStatefulWidget {
  final String courtId;
  final String courtName;

  const CourtSlotsScreen({
    super.key,
    required this.courtId,
    required this.courtName,
  });

  @override
  ConsumerState<CourtSlotsScreen> createState() => _CourtSlotsScreenState();
}

class _CourtSlotsScreenState extends ConsumerState<CourtSlotsScreen> {
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0];

  static const _dayLabels = {
    0: 'Domingo',
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
  };

  int _slotDurationMinutes = 60;
  TimeOfDay _openingTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);
  final Set<int> _enabledDays = {};
  bool _isSaving = false;
  bool _configLoaded = false;

  void _loadConfigFromCourt(CourtModel court) {
    if (_configLoaded) return;

    _slotDurationMinutes = court.slotDurationMinutes;

    final openParts = court.openingTime.split(':');
    _openingTime = TimeOfDay(
      hour: int.parse(openParts[0]),
      minute: int.parse(openParts[1]),
    );

    final closeParts = court.closingTime.split(':');
    _closingTime = TimeOfDay(
      hour: int.parse(closeParts[0]),
      minute: int.parse(closeParts[1]),
    );

    _enabledDays
      ..clear()
      ..addAll(court.operatingDays);

    _configLoaded = true;
  }

  int _calculateSlotCount() {
    final startMinutes = _openingTime.hour * 60 + _openingTime.minute;
    final endMinutes = _closingTime.hour * 60 + _closingTime.minute;
    if (endMinutes <= startMinutes) return 0;
    return (endMinutes - startMinutes) ~/ _slotDurationMinutes;
  }

  int get _totalSlots => _enabledDays.length * _calculateSlotCount();

  String get _openingTimeStr =>
      '${_openingTime.hour.toString().padLeft(2, '0')}:${_openingTime.minute.toString().padLeft(2, '0')}';

  String get _closingTimeStr =>
      '${_closingTime.hour.toString().padLeft(2, '0')}:${_closingTime.minute.toString().padLeft(2, '0')}';

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(courtRepositoryProvider).updateCourtSchedule(
            widget.courtId,
            slotDurationMinutes: _slotDurationMinutes,
            openingTime: _openingTimeStr,
            closingTime: _closingTimeStr,
            operatingDays: _enabledDays.toList()..sort(),
          );
      ref.invalidate(_courtByIdProvider(widget.courtId));
      if (mounted) {
        SnackbarUtils.showSuccess(
            context, 'Configuração salva! $_totalSlots horários por semana.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao salvar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courtAsync = ref.watch(_courtByIdProvider(widget.courtId));

    courtAsync.whenData((court) {
      if (!_configLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _loadConfigFromCourt(court));
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courtName} - Horários'),
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: courtAsync.when(
        data: (_) => _configLoaded
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDurationSelector(),
                  const SizedBox(height: 12),
                  _buildTimeRangeCard(),
                  const SizedBox(height: 12),
                  _buildDaysCard(),
                  const SizedBox(height: 12),
                  _buildPreviewCard(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildSaveBar() {
    final total = _totalSlots;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time,
                    size: 16, color: AppColors.onBackgroundMedium),
                const SizedBox(width: 6),
                Text(
                  '$total horários por semana',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onBackgroundMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: !_isSaving ? _saveConfiguration : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label:
                    Text(_isSaving ? 'Salvando...' : 'Salvar Configuração'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duração do horário',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.timer_outlined),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _slotDurationMinutes,
                  isDense: true,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutos')),
                    DropdownMenuItem(value: 45, child: Text('45 minutos')),
                    DropdownMenuItem(value: 60, child: Text('1 hora')),
                    DropdownMenuItem(value: 75, child: Text('1h15')),
                    DropdownMenuItem(value: 90, child: Text('1h30')),
                    DropdownMenuItem(value: 120, child: Text('2 horas')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _slotDurationMinutes = v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horário de funcionamento',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker(
                    time: _openingTime,
                    onChanged: (t) => setState(() => _openingTime = t),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('até',
                      style: TextStyle(color: AppColors.onBackgroundLight)),
                ),
                Expanded(
                  child: _buildTimePicker(
                    time: _closingTime,
                    onChanged: (t) => setState(() => _closingTime = t),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border:
              Border.all(color: AppColors.onBackgroundLight.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              _formatTimeOfDay(time),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dias de funcionamento',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dayOrder.map((day) {
                final enabled = _enabledDays.contains(day);
                return FilterChip(
                  label: Text(_dayLabels[day]!),
                  selected: enabled,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _enabledDays.add(day);
                      } else {
                        _enabledDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final slotsPerDay = _calculateSlotCount();
    if (_enabledDays.isEmpty || slotsPerDay <= 0) {
      return const SizedBox.shrink();
    }

    // Build a CourtModel to use generateSlots for preview
    final previewCourt = CourtModel(
      id: '',
      name: '',
      sportId: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      slotDurationMinutes: _slotDurationMinutes,
      openingTime: _openingTimeStr,
      closingTime: _closingTimeStr,
      operatingDays: _enabledDays.toList(),
    );
    final previewSlots = generateSlots(previewCourt, _enabledDays.first);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview ($slotsPerDay por dia)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: previewSlots
                  .map((s) => Chip(
                        label: Text(s.timeRange,
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
