import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'erp_repository.dart';

final erpRepositoryProvider = Provider<ErpRepository>((ref) {
  return ErpRepository();
});

/// Current date for homework display, defaults to today, updates when attendance is marked for a new date.
final currentHomeworkDateProvider = StateProvider<DateTime?>((ref) {
  return DateTime.now();
});
