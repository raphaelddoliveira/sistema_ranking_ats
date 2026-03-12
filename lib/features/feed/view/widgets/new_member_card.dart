import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/feed_repository.dart';

class NewMemberCard extends StatelessWidget {
  final NewMemberFeedItem item;

  const NewMemberCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/players/${item.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Wave icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('👋', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: item.avatarUrl != null
                    ? CachedNetworkImageProvider(item.avatarUrl!)
                    : null,
                child: item.avatarUrl == null
                    ? Text(
                        item.playerName.isNotEmpty
                            ? item.playerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: item.playerName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' entrou no ranking'),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.rankingPosition != null) ...[
                          Text(
                            'Posição #${item.rankingPosition}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onBackgroundMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            '  •  ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onBackgroundLight,
                            ),
                          ),
                        ],
                        Text(
                          item.joinedAt.timeAgo(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onBackgroundLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
