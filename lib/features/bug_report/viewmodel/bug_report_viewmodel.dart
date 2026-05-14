import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../data/bug_report_repository.dart';

final bugReportProvider =
    StateNotifierProvider<BugReportNotifier, AsyncValue<void>>((ref) {
  return BugReportNotifier(ref.watch(bugReportRepositoryProvider));
});

class BugReportNotifier extends StateNotifier<AsyncValue<void>> {
  final BugReportRepository _repository;

  BugReportNotifier(this._repository) : super(const AsyncData(null));

  Future<bool> submit({
    required String playerId,
    String? clubId,
    required String reportType,
    required String description,
    String? screenName,
    XFile? screenshot,
    String? appVersion,
    String? userAgent,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.submitReport(
        playerId: playerId,
        clubId: clubId,
        reportType: reportType,
        description: description,
        screenName: screenName,
        screenshot: screenshot,
        appVersion: appVersion,
        userAgent: userAgent,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
