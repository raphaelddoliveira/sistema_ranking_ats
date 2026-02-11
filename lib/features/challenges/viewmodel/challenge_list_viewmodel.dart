import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/challenge_model.dart';
import '../data/challenge_repository.dart';

final activeChallengesProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getActiveChallenges();
});

final challengeHistoryProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getChallengeHistory();
});
