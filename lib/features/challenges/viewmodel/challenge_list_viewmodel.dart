import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/challenge_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/challenge_repository.dart';

final activeChallengesProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getActiveChallenges(clubId: clubId, sportId: sportId);
});

final challengeHistoryProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getChallengeHistory(clubId: clubId, sportId: sportId);
});
