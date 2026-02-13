import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/player_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});

class AuthRepository {
  final AuthService _authService;
  final SupabaseClient _client;

  AuthRepository(this._authService, this._client);

  User? get currentUser => _authService.currentUser;
  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  Future<PlayerModel> signInWithEmail(String email, String password) async {
    final response = await _authService.signInWithEmail(email, password);
    return _getOrCreatePlayer(response.user!);
  }

  Future<PlayerModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _authService.signUpWithEmail(email, password);
    final user = response.user;

    if (user == null) {
      throw const AuthException('Erro ao criar conta. Tente novamente.');
    }

    return _createPlayer(
      authId: user.id,
      email: email,
      fullName: fullName,
      phone: phone,
    );
  }

  Future<PlayerModel> signInWithGoogle() async {
    final response = await _authService.signInWithGoogle();
    return _getOrCreatePlayer(response.user!);
  }

  Future<void> signInWithApple() async {
    await _authService.signInWithApple();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<PlayerModel?> getCurrentPlayer() async {
    final user = _authService.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return PlayerModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<PlayerModel> _getOrCreatePlayer(User user) async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data != null) return PlayerModel.fromJson(data);

      // Auto-create player on first social login
      return _createPlayer(
        authId: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String? ??
            user.email?.split('@').first ??
            'Jogador',
        phone: user.phone,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<PlayerModel> _createPlayer({
    required String authId,
    required String email,
    required String fullName,
    String? phone,
  }) async {
    try {
      final data = await _client
          .from(SupabaseConstants.playersTable)
          .insert({
            'auth_id': authId,
            'email': email,
            'full_name': fullName,
            'phone': phone,
          })
          .select()
          .single();

      return PlayerModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
