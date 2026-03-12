import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/like_button.dart';
import '../../data/feed_repository.dart';

class MatchResultCard extends ConsumerWidget {
  final MatchResultFeedItem item;

  const MatchResultCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = item.challenge;
    final isWo = challenge.isWo;

    // Determine winner/loser names and avatars
    final isWinnerChallenger = challenge.winnerId == challenge.challengerId;
    final winnerName = isWinnerChallenger
        ? (challenge.challengerName ?? 'Jogador')
        : (challenge.challengedName ?? 'Jogador');
    final loserName = isWinnerChallenger
        ? (challenge.challengedName ?? 'Jogador')
        : (challenge.challengerName ?? 'Jogador');
    final winnerAvatar = isWinnerChallenger
        ? challenge.challengerAvatarUrl
        : challenge.challengedAvatarUrl;
    final loserAvatar = isWinnerChallenger
        ? challenge.challengedAvatarUrl
        : challenge.challengerAvatarUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/challenges/${challenge.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Main row: avatars + names + score
              Row(
                children: [
                  // Winner side
                  Expanded(
                    child: _PlayerSide(
                      name: winnerName,
                      avatarUrl: winnerAvatar,
                      isWinner: true,
                      delta: item.winnerDelta,
                      newPos: item.winnerNewPos,
                    ),
                  ),

                  // Score center
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        if (isWo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'WO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          )
                        else
                          Text(
                            challenge.scoreDisplay ?? '-',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                              letterSpacing: 0.5,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onBackgroundLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loser side
                  Expanded(
                    child: _PlayerSide(
                      name: loserName,
                      avatarUrl: loserAvatar,
                      isWinner: false,
                      delta: item.loserDelta,
                      newPos: item.loserNewPos,
                      align: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Bottom row: time + like
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: AppColors.onBackgroundLight),
                  const SizedBox(width: 4),
                  Text(
                    item.timestamp.timeAgo(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onBackgroundLight,
                    ),
                  ),
                  if (challenge.courtName != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined, size: 12, color: AppColors.onBackgroundLight),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        challenge.courtName!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onBackgroundLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  LikeButton(challengeId: challenge.id, ref: ref),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSide extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isWinner;
  final int? delta;
  final int? newPos;
  final CrossAxisAlignment align;

  const _PlayerSide({
    required this.name,
    this.avatarUrl,
    required this.isWinner,
    this.delta,
    this.newPos,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinner ? AppColors.rankUp : AppColors.rankDown;
    final label = isWinner ? 'VENCEU' : 'PERDEU';
    final isEnd = align == CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: align,
      children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.surfaceVariant,
          backgroundImage:
              avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                )
              : null,
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.onBackground,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: isEnd ? TextAlign.end : TextAlign.start,
        ),

        // Result badge + ranking change
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (delta != null && delta != 0) ...[
              const SizedBox(width: 4),
              Icon(
                isWinner ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
              Text(
                '${delta!.abs()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
            if (newPos != null) ...[
              const SizedBox(width: 4),
              Text(
                '#$newPos',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.onBackgroundLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
