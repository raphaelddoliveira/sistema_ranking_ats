import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reservation_model.dart';
import '../../clubs/data/club_repository.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../courts/data/court_repository.dart';
import '../../courts/viewmodel/courts_viewmodel.dart';

/// Provider for all club reservations (admin view)
final _clubReservationsProvider = FutureProvider<List<ReservationModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getClubReservations(clubId: clubId);
});

/// Provider for club members (for player pickers)
final _adminMembersProvider = FutureProvider<List<ClubMemberModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getMembers(clubId);
});

class AdminReservationsScreen extends ConsumerWidget {
  const AdminReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(_clubReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_clubReservationsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateReservationSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova Reserva'),
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: AppColors.onBackgroundLight),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma reserva ativa',
                    style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_clubReservationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final r = reservations[index];
                return _ReservationCard(reservation: r);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  void _showCreateReservationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _CreateReservationSheet(),
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isChallenge = reservation.challengeId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Court icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isChallenge
                    ? AppColors.challengeScheduled.withAlpha(25)
                    : AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isChallenge ? Icons.sports_tennis : Icons.event,
                color: isChallenge ? AppColors.challengeScheduled : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.courtName ?? 'Quadra',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFormat.format(reservation.reservationDate)} | ${reservation.startTime.substring(0, 5)}-${reservation.endTime.substring(0, 5)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.onBackgroundMedium),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${reservation.playerName ?? '?'} vs ${reservation.opponentPlayerName ?? reservation.opponentName ?? 'Aberta'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.onBackgroundLight),
                  ),
                  if (isChallenge)
                    const Text(
                      'Desafio de ranking',
                      style: TextStyle(fontSize: 10, color: AppColors.challengeScheduled, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            // Cancel button
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
              tooltip: 'Cancelar reserva',
              onPressed: () => _confirmCancel(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva?'),
        content: Text(
          'Cancelar a reserva de ${reservation.courtName ?? 'quadra'} em ${DateFormat('dd/MM').format(reservation.reservationDate)}?'
          '${reservation.challengeId != null ? '\n\nIsso tambem cancelara o desafio vinculado.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nao'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Reserva', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final authId = Supabase.instance.client.auth.currentUser!.id;
      await ref.read(courtRepositoryProvider).adminCancelReservation(
        reservationId: reservation.id,
        adminAuthId: authId,
      );
      ref.invalidate(_clubReservationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}

class _CreateReservationSheet extends ConsumerStatefulWidget {
  const _CreateReservationSheet();

  @override
  ConsumerState<_CreateReservationSheet> createState() => _CreateReservationSheetState();
}

class _CreateReservationSheetState extends ConsumerState<_CreateReservationSheet> {
  ClubMemberModel? _player1;
  ClubMemberModel? _player2;
  CourtModel? _court;
  DateTime? _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  bool _loading = false;

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _isValid =>
      _player1 != null &&
      _player2 != null &&
      _court != null &&
      _date != null &&
      _player1!.playerId != _player2!.playerId;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(_adminMembersProvider);
    final courtsAsync = ref.watch(courtsListProvider);

    final members = membersAsync.valueOrNull
            ?.where((m) => m.status == ClubMemberStatus.active)
            .toList() ??
        [];
    final courts = courtsAsync.valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nova Reserva',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Player 1
          _buildDropdown<ClubMemberModel>(
            label: 'Jogador 1',
            value: _player1,
            items: members,
            displayFn: (m) => m.playerName,
            onChanged: (m) => setState(() => _player1 = m),
          ),
          const SizedBox(height: 12),

          // Player 2
          _buildDropdown<ClubMemberModel>(
            label: 'Jogador 2',
            value: _player2,
            items: members,
            displayFn: (m) => m.playerName,
            onChanged: (m) => setState(() => _player2 = m),
          ),
          if (_player1 != null && _player2 != null && _player1!.playerId == _player2!.playerId)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Selecione jogadores diferentes', style: TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),

          // Court
          _buildDropdown<CourtModel>(
            label: 'Quadra',
            value: _court,
            items: courts,
            displayFn: (c) => c.name,
            onChanged: (c) => setState(() => _court = c),
          ),
          const SizedBox(height: 12),

          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(_date != null
                ? DateFormat('dd/MM/yyyy').format(_date!)
                : 'Selecionar data'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, size: 20),
                  title: Text('Inicio: ${_formatTime(_startTime)}', style: const TextStyle(fontSize: 14)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _startTime);
                    if (picked != null) setState(() => _startTime = picked);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, size: 20),
                  title: Text('Fim: ${_formatTime(_endTime)}', style: const TextStyle(fontSize: 14)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _endTime);
                    if (picked != null) setState(() => _endTime = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Create button
          FilledButton(
            onPressed: _isValid && !_loading ? _create : null,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Criar Reserva'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayFn,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(displayFn(item), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _create() async {
    if (!_isValid) return;
    setState(() => _loading = true);

    try {
      final clubId = ref.read(currentClubIdProvider);
      if (clubId == null) throw Exception('Clube nao selecionado');

      await ref.read(courtRepositoryProvider).adminCreateReservation(
        player1Id: _player1!.playerId,
        player2Id: _player2!.playerId,
        courtId: _court!.id,
        date: _date!,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        clubId: clubId,
      );

      ref.invalidate(_clubReservationsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva criada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
