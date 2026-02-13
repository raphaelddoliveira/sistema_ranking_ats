import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/challenge_repository.dart';

final eligibleOpponentsProvider =
    FutureProvider<List<ClubMemberModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null || sportId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getEligibleOpponents(clubId: clubId, sportId: sportId);
});

final createChallengeProvider =
    StateNotifierProvider<CreateChallengeNotifier, AsyncValue<void>>((ref) {
  return CreateChallengeNotifier(
    ref.watch(challengeRepositoryProvider),
    ref.watch(currentClubIdProvider),
    ref.watch(currentSportIdProvider),
  );
});

class CreateChallengeNotifier extends StateNotifier<AsyncValue<void>> {
  final ChallengeRepository _repository;
  final String? _clubId;
  final String? _sportId;

  CreateChallengeNotifier(this._repository, this._clubId, this._sportId)
      : super(const AsyncData(null));

  Future<String?> createChallenge(String challengedId) async {
    if (_clubId == null || _sportId == null) return null;
    state = const AsyncLoading();
    try {
      final challengeId = await _repository.createChallenge(
        challengedId,
        clubId: _clubId,
        sportId: _sportId,
      );
      state = const AsyncData(null);
      return challengeId;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
