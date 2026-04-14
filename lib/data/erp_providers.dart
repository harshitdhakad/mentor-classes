import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/academic_resource_model.dart';
import '../models/homework_model.dart';
import '../models/performance_analytics_model.dart';
import '../models/student_batch_model.dart';
import '../models/syllabus_tracker_model.dart';
import 'erp_repository.dart';

final erpRepositoryProvider = Provider<ErpRepository>((ref) {
  return ErpRepository();
});

/// Current date for homework display, defaults to today, updates when attendance is marked for a new date.
class CurrentHomeworkDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setDate(DateTime date) {
    state = date;
  }
}

final currentHomeworkDateProvider =
    NotifierProvider<CurrentHomeworkDateNotifier, DateTime>(
  CurrentHomeworkDateNotifier.new,
);

// ====================== ACADEMIC RESOURCES ======================

/// Selected class level provider (for filtering resources and students)
class SelectedClassNotifier extends Notifier<int> {
  @override
  int build() {
    return 5; // Default to class 5
  }

  void setClass(int classLevel) {
    state = (classLevel >= 5 && classLevel <= 10) ? classLevel : 5;
  }
}

final selectedClassProvider = NotifierProvider<SelectedClassNotifier, int>(
  SelectedClassNotifier.new,
);

/// Selected resource type filter (notes, test_papers, worksheets)
class SelectedResourceTypeNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null; // Show all by default
  }

  void setType(String? type) {
    state = type;
  }
}

final selectedResourceTypeProvider = NotifierProvider<SelectedResourceTypeNotifier, String?>(
  SelectedResourceTypeNotifier.new,
);

/// Selected subject filter
class SelectedSubjectNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null; // Show all by default
  }

  void setSubject(String? subject) {
    state = subject;
  }
}

final selectedSubjectProvider = NotifierProvider<SelectedSubjectNotifier, String?>(
  SelectedSubjectNotifier.new,
);

/// Academic resources for selected class and filters
final academicResourcesProvider =
    StreamProvider.family<List<AcademicResource>, (int, String?, String?)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, subject, resourceType) = params;
    return repo.watchResourcesByFilter(
      classLevel: classLevel,
      subject: subject,
      resourceType: resourceType,
    );
  },
);

/// Get subjects available for a class
final subjectsForClassProvider = FutureProvider.family<List<String>, int>(
  (ref, classLevel) {
    final repo = ref.watch(erpRepositoryProvider);
    return repo.getSubjectsForClass(classLevel);
  },
);

// ====================== STUDENT & BATCH MANAGEMENT ======================

/// Enhanced student list for batch management
final studentsByClassEnhancedProvider = FutureProvider.family<List<EnhancedStudentItem>, int>(
  (ref, classLevel) {
    final repo = ref.watch(erpRepositoryProvider);
    return repo.fetchStudentsByClassEnhanced(classLevel);
  },
);

/// Refresh state notifier for triggering rebuilds
class RefreshTriggerNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void refresh() {
    state++;
  }
}

final refreshTriggerProvider = NotifierProvider<RefreshTriggerNotifier, int>(
  RefreshTriggerNotifier.new,
);

// ====================== PERFORMANCE ANALYTICS ======================

/// Performance analytics for a specific student
final studentPerformanceProvider =
    FutureProvider.family<StudentPerformanceAnalytics?, (int, String, String)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, rollNumber, studentName) = params;
    return repo.fetchStudentPerformanceAnalytics(
      classLevel: classLevel,
      rollNumber: rollNumber,
      studentName: studentName,
    );
  },
);

/// Selected test type filter (weekly, monthly, unit, term)
class SelectedTestTypeNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null; // Show all by default
  }

  void setType(String? type) {
    state = type;
  }
}

final selectedTestTypeProvider = NotifierProvider<SelectedTestTypeNotifier, String?>(
  SelectedTestTypeNotifier.new,
);

/// Enhanced test marks for a class with filters
final testMarksForClassProvider =
    FutureProvider.family<List<EnhancedTestMarks>, (int, String?, String?)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, testType, subject) = params;
    return repo.fetchTestMarksForClass(
      classLevel: classLevel,
      testType: testType,
      subject: subject,
    );
  },
);

/// Class-wide performance summary for leaderboard view
final classPerformanceSummaryProvider =
    StreamProvider.family<List<StudentPerformanceSummary>, int>(
  (ref, classLevel) {
    final repo = ref.watch(erpRepositoryProvider);
    return repo.watchClassPerformanceSummary(classLevel);
  },
);

// ====================== SYLLABUS TRACKER ======================

/// Selected class for syllabus tracking (teacher view)
class SelectedSyllabusClassNotifier extends Notifier<int> {
  @override
  int build() {
    return 5; // Default to class 5
  }

  void setClass(int classLevel) {
    state = (classLevel >= 5 && classLevel <= 10) ? classLevel : 5;
  }
}

final selectedSyllabusClassProvider = NotifierProvider<SelectedSyllabusClassNotifier, int>(
  SelectedSyllabusClassNotifier.new,
);

/// Get class syllabus with all 4 core subjects and their chapters
final classSyllabusProvider = FutureProvider.family<ClassSyllabus, int>(
  (ref, classLevel) {
    final repo = ref.watch(erpRepositoryProvider);
    return repo.getClassSyllabus(classLevel);
  },
);

// ====================== ATTENDANCE & PERFORMANCE SUMMARY ======================

/// Get student attendance summary for academic year
final studentAttendanceSummaryProvider =
    FutureProvider.family<dynamic, (int, String, String)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, rollNumber, studentName) = params;
    return repo.getStudentAttendanceSummary(
      classLevel: classLevel,
      rollNumber: rollNumber,
      studentName: studentName,
    );
  },
);

/// Get month attendance records for a class
final monthAttendanceRecordsProvider =
    FutureProvider.family<List<dynamic>, (int, DateTime)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, month) = params;
    return repo.getMonthAttendanceRecords(classLevel, month);
  },
);

// ====================== HOMEWORK MANAGEMENT ======================

/// Watch homework for a specific class (subject-based structure)
/// Returns a Map<String, HomeWorkAssignment> where key is the subject
final watchHomeworkForClassProvider = StreamProvider.family<Map<String, HomeWorkAssignment>, int>(
  (ref, classLevel) {
    final repo = ref.watch(erpRepositoryProvider);
    return repo.watchHomeworkForClass(classLevel);
  },
);

/// Get homework for a specific class and subject
final getHomeworkForClassAndSubjectProvider = FutureProvider.family<dynamic, (int, String)>(
  (ref, params) {
    final repo = ref.watch(erpRepositoryProvider);
    final (classLevel, subject) = params;
    return repo.getHomeworkForClassAndSubject(classLevel: classLevel, subject: subject);
  },
);
