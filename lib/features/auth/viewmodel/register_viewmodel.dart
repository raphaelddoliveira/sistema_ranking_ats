import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';

final registerViewModelProvider =
    StateNotifierProvider.autoDispose<RegisterViewModel, AsyncValue<void>>(
        (ref) {
  return RegisterViewModel(ref.watch(authRepositoryProvider));
});

class RegisterViewModel extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  RegisterViewModel(this._authRepository) : super(const AsyncData(null));

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
