import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/club_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../data/club_repository.dart';

/// Currently selected club ID
final currentClubIdProvider = StateProvider<String?>((ref) => null);

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

/// Current player's membership in the selected club
final currentClubMemberProvider = FutureProvider<ClubMemberModel?>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final player = ref.watch(currentPlayerProvider).valueOrNull;
  if (clubId == null || player == null) return null;
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getMyMembership(clubId, player.id);
});

/// Whether current player is admin of the selected club
final isClubAdminProvider = Provider<bool>((ref) {
  final member = ref.watch(currentClubMemberProvider).valueOrNull;
  return member?.isClubAdmin ?? false;
});

/// Members of the selected club
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
