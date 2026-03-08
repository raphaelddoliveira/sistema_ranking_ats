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

final upcomingChallengesProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getUpcomingChallenges(clubId: clubId, sportId: sportId);
});

/// Set of player IDs that have an active challenge (for ranking badges)
final playersWithActiveChallengeProvider =
    FutureProvider<Set<String>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return {};
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getPlayersWithActiveChallenges(clubId: clubId, sportId: sportId);
});

final allChallengeHistoryProvider =
    FutureProvider<List<ChallengeModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getAllChallengeHistory(clubId: clubId, sportId: sportId);
});
