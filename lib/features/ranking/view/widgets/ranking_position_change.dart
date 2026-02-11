import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RankingPositionChange extends StatelessWidget {
  final int change;
  final double iconSize;
  final double fontSize;

  const RankingPositionChange({
    super.key,
    required this.change,
    this.iconSize = 16,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    if (change == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove, size: iconSize, color: AppColors.rankSame),
          Text(
            '0',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.rankSame,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final isUp = change > 0;
    final color = isUp ? AppColors.rankUp : AppColors.rankDown;
    final icon = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize + 4, color: color),
        Text(
          '${change.abs()}',
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
