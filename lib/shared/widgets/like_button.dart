import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/challenges/viewmodel/challenge_like_viewmodel.dart';

class LikeButton extends StatelessWidget {
  final String challengeId;
  final WidgetRef ref;

  const LikeButton({super.key, required this.challengeId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final likeAsync = ref.watch(challengeLikeProvider(challengeId));
    final count = likeAsync.valueOrNull?.count ?? 0;
    final liked = likeAsync.valueOrNull?.liked ?? false;

    return GestureDetector(
      onTap: () {
        ref.read(challengeLikeActionProvider.notifier).toggleLike(challengeId);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: liked ? AppColors.error : AppColors.onBackgroundLight,
            ),
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: liked ? AppColors.error : AppColors.onBackgroundLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
