import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/h2h_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/h2h_viewmodel.dart';

class H2HScreen extends ConsumerWidget {
  final String player1Id;
  final String player2Id;

  const H2HScreen({
    super.key,
    required this.player1Id,
    required this.player2Id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubId = ref.watch(currentClubIdProvider);
    final sportId = ref.watch(currentSportIdProvider);

    if (clubId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confronto Direto')),
        body: const Center(child: Text('Nenhum clube selecionado')),
      );
    }

    final h2hAsync = ref.watch(h2hProvider((
      p1: player1Id,
      p2: player2Id,
      clubId: clubId,
      sportId: sportId,
    )));

    return Scaffold(
      appBar: AppBar(title: const Text('Confronto Direto')),
      body: h2hAsync.when(
        data: (h2h) {
          if (h2h.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum confronto registrado entre estes jogadores.',
                style: TextStyle(color: AppColors.onBackgroundLight),
              ),
            );
          }
          return _H2HBody(h2h: h2h);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _H2HBody extends StatelessWidget {
  final H2HModel h2h;

  const _H2HBody({required this.h2h});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ScoreHeader(h2h: h2h),
        const SizedBox(height: 16),
        _StatsCard(h2h: h2h),
        const SizedBox(height: 16),
        if (h2h.matches.length >= 2) ...[
          _H2HChart(h2h: h2h),
          const SizedBox(height: 16),
        ],
        _MatchHistory(h2h: h2h),
      ],
    );
  }
}

// ─── Score Header ───────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  final H2HModel h2h;

  const _ScoreHeader({required this.h2h});

  @override
  Widget build(BuildContext context) {
    final p1Name = h2h.player1Name ?? 'Jogador 1';
    final p2Name = h2h.player2Name ?? 'Jogador 2';
    final p1Leads = h2h.player1Wins > h2h.player2Wins;
    final p2Leads = h2h.player2Wins > h2h.player1Wins;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                // Player 1
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: p1Leads
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        child: Text(
                          _initials(p1Name),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: p1Leads
                                ? AppColors.onPrimary
                                : AppColors.onBackgroundMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p1Name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              p1Leads ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        '${h2h.player1Wins} x ${h2h.player2Wins}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${h2h.totalMatches} ${h2h.totalMatches == 1 ? 'jogo' : 'jogos'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onBackgroundLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Player 2
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: p2Leads
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        child: Text(
                          _initials(p2Name),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: p2Leads
                                ? AppColors.onPrimary
                                : AppColors.onBackgroundMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p2Name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              p2Leads ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ─── Stats Card ─────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final H2HModel h2h;

  const _StatsCard({required this.h2h});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estatísticas',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _StatRow(
              label: 'Vitórias',
              p1Value: '${h2h.player1Wins}',
              p2Value: '${h2h.player2Wins}',
              p1Highlight: h2h.player1Wins > h2h.player2Wins,
              p2Highlight: h2h.player2Wins > h2h.player1Wins,
            ),
            const Divider(height: 16),
            _StatRow(
              label: 'Sets',
              p1Value: '${h2h.player1Sets}',
              p2Value: '${h2h.player2Sets}',
              p1Highlight: h2h.player1Sets > h2h.player2Sets,
              p2Highlight: h2h.player2Sets > h2h.player1Sets,
            ),
            if (h2h.player1WOs > 0 || h2h.player2WOs > 0) ...[
              const Divider(height: 16),
              _StatRow(
                label: 'WOs sofridos',
                p1Value: '${h2h.player1WOs}',
                p2Value: '${h2h.player2WOs}',
                p1Highlight: h2h.player1WOs < h2h.player2WOs,
                p2Highlight: h2h.player2WOs < h2h.player1WOs,
                invertHighlight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String p1Value;
  final String p2Value;
  final bool p1Highlight;
  final bool p2Highlight;
  final bool invertHighlight;

  const _StatRow({
    required this.label,
    required this.p1Value,
    required this.p2Value,
    this.p1Highlight = false,
    this.p2Highlight = false,
    this.invertHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        invertHighlight ? AppColors.error : AppColors.success;

    return Row(
      children: [
        Expanded(
          child: Text(
            p1Value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p1Highlight ? highlightColor : AppColors.onBackground,
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onBackgroundMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            p2Value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p2Highlight ? highlightColor : AppColors.onBackground,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Chart ──────────────────────────────────────────────────

class _H2HChart extends StatelessWidget {
  final H2HModel h2h;

  const _H2HChart({required this.h2h});

  @override
  Widget build(BuildContext context) {
    // Build cumulative score evolution (oldest first)
    final matches = h2h.matches.reversed.toList();
    int p1Acc = 0, p2Acc = 0;
    final p1Spots = <FlSpot>[];
    final p2Spots = <FlSpot>[];

    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m.winnerId == h2h.player1Id) {
        p1Acc++;
      } else {
        p2Acc++;
      }
      p1Spots.add(FlSpot(i.toDouble(), p1Acc.toDouble()));
      p2Spots.add(FlSpot(i.toDouble(), p2Acc.toDouble()));
    }

    final maxY = (p1Acc > p2Acc ? p1Acc : p2Acc) + 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolução',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _LegendDot(color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  _shortName(h2h.player1Name ?? 'P1'),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onBackgroundMedium),
                ),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  _shortName(h2h.player2Name ?? 'P2'),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onBackgroundMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: _calcInterval(matches.length),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= matches.length) {
                              return const SizedBox.shrink();
                            }
                            final d = matches[idx].playedAt;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${d.day}/${d.month}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onBackgroundLight,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value % 1 != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.onBackgroundLight,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: maxY.toDouble(),
                    lineBarsData: [
                      _buildLine(p1Spots, AppColors.primary),
                      _buildLine(p2Spots, AppColors.secondary),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final idx = spot.x.toInt();
                            if (idx < 0 || idx >= matches.length) return null;
                            final m = matches[idx];
                            final isP1 =
                                spot.bar.color == AppColors.primary;
                            final name = isP1
                                ? _shortName(h2h.player1Name ?? 'P1')
                                : _shortName(h2h.player2Name ?? 'P2');
                            return LineTooltipItem(
                              '$name: ${spot.y.toInt()} ${m.isWO ? '(WO)' : ''}',
                              TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(20),
      ),
    );
  }

  double _calcInterval(int length) {
    if (length <= 7) return 1;
    if (length <= 14) return 2;
    return (length / 6).roundToDouble();
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first} ${parts.last[0]}.';
    return parts.first;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Match History ──────────────────────────────────────────

class _MatchHistory extends StatelessWidget {
  final H2HModel h2h;

  const _MatchHistory({required this.h2h});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...h2h.matches.asMap().entries.map((entry) {
              final match = entry.value;
              final isLast = entry.key == h2h.matches.length - 1;

              final p1Won = match.winnerId == h2h.player1Id;
              final winnerName = p1Won
                  ? (h2h.player1Name ?? 'Jogador 1')
                  : (h2h.player2Name ?? 'Jogador 2');

              return Column(
                children: [
                  _MatchTile(
                    match: match,
                    winnerName: winnerName,
                    p1Won: p1Won,
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final H2HMatch match;
  final String winnerName;
  final bool p1Won;

  const _MatchTile({
    required this.match,
    required this.winnerName,
    required this.p1Won,
  });

  @override
  Widget build(BuildContext context) {
    final date = match.playedAt.isUtc ? match.playedAt.toLocal() : match.playedAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Win indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: p1Won ? AppColors.primary : AppColors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: p1Won ? AppColors.primary : AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        winnerName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p1Won
                              ? AppColors.primary
                              : AppColors.secondaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onBackgroundLight,
                  ),
                ),
              ],
            ),
          ),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: match.isWO
                  ? AppColors.error.withAlpha(15)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              match.resultDisplay,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: match.isWO
                    ? AppColors.error
                    : AppColors.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
