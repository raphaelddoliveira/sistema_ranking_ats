import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../shared/providers/current_player_provider.dart';
import 'widgets/profile_header.dart';
import 'widgets/stats_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja realmente sair da sua conta?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: playerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Jogador nao encontrado'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProfileHeader(player: player),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        label: 'Posicao',
                        value: '#${player.rankingPosition ?? '-'}',
                        icon: Icons.emoji_events,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        label: 'Desafios/Mes',
                        value: '${player.challengesThisMonth}',
                        icon: Icons.sports_tennis,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        label: 'Status',
                        value: player.status.name,
                        icon: Icons.circle,
                        color: player.isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        label: 'Mensalidade',
                        value: player.feeStatus.name,
                        icon: Icons.payments,
                        color: player.hasFeeOverdue
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (player.isOnCooldown)
                  _buildInfoTile(
                    icon: Icons.timer,
                    title: 'Cooldown ativo',
                    subtitle: 'Aguarde para desafiar novamente',
                    color: AppColors.warning,
                  ),
                if (player.isProtected)
                  _buildInfoTile(
                    icon: Icons.shield,
                    title: 'Protecao ativa',
                    subtitle: 'Voce esta protegido de novos desafios',
                    color: AppColors.info,
                  ),
                if (player.isOnAmbulance)
                  _buildInfoTile(
                    icon: Icons.local_hospital,
                    title: 'Ambulancia ativa',
                    subtitle: 'Voce esta em pausa no ranking',
                    color: AppColors.ambulanceActive,
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
