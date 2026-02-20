import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/court_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../courts/data/court_repository.dart';

/// All active courts for the current club + sport (for challenge court selection)
final challengeCourtsProvider =
    FutureProvider<List<CourtModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getCourts(clubId: clubId, sportId: sportId);
});
