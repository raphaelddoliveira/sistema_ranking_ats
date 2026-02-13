import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../viewmodel/club_providers.dart';

/// Reusable AppBar title with club name as tappable pill subtitle.
Widget clubAppBarTitle(String title, BuildContext context, WidgetRef ref) {
  final currentClub = ref.watch(currentClubProvider);
  final clubName = currentClub.valueOrNull?.name;

  return GestureDetector(
    onTap: () => openClubSelector(context, ref),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (clubName != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clubName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(210),
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 16, color: Colors.white.withAlpha(210)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Opens the club selector bottom sheet.
void openClubSelector(BuildContext context, WidgetRef ref) {
  final clubs = ref.read(myClubsProvider).valueOrNull ?? [];
  final currentClubId = ref.read(currentClubIdProvider);

  if (clubs.isEmpty) {
    // No clubs — show options to create or join
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Comece agora',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Crie um clube ou entre em um existente',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.onBackgroundLight,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Icon(Icons.add, size: 18, color: AppColors.onBackgroundLight),
                ),
                title: const Text('Criar novo clube'),
                subtitle: const Text('Voce sera o administrador'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/clubs/create');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.onBackgroundLight),
                ),
                title: const Text('Entrar com codigo'),
                subtitle: const Text('Digite o codigo de convite do clube'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/clubs/join');
                },
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  final currentClub = currentClubId != null
      ? clubs.where((c) => c.id == currentClubId).firstOrNull ?? clubs.first
      : clubs.first;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Trocar clube',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...clubs.map((club) {
              final isSelected = club.id == currentClub.id;
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: isSelected
                      ? AppColors.primary.withAlpha(25)
                      : AppColors.surfaceVariant,
                  child: Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: isSelected ? AppColors.primary : AppColors.onBackgroundLight,
                  ),
                ),
                title: Text(
                  club.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  ref.read(currentClubIdProvider.notifier).state = club.id;
                  Navigator.pop(ctx);
                },
              );
            }),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(Icons.add, size: 18, color: AppColors.onBackgroundLight),
              ),
              title: const Text('Criar novo clube'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/clubs/create');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(Icons.login, size: 18, color: AppColors.onBackgroundLight),
              ),
              title: const Text('Entrar em um clube'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/clubs/join');
              },
            ),
          ],
        ),
      ),
    ),
  );
}
