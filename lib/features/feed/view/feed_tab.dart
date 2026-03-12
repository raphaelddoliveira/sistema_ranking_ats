import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/feed_repository.dart';
import '../viewmodel/feed_viewmodel.dart';
import 'widgets/feed_section_header.dart';
import 'widgets/match_result_card.dart';
import 'widgets/new_member_card.dart';

class FeedTab extends ConsumerWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return feedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _EmptyFeed();
        }

        // Group items by time period
        final groups = _groupByTimePeriod(items);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(feedProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 100),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeedSectionHeader(title: group.title),
                  ...group.items.map((item) => switch (item) {
                        MatchResultFeedItem() =>
                          MatchResultCard(item: item),
                        NewMemberFeedItem() =>
                          NewMemberCard(item: item),
                      }),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Erro ao carregar feed',
                style: TextStyle(color: AppColors.onBackgroundMedium)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(feedProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  List<_FeedGroup> _groupByTimePeriod(List<FeedItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<FeedItem>> grouped = {};
    final order = <String>[];

    for (final item in items) {
      final local = item.timestamp.toLocal();
      final date = DateTime(local.year, local.month, local.day);

      String label;
      if (!date.isBefore(today)) {
        label = 'Hoje';
      } else if (!date.isBefore(yesterday)) {
        label = 'Ontem';
      } else if (date.isAfter(weekAgo)) {
        label = 'Esta semana';
      } else {
        label = 'Anteriores';
      }

      if (!grouped.containsKey(label)) {
        grouped[label] = [];
        order.add(label);
      }
      grouped[label]!.add(item);
    }

    return order
        .map((label) => _FeedGroup(title: label, items: grouped[label]!))
        .toList();
  }
}

class _FeedGroup {
  final String title;
  final List<FeedItem> items;

  _FeedGroup({required this.title, required this.items});
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dynamic_feed_outlined,
                size: 64, color: AppColors.onBackgroundLight),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma atividade ainda',
              style: TextStyle(
                  fontSize: 16, color: AppColors.onBackgroundLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seja o primeiro a desafiar!',
              style: TextStyle(
                  fontSize: 13, color: AppColors.onBackgroundLight),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.go('/challenges'),
              icon: const Icon(Icons.flash_on),
              label: const Text('Criar Desafio'),
            ),
          ],
        ),
      ),
    );
  }
}
