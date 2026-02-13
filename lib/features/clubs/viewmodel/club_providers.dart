import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/club_model.dart';
import '../../../shared/models/sport_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../data/club_repository.dart';

/// Currently selected club ID
final currentClubIdProvider = StateProvider<String?>((ref) => null);

/// Currently selected sport ID
final currentSportIdProvider = StateProvider<String?>((ref) => null);

/// List of clubs the current player belongs to
final myClubsProvider = FutureProvider<List<ClubModel>>((ref) async {
  final player = ref.watch(currentPlayerProvider).valueOrNull;
  if (player == null) return [];
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getMyClubs(player.id);
});

/// Currently selected club details
final currentClubProvider = FutureProvider<ClubModel?>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return null;
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getClub(clubId);
});

/// Sports enabled for the currently selected club
final clubSportsProvider = FutureProvider<List<ClubSportModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getClubSports(clubId);
});

/// All available sports (reference table)
final allSportsProvider = FutureProvider<List<SportModel>>((ref) async {
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getAllSports();
});

/// Currently selected sport details (derived from clubSports + currentSportId)
final currentSportProvider = FutureProvider<SportModel?>((ref) async {
  final sportId = ref.watch(currentSportIdProvider);
  final clubSports = ref.watch(clubSportsProvider).valueOrNull ?? [];
  if (sportId == null || clubSports.isEmpty) return null;
  try {
    return clubSports.firstWhere((cs) => cs.sportId == sportId).sport;
  } catch (_) {
    return null;
  }
});

/// Current player's membership in the selected club + sport
final currentClubMemberProvider = FutureProvider<ClubMemberModel?>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  final player = ref.watch(currentPlayerProvider).valueOrNull;
  if (clubId == null || player == null) return null;
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getMyMembership(clubId, player.id, sportId: sportId);
});

/// Whether current player is admin of the selected club (any sport row)
final isClubAdminProvider = Provider<bool>((ref) {
  final member = ref.watch(currentClubMemberProvider).valueOrNull;
  return member?.isClubAdmin ?? false;
});

/// Members of the selected club (all sports, used in management)
final clubMembersProvider = FutureProvider.family<List<ClubMemberModel>, String>(
  (ref, clubId) async {
    final repo = ref.watch(clubRepositoryProvider);
    return repo.getMembers(clubId);
  },
);

/// Pending join requests for the selected club
final clubJoinRequestsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, clubId) async {
    final repo = ref.watch(clubRepositoryProvider);
    return repo.getJoinRequests(clubId);
  },
);
