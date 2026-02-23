import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/h2h_model.dart';
import '../data/challenge_repository.dart';

final h2hProvider = FutureProvider.family<H2HModel,
    ({String p1, String p2, String clubId, String? sportId})>(
  (ref, params) async {
    final repository = ref.watch(challengeRepositoryProvider);
    return repository.getH2HStats(
      params.p1,
      params.p2,
      clubId: params.clubId,
      sportId: params.sportId,
    );
  },
);
