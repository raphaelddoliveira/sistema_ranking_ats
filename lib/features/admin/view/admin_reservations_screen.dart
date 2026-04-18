import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/reservation_model.dart';
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
        onPressed: () => _showCourtPicker(context, ref),
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

  void _showCourtPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, innerRef, _) {
          final courtsAsync = innerRef.watch(courtsListProvider);

          return courtsAsync.when(
            loading: () => const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SafeArea(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Erro: $e')),
              ),
            ),
            data: (courts) {
              if (courts.isEmpty) {
                return const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Nenhuma quadra disponível')),
                  ),
                );
              }

              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecione a Quadra',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...courts.map((court) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(25),
                            child: const Icon(Icons.sports_tennis, color: AppColors.primary, size: 20),
                          ),
                          title: Text(court.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/admin/court-schedule/${court.id}');
                          },
                        )),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
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
    final isAdmin = reservation.isAdministrative;

    final iconColor = isAdmin
        ? AppColors.warning
        : isChallenge
            ? AppColors.challengeScheduled
            : AppColors.primary;
    final icon = isAdmin
        ? Icons.block
        : isChallenge
            ? Icons.sports_tennis
            : Icons.event;

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
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                  if (reservation.isAdministrative)
                    Text(
                      reservation.administrativeTitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
                    )
                  else ...[
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
                ],
              ),
            ),
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
              tooltip: 'Editar reserva',
              onPressed: () {
                context.push(
                  '/admin/court-schedule/${reservation.courtId}',
                  extra: {
                    'editingReservationId': reservation.id,
                  },
                );
              },
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

