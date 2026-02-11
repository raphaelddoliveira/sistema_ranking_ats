import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notifications/viewmodel/notification_viewmodel.dart';
import '../providers/current_player_provider.dart';
import '../../features/admin/view/admin_dashboard_screen.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  static const _tabs = [
    RouteNames.ranking,
    RouteNames.challenges,
    RouteNames.courts,
    RouteNames.notifications,
    RouteNames.profile,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final unreadAsync = ref.watch(unreadCountProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final isAdmin = currentPlayer.valueOrNull?.isAdmin ?? false;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index]),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis),
            label: 'Desafios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Quadras',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: (unreadAsync.valueOrNull ?? 0) > 0,
              label: Text(
                '${unreadAsync.valueOrNull ?? 0}',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alertas',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: isAdmin && currentIndex == 0
          ? FloatingActionButton.small(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.admin_panel_settings, size: 20),
            )
          : null,
    );
  }
}
