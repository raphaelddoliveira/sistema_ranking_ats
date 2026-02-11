import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/player_model.dart';

class RankingListTile extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback? onTap;

  const RankingListTile({
    super.key,
    required this.player,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final position = player.rankingPosition ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Position badge
              _PositionBadge(position: position),
              const SizedBox(width: 12),

              // Avatar
              _PlayerAvatar(player: player),
              const SizedBox(width: 12),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (player.nickname != null)
                      Text(
                        '"${player.nickname}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                  ],
                ),
              ),

              // Status indicators
              _StatusIndicators(player: player),

              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  final int position;

  const _PositionBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = switch (position) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => Colors.grey.shade300,
    };

    final textColor = position <= 3 ? Colors.white : Colors.black87;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: position <= 3
            ? [BoxShadow(color: color.withAlpha(80), blurRadius: 6)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '#$position',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: textColor,
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final PlayerModel player;

  const _PlayerAvatar({required this.player});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: player.avatarUrl != null
          ? CachedNetworkImageProvider(player.avatarUrl!)
          : null,
      child: player.avatarUrl == null
          ? Text(
              player.fullName.isNotEmpty
                  ? player.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            )
          : null,
    );
  }
}

class _StatusIndicators extends StatelessWidget {
  final PlayerModel player;

  const _StatusIndicators({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (player.isOnAmbulance)
          const Tooltip(
            message: 'Ambulancia ativa',
            child: Icon(Icons.local_hospital, color: AppColors.ambulanceActive, size: 18),
          ),
        if (player.isOnCooldown)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Em cooldown',
              child: Icon(Icons.timer, color: AppColors.warning, size: 18),
            ),
          ),
        if (player.isProtected)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Protegido',
              child: Icon(Icons.shield, color: AppColors.info, size: 18),
            ),
          ),
        if (player.hasFeeOverdue)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Mensalidade em atraso',
              child: Icon(Icons.warning_amber, color: AppColors.error, size: 18),
            ),
          ),
      ],
    );
  }
}
