import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../courts/data/court_repository.dart';
import '../../courts/viewmodel/courts_viewmodel.dart';
import '../data/club_repository.dart';
import '../viewmodel/club_providers.dart';

/// Courts for a specific club (including inactive for admin view)
final _clubCourtsProvider = FutureProvider.family<List<CourtModel>, String>(
  (ref, clubId) async {
    final repo = ref.watch(courtRepositoryProvider);
    return repo.getAllCourts(clubId: clubId);
  },
);

class ClubManagementScreen extends ConsumerWidget {
  final String clubId;

  const ClubManagementScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(currentClubProvider);
    final membersAsync = ref.watch(clubMembersProvider(clubId));
    final requestsAsync = ref.watch(clubJoinRequestsProvider(clubId));
    final isAdmin = ref.watch(isClubAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Clube'),
        centerTitle: true,
      ),
      body: clubAsync.when(
        data: (club) {
          if (club == null) {
            return const Center(child: Text('Clube nao encontrado'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Club info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.groups_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        club.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (club.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          club.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onBackgroundLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Invite code
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              club.inviteCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: club.inviteCode));
                                SnackbarUtils.showSuccess(context, 'Codigo copiado!');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pending requests (admin only)
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: requestsAsync.when(
                    data: (requests) {
                      final pending = requests.length;
                      return Row(
                        children: [
                          Text(
                            'Solicitacoes Pendentes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (pending > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pending',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => Text(
                      'Solicitacoes Pendentes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    error: (_, _) => Text(
                      'Solicitacoes Pendentes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle_outline, color: AppColors.onBackgroundLight),
                          title: Text('Nenhuma solicitacao pendente'),
                        ),
                      );
                    }
                    return Column(
                      children: requests.map((req) => _RequestTile(
                        request: req,
                        onApprove: () async {
                          final player = ref.read(currentPlayerProvider).valueOrNull;
                          if (player == null) return;
                          try {
                            await ref.read(clubRepositoryProvider)
                                .approveJoinRequest(req['id'], player.authId);
                            ref.invalidate(clubJoinRequestsProvider(clubId));
                            ref.invalidate(clubMembersProvider(clubId));
                            if (context.mounted) {
                              SnackbarUtils.showSuccess(context, 'Solicitacao aprovada!');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarUtils.showError(context, 'Erro ao aprovar: $e');
                            }
                          }
                        },
                        onReject: () async {
                          final player = ref.read(currentPlayerProvider).valueOrNull;
                          if (player == null) return;
                          try {
                            await ref.read(clubRepositoryProvider)
                                .rejectJoinRequest(req['id'], player.authId);
                            ref.invalidate(clubJoinRequestsProvider(clubId));
                            if (context.mounted) {
                              SnackbarUtils.showSuccess(context, 'Solicitacao rejeitada');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarUtils.showError(context, 'Erro ao rejeitar: $e');
                            }
                          }
                        },
                      )).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: AppColors.error),
                      title: const Text('Erro ao carregar solicitacoes'),
                      subtitle: Text('$e', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Members list
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: membersAsync.when(
                  data: (members) => Text(
                    'Membros (${members.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => const Text('Membros'),
                  error: (_, _) => const Text('Membros'),
                ),
              ),
              membersAsync.when(
                data: (members) => Column(
                  children: members.map((member) => _MemberTile(
                    member: member,
                    isAdmin: isAdmin,
                    onToggleRole: isAdmin
                        ? () async {
                            final newRole = member.isClubAdmin ? 'member' : 'admin';
                            await ref.read(clubRepositoryProvider)
                                .updateMemberRole(member.id, newRole);
                            ref.invalidate(clubMembersProvider(clubId));
                          }
                        : null,
                    onRemove: isAdmin
                        ? () async {
                            final player = ref.read(currentPlayerProvider).valueOrNull;
                            if (player == null) return;
                            try {
                              await ref.read(clubRepositoryProvider)
                                  .removeMember(member.id, player.authId);
                              ref.invalidate(clubMembersProvider(clubId));
                              if (context.mounted) {
                                SnackbarUtils.showSuccess(context, 'Membro removido');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                SnackbarUtils.showError(context, 'Erro: $e');
                              }
                            }
                          }
                        : null,
                  )).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e'),
              ),

              // ─── Courts section ───
              const SizedBox(height: 24),
              _CourtsSection(clubId: clubId, isAdmin: isAdmin),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final player = request['player'] as Map<String, dynamic>?;
    final name = player?['full_name'] ?? 'Jogador';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Aguardando aprovacao'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              onPressed: onApprove,
              tooltip: 'Aprovar',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: onReject,
              tooltip: 'Rejeitar',
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ClubMemberModel member;
  final bool isAdmin;
  final VoidCallback? onToggleRole;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.member,
    required this.isAdmin,
    this.onToggleRole,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isClubAdmin ? AppColors.secondary : AppColors.primaryLight,
          child: Text(
            '#${member.rankingPosition ?? '-'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          member.playerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          member.isClubAdmin ? 'Admin' : 'Membro',
          style: TextStyle(
            color: member.isClubAdmin ? AppColors.secondary : AppColors.onBackgroundLight,
            fontWeight: member.isClubAdmin ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'toggle_role') onToggleRole?.call();
                  if (action == 'remove') onRemove?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle_role',
                    child: Text(member.isClubAdmin ? 'Tornar membro' : 'Tornar admin'),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remover', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// ─── Courts Section ───

class _CourtsSection extends ConsumerWidget {
  final String clubId;
  final bool isAdmin;

  const _CourtsSection({
    required this.clubId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(_clubCourtsProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: courtsAsync.when(
                  data: (courts) => Text(
                    'Quadras (${courts.where((c) => c.isActive).length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => const Text('Quadras'),
                  error: (_, _) => const Text('Quadras'),
                ),
              ),
            ),
            if (isAdmin)
              TextButton.icon(
                onPressed: () => _showCourtDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        courtsAsync.when(
          data: (courts) {
            if (courts.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.sports_tennis, color: AppColors.onBackgroundLight),
                  title: Text('Nenhuma quadra cadastrada'),
                  subtitle: Text('Adicione quadras para reservas'),
                ),
              );
            }
            return Column(
              children: courts.map((court) => _CourtTile(
                court: court,
                isAdmin: isAdmin,
                onEdit: () => _showCourtDialog(context, ref, court: court),
                onToggleActive: () async {
                  final repo = ref.read(courtRepositoryProvider);
                  if (court.isActive) {
                    await repo.deactivateCourt(court.id);
                  } else {
                    await repo.reactivateCourt(court.id);
                  }
                  ref.invalidate(_clubCourtsProvider(clubId));
                  ref.invalidate(courtsListProvider);
                },
              )).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }

  void _showCourtDialog(BuildContext context, WidgetRef ref, {CourtModel? court}) {
    final nameController = TextEditingController(text: court?.name ?? '');
    final notesController = TextEditingController(text: court?.notes ?? '');
    String? selectedSurface = court?.surfaceType;
    bool isCovered = court?.isCovered ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(court == null ? 'Nova Quadra' : 'Editar Quadra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da quadra',
                    hintText: 'Ex: Quadra 1',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedSurface,
                  decoration: const InputDecoration(labelText: 'Tipo de piso'),
                  items: const [
                    DropdownMenuItem(value: 'saibro', child: Text('Saibro')),
                    DropdownMenuItem(value: 'dura', child: Text('Quadra Dura')),
                    DropdownMenuItem(value: 'grama', child: Text('Grama')),
                    DropdownMenuItem(value: 'carpet', child: Text('Carpet')),
                  ],
                  onChanged: (v) => setState(() => selectedSurface = v),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Quadra coberta'),
                  value: isCovered,
                  onChanged: (v) => setState(() => isCovered = v),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes (opcional)',
                    hintText: 'Ex: Iluminacao disponivel',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(courtRepositoryProvider);
                if (court == null) {
                  await repo.createCourt(
                    clubId: clubId,
                    name: name,
                    surfaceType: selectedSurface,
                    isCovered: isCovered,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                } else {
                  await repo.updateCourt(
                    court.id,
                    name: name,
                    surfaceType: selectedSurface,
                    isCovered: isCovered,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                }
                ref.invalidate(_clubCourtsProvider(clubId));
                ref.invalidate(courtsListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(court == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtTile extends StatelessWidget {
  final CourtModel court;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _CourtTile({
    required this.court,
    required this.isAdmin,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: court.isActive
              ? AppColors.primary.withAlpha(25)
              : AppColors.surfaceVariant,
          child: Icon(
            court.isCovered ? Icons.roofing : Icons.wb_sunny,
            size: 20,
            color: court.isActive ? AppColors.primary : AppColors.onBackgroundLight,
          ),
        ),
        title: Text(
          court.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: court.isActive ? null : AppColors.onBackgroundLight,
          ),
        ),
        subtitle: Text(
          [
            court.surfaceLabel,
            court.isCovered ? 'Coberta' : 'Descoberta',
            if (!court.isActive) 'Inativa',
          ].join(' · '),
          style: TextStyle(
            fontSize: 12,
            color: court.isActive ? AppColors.onBackgroundMedium : AppColors.onBackgroundLight,
          ),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'toggle') onToggleActive();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      court.isActive ? 'Desativar' : 'Reativar',
                      style: TextStyle(
                        color: court.isActive ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
