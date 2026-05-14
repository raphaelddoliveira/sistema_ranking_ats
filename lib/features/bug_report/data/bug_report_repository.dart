import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';

final bugReportRepositoryProvider = Provider<BugReportRepository>((ref) {
  return BugReportRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});

class BugReportRepository {
  final SupabaseClient _client;
  final StorageService _storage;

  BugReportRepository(this._client, this._storage);

  Future<String> submitReport({
    required String playerId,
    String? clubId,
    required String reportType,
    required String description,
    String? screenName,
    XFile? screenshot,
    String? appVersion,
    String? userAgent,
  }) async {
    try {
      // 1. Insert report row first to get the ID
      final inserted = await _client
          .from(SupabaseConstants.bugReportsTable)
          .insert({
            'player_id': playerId,
            if (clubId != null) 'club_id': clubId,
            'report_type': reportType,
            'description': description,
            if (screenName != null) 'screen_name': screenName,
            if (appVersion != null) 'app_version': appVersion,
            if (userAgent != null) 'user_agent': userAgent,
          })
          .select('id')
          .single();

      final reportId = inserted['id'] as String;

      // 2. Upload screenshot if provided, then update row with URL
      if (screenshot != null) {
        final url =
            await _storage.uploadBugReportScreenshot(reportId, screenshot);
        await _client
            .from(SupabaseConstants.bugReportsTable)
            .update({'screenshot_url': url}).eq('id', reportId);
      }

      return reportId;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
