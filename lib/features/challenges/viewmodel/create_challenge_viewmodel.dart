import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/challenge_repository.dart';

final eligibleOpponentsProvider =
    FutureProvider<List<ClubMemberModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getEligibleOpponents(clubId: clubId);
});

final createChallengeProvider =
    StateNotifierProvider<CreateChallengeNotifier, AsyncValue<void>>((ref) {
  return CreateChallengeNotifier(
    ref.watch(challengeRepositoryProvider),
    ref.watch(currentClubIdProvider),
  );
});

class CreateChallengeNotifier extends StateNotifier<AsyncValue<void>> {
  final ChallengeRepository _repository;
  final String? _clubId;

  CreateChallengeNotifier(this._repository, this._clubId)
      : super(const AsyncData(null));

  Future<String?> createChallenge(String challengedId) async {
    if (_clubId == null) return null;
    state = const AsyncLoading();
    try {
      final challengeId = await _repository.createChallenge(
        challengedId,
        clubId: _clubId,
      );
      state = const AsyncData(null);
      return challengeId;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
