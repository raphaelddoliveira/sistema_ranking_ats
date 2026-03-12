import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clubs/viewmodel/club_providers.dart';
import '../data/feed_repository.dart';

final feedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];

  final repository = ref.watch(feedRepositoryProvider);
  return repository.getFeed(clubId: clubId, sportId: sportId);
});
