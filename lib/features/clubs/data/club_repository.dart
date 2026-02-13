import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/club_model.dart';

final clubRepositoryProvider = Provider<ClubRepository>((ref) {
  return ClubRepository(ref.watch(supabaseClientProvider));
});

class ClubRepository {
  final SupabaseClient _client;

  ClubRepository(this._client);

  /// Get all clubs the current player belongs to
  Future<List<ClubModel>> getMyClubs(String playerId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('club:clubs(*)')
          .eq('player_id', playerId)
          .eq('status', 'active');
      return data
          .map((e) => ClubModel.fromJson(e['club'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get a single club by ID
  Future<ClubModel> getClub(String clubId) async {
    try {
      final data = await _client
          .from('clubs')
          .select()
          .eq('id', clubId)
          .single();
      return ClubModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Create a new club via RPC
  Future<String> createClub({
    required String authId,
    required String name,
    String? description,
  }) async {
    try {
      final result = await _client.rpc('create_club', params: {
        'p_auth_id': authId,
        'p_name': name,
        'p_description': description,
      });
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Request to join a club by invite code
  Future<String> joinClubByCode({
    required String authId,
    required String inviteCode,
  }) async {
    try {
      final result = await _client.rpc('join_club_by_code', params: {
        'p_auth_id': authId,
        'p_invite_code': inviteCode,
      });
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get members of a club (with player data)
  Future<List<ClubMemberModel>> getMembers(String clubId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .order('ranking_position', ascending: true);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get the current player's membership for a specific club
  Future<ClubMemberModel?> getMyMembership(String clubId, String playerId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .eq('player_id', playerId)
          .eq('status', 'active')
          .maybeSingle();
      if (data == null) return null;
      return ClubMemberModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get pending join requests for a club
  Future<List<Map<String, dynamic>>> getJoinRequests(String clubId) async {
    try {
      final data = await _client
          .from('club_join_requests')
          .select('*, player:players(full_name, avatar_url)')
          .eq('club_id', clubId)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Approve a join request
  Future<void> approveJoinRequest(String requestId, String adminAuthId) async {
    try {
      await _client.rpc('approve_join_request', params: {
        'p_request_id': requestId,
        'p_admin_auth_id': adminAuthId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId, String adminAuthId) async {
    try {
      await _client.rpc('reject_join_request', params: {
        'p_request_id': requestId,
        'p_admin_auth_id': adminAuthId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update member role (promote/demote)
  Future<void> updateMemberRole(String memberId, String role) async {
    try {
      await _client
          .from('club_members')
          .update({'role': role})
          .eq('id', memberId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Remove a member from the club
  Future<void> removeMember(String memberId) async {
    try {
      await _client
          .from('club_members')
          .update({'status': 'inactive'})
          .eq('id', memberId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update club details
  Future<void> updateClub(String clubId, {String? name, String? description}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      await _client.from('clubs').update(updates).eq('id', clubId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Regenerate invite code
  Future<String> regenerateInviteCode(String clubId) async {
    try {
      final newCode = await _client.rpc('generate_invite_code');
      await _client
          .from('clubs')
          .update({'invite_code': newCode})
          .eq('id', clubId);
      return newCode as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
