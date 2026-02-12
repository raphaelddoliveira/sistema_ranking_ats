import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';

final loginViewModelProvider =
    StateNotifierProvider.autoDispose<LoginViewModel, AsyncValue<void>>((ref) {
  return LoginViewModel(ref.watch(authRepositoryProvider));
});

class LoginViewModel extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  LoginViewModel(this._authRepository) : super(const AsyncData(null));

  Future<void> loginWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithEmail(email, password);
      if (mounted) state = const AsyncData(null);
    } on AppException catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithGoogle();
      if (mounted) state = const AsyncData(null);
    } on AppException catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }

  Future<void> loginWithApple() async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithApple();
      if (mounted) state = const AsyncData(null);
    } on AppException catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }
}
