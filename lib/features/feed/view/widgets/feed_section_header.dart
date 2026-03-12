import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class FeedSectionHeader extends StatelessWidget {
  final String title;

  const FeedSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onBackgroundMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
