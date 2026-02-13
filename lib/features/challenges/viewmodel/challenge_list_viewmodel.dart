import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/challenge_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/challenge_repository.dart';

final activeChallengesProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getActiveChallenges(clubId: clubId);
});

final challengeHistoryProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getChallengeHistory(clubId: clubId);
});
