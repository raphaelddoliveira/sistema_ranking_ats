import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/player_model.dart';
import '../viewmodel/ranking_list_viewmodel.dart';
import 'widgets/ranking_list_tile.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(rankingListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmashRank'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(rankingListProvider),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: rankingAsync.when(
        data: (players) {
          if (players.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.onBackgroundLight),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum jogador no ranking',
                    style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                ],
              ),
            );
          }

          final topThree = players.length >= 3 ? players.sublist(0, 3) : <PlayerModel>[];

          // Filtrar lista pela busca
          final filteredPlayers = _searchQuery.isEmpty
              ? players
              : players.where((p) {
                  final query = _searchQuery.toLowerCase();
                  return p.fullName.toLowerCase().contains(query) ||
                      (p.nickname?.toLowerCase().contains(query) ?? false);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(rankingListProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Hero header with gradient (always in tree to preserve TextField focus)
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _searchQuery.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: AppColors.heroGradient,
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.emoji_events, color: AppColors.secondary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${players.length} jogadores ativos',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (topThree.length == 3) ...[
                                  const SizedBox(height: 20),
                                  _TopThreePodium(
                                    topThree: topThree,
                                    onTap: (player) {
                                      context.push(
                                        '/ranking/history/${player.id}?name=${Uri.encodeComponent(player.fullName)}',
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // Search bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar jogador...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),

                // Section title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? '${filteredPlayers.length} resultado${filteredPlayers.length != 1 ? 's' : ''}'
                          : 'Ranking completo',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.onBackgroundMedium,
                      ),
                    ),
                  ),
                ),

                // Player list
                if (filteredPlayers.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: AppColors.onBackgroundLight),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum jogador encontrado',
                            style: TextStyle(color: AppColors.onBackgroundLight),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final player = filteredPlayers[index];
                          return RankingListTile(
                            player: player,
                            onTap: () {
                              context.push(
                                '/ranking/history/${player.id}?name=${Uri.encodeComponent(player.fullName)}',
                              );
                            },
                          );
                        },
                        childCount: filteredPlayers.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar ranking',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: AppColors.onBackgroundLight, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(rankingListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top 3 Podium Widget ───
class _TopThreePodium extends StatelessWidget {
  final List<PlayerModel> topThree;
  final ValueChanged<PlayerModel> onTap;

  const _TopThreePodium({required this.topThree, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        _PodiumCard(
          player: topThree[1],
          position: 2,
          height: 120,
          badgeColor: AppColors.silver,
          badgeGradient: const LinearGradient(
            colors: [Color(0xFFD0D0D0), Color(0xFFA8A8A8), Color(0xFF888888)],
          ),
          onTap: () => onTap(topThree[1]),
        ),
        const SizedBox(width: 8),
        // 1st place (tallest)
        _PodiumCard(
          player: topThree[0],
          position: 1,
          height: 150,
          badgeColor: AppColors.gold,
          badgeGradient: const LinearGradient(
            colors: [Color(0xFFE8D44D), Color(0xFFD4AF37), Color(0xFFB8941F)],
          ),
          onTap: () => onTap(topThree[0]),
          isFirst: true,
        ),
        const SizedBox(width: 8),
        // 3rd place
        _PodiumCard(
          player: topThree[2],
          position: 3,
          height: 100,
          badgeColor: AppColors.bronze,
          badgeGradient: const LinearGradient(
            colors: [Color(0xFFD4955A), Color(0xFFB87333), Color(0xFF8B5E3C)],
          ),
          onTap: () => onTap(topThree[2]),
        ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final PlayerModel player;
  final int position;
  final double height;
  final Color badgeColor;
  final LinearGradient badgeGradient;
  final VoidCallback onTap;
  final bool isFirst;

  const _PodiumCard({
    required this.player,
    required this.position,
    required this.height,
    required this.badgeColor,
    required this.badgeGradient,
    required this.onTap,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: isFirst ? 110 : 95,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeColor, width: isFirst ? 3 : 2),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withAlpha(80),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: isFirst ? 32 : 26,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: player.avatarUrl != null
                        ? CachedNetworkImageProvider(player.avatarUrl!)
                        : null,
                    child: player.avatarUrl == null
                        ? Text(
                            player.fullName.isNotEmpty
                                ? player.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: isFirst ? 22 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackgroundMedium,
                            ),
                          )
                        : null,
                  ),
                ),
                // Position badge
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: badgeGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withAlpha(100),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$position',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Crown for 1st
                if (isFirst)
                  const Positioned(
                    top: -14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text('👑', style: TextStyle(fontSize: 18)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              _firstName(player.fullName),
              style: GoogleFonts.spaceGrotesk(
                fontSize: isFirst ? 13 : 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _firstName(String fullName) {
    final parts = fullName.split(' ');
    return parts.first;
  }
}
