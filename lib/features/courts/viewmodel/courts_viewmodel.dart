import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/court_model.dart';
import '../data/court_repository.dart';

final courtsListProvider = FutureProvider<List<CourtModel>>((ref) async {
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getCourts();
});
