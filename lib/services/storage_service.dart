import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/error_handler.dart';
import 'supabase_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseStorageProvider));
});

class StorageService {
  final SupabaseStorageClient _storage;

  StorageService(this._storage);

  Future<String> uploadAvatar(String playerId, XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final path = '$playerId/avatar.$ext';

      await _storage
          .from(SupabaseConstants.avatarsBucket)
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));

      return _storage
          .from(SupabaseConstants.avatarsBucket)
          .getPublicUrl(path);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> uploadReceipt(String playerId, String feeId, XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final path = '$playerId/$feeId.$ext';

      await _storage
          .from(SupabaseConstants.receiptsBucket)
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));

      return _storage
          .from(SupabaseConstants.receiptsBucket)
          .getPublicUrl(path);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
