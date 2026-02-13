import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/ranking_repository.dart';

final rankingListProvider =
    FutureProvider<List<ClubMemberModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getRanking(clubId);
});
