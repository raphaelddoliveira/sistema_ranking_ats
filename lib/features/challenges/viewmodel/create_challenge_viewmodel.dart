import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/challenge_repository.dart';

final eligibleOpponentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getEligibleOpponents();
});

final createChallengeProvider =
    StateNotifierProvider<CreateChallengeNotifier, AsyncValue<void>>((ref) {
  return CreateChallengeNotifier(ref.watch(challengeRepositoryProvider));
});

class CreateChallengeNotifier extends StateNotifier<AsyncValue<void>> {
  final ChallengeRepository _repository;

  CreateChallengeNotifier(this._repository)
      : super(const AsyncData(null));

  Future<String?> createChallenge(String challengedId) async {
    state = const AsyncLoading();
    try {
      final challengeId = await _repository.createChallenge(challengedId);
      state = const AsyncData(null);
      return challengeId;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
