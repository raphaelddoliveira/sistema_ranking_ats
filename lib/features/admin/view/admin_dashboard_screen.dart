import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/player_model.dart';
import '../../../shared/models/enums.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.people,
            title: 'Gerenciar Jogadores',
            subtitle: 'Status, posicao, ambulancia',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AdminPlayersScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.local_hospital,
            title: 'Ambulancias',
            subtitle: 'Ativar/desativar ambulancias',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AdminAmbulanceScreen()),
            ),
          ),
          _AdminCard(
            icon: Icons.payment,
            title: 'Mensalidades',
            subtitle: 'Controle de pagamentos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const _PlaceholderScreen(title: 'Mensalidades')),
            ),
          ),
          _AdminCard(
            icon: Icons.sports_tennis,
            title: 'Quadras',
            subtitle: 'CRUD de quadras e slots',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const _PlaceholderScreen(title: 'Gerenciar Quadras')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary.withAlpha(25),
          child: Icon(icon, color: AppColors.secondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Admin Players Screen ───
class AdminPlayersScreen extends ConsumerWidget {
  const AdminPlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(_adminPlayersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Jogadores')),
      body: playersAsync.when(
        data: (players) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    '#${player.rankingPosition}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                title: Text(player.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(
                  children: [
                    _StatusBadge(status: player.status),
                    if (player.role == PlayerRole.admin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.secondary)),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleAction(context, ref, player, action),
                  itemBuilder: (_) => [
                    if (player.status != PlayerStatus.active)
                      const PopupMenuItem(
                          value: 'activate', child: Text('Ativar')),
                    if (player.status == PlayerStatus.active)
                      const PopupMenuItem(
                          value: 'deactivate', child: Text('Desativar')),
                    if (player.status != PlayerStatus.suspended)
                      const PopupMenuItem(
                          value: 'suspend', child: Text('Suspender')),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    PlayerModel player,
    String action,
  ) async {
    final client = ref.read(supabaseClientProvider);
    String newStatus;

    switch (action) {
      case 'activate':
        newStatus = 'active';
      case 'deactivate':
        newStatus = 'inactive';
      case 'suspend':
        newStatus = 'suspended';
      default:
        return;
    }

    try {
      await client
          .from(SupabaseConstants.playersTable)
          .update({'status': newStatus}).eq('id', player.id);

      if (context.mounted) {
        SnackbarUtils.showSuccess(
            context, '${player.fullName} atualizado para $newStatus');
        ref.invalidate(_adminPlayersProvider);
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }
}

final _adminPlayersProvider = FutureProvider<List<PlayerModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from(SupabaseConstants.playersTable)
      .select()
      .order('ranking_position');
  return data.map((e) => PlayerModel.fromJson(e)).toList();
});

// ─── Admin Ambulance Screen ───
class AdminAmbulanceScreen extends ConsumerWidget {
  const AdminAmbulanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(_adminPlayersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ambulancias')),
      body: playersAsync.when(
        data: (players) {
          final activePlayers =
              players.where((p) => p.status == PlayerStatus.active).toList();
          final ambulancePlayers =
              players.where((p) => p.status == PlayerStatus.ambulance).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (ambulancePlayers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Ambulancias Ativas (${ambulancePlayers.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...ambulancePlayers.map((p) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x20E53935),
                          child: Icon(Icons.local_hospital,
                              color: AppColors.ambulanceActive, size: 20),
                        ),
                        title: Text(p.fullName),
                        subtitle: Text('#${p.rankingPosition}'),
                        trailing: ElevatedButton(
                          onPressed: () =>
                              _deactivateAmbulance(context, ref, p),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: const Text('Desativar',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Jogadores Ativos (${activePlayers.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...activePlayers.map((p) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text('#${p.rankingPosition}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text(p.fullName),
                      trailing: OutlinedButton(
                        onPressed: () =>
                            _activateAmbulance(context, ref, p),
                        child: const Text('Ambulancia',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  void _activateAmbulance(
      BuildContext context, WidgetRef ref, PlayerModel player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar Ambulancia'),
        content: Text(
          'Ativar ambulancia para ${player.fullName} (#${player.rankingPosition})?\n\n'
          'Isso ira:\n'
          '- Penalizar -3 posicoes\n'
          '- Ativar protecao de 10 dias\n'
          '- Apos 10 dias: -1 posicao/dia',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(supabaseClientProvider);
                await client.rpc(
                  SupabaseConstants.rpcActivateAmbulance,
                  params: {'p_player_id': player.id},
                );
                if (context.mounted) {
                  SnackbarUtils.showSuccess(
                      context, 'Ambulancia ativada para ${player.fullName}');
                  ref.invalidate(_adminPlayersProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtils.showError(context, 'Erro: $e');
                }
              }
            },
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  void _deactivateAmbulance(
      BuildContext context, WidgetRef ref, PlayerModel player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar Ambulancia'),
        content:
            Text('Desativar ambulancia de ${player.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(supabaseClientProvider);
                await client.rpc(
                  SupabaseConstants.rpcDeactivateAmbulance,
                  params: {'p_player_id': player.id},
                );
                if (context.mounted) {
                  SnackbarUtils.showSuccess(context,
                      'Ambulancia desativada para ${player.fullName}');
                  ref.invalidate(_adminPlayersProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtils.showError(context, 'Erro: $e');
                }
              }
            },
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PlayerStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      PlayerStatus.active => (AppColors.success, 'Ativo'),
      PlayerStatus.inactive => (Colors.grey, 'Inativo'),
      PlayerStatus.ambulance => (AppColors.ambulanceActive, 'Ambulancia'),
      PlayerStatus.suspended => (AppColors.error, 'Suspenso'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Em desenvolvimento',
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
