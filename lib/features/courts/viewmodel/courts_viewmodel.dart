import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/court_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/court_repository.dart';

final courtsListProvider = FutureProvider<List<CourtModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getCourts(clubId: clubId);
});
