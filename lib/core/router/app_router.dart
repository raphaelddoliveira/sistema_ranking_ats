import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/auth/view/forgot_password_screen.dart';
import '../../features/ranking/view/ranking_screen.dart';
import '../../features/challenges/view/challenges_screen.dart';
import '../../features/challenges/view/create_challenge_screen.dart';
import '../../features/challenges/view/challenge_detail_screen.dart';
import '../../features/courts/view/courts_screen.dart';
import '../../features/courts/view/court_schedule_screen.dart';
import '../../features/courts/view/my_reservations_screen.dart';
import '../../shared/models/court_model.dart';
import '../../features/notifications/view/notifications_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../services/supabase_service.dart';
import '../constants/route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: RouteNames.ranking,
    refreshListenable: _GoRouterAuthRefresh(supabase.auth),
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return RouteNames.login;
      if (isLoggedIn && isAuthRoute) return RouteNames.ranking;
      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main app routes with bottom nav
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: RouteNames.ranking,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RankingScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.challenges,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChallengesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateChallengeScreen(),
              ),
              GoRoute(
                path: ':challengeId',
                builder: (context, state) => ChallengeDetailScreen(
                  challengeId: state.pathParameters['challengeId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.courts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CourtsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'my-reservations',
                builder: (context, state) =>
                    const MyReservationsScreen(),
              ),
              GoRoute(
                path: ':courtId',
                builder: (context, state) => CourtScheduleScreen(
                  court: state.extra! as CourtModel,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.notifications,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Converts Supabase auth state changes into a [ChangeNotifier]
/// so GoRouter can react to auth events.
class _GoRouterAuthRefresh extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _GoRouterAuthRefresh(GoTrueClient auth) {
    _subscription = auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
