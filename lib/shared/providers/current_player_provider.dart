import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../shared/models/player_model.dart';
import 'auth_state_provider.dart';

final currentPlayerProvider = FutureProvider<PlayerModel?>((ref) async {
  // Re-fetch when auth state changes
  ref.watch(authStateProvider);

  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getCurrentPlayer();
});
