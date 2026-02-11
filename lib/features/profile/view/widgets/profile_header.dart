import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/player_model.dart';

class ProfileHeader extends StatelessWidget {
  final PlayerModel player;

  const ProfileHeader({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: player.avatarUrl != null
              ? CachedNetworkImageProvider(player.avatarUrl!)
              : null,
          child: player.avatarUrl == null
              ? Text(
                  player.fullName.isNotEmpty
                      ? player.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 36),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          player.fullName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (player.nickname != null) ...[
          const SizedBox(height: 4),
          Text(
            '"${player.nickname}"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          player.email,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}
