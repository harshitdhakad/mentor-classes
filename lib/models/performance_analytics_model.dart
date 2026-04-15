import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced test marks with performance analytics
class EnhancedTestMarks {
  EnhancedTestMarks({
    required this.id,
    required this.classLevel,
    required this.subject,
    required this.topic,
    required this.testName,
    required this.testType, // 'weekly', 'monthly', 'unit', 'term'
    required this.testKind, // 'single', 'series'
    this.seriesId,
    required this.maxMarks,
    required this.marksByRoll,
    required this.percentageByRoll,
    required this.ranksByRoll,
    required this.notGivenRolls,
    required this.createdAt,
    required this.createdBy,
    this.publishedAt,
  });

  final String id;
  final int classLevel;
  final String subject; // e.g., 'Maths', 'Science', 'Hindi'
  final String topic; // e.g., 'Algebra', 'Physics, Chemistry'
  final String testName;
  final String testType; // 'weekly', 'monthly', 'unit', 'term'
  final String testKind; // 'single' or 'series'
  final String? seriesId; // Reference to test series if applicable
  final double maxMarks;
  
  // Maps: rollNumber -> value
  final Map<String, double> marksByRoll;
  final Map<String, double> percentageByRoll; // Auto-calculated
  final Map<String, int> ranksByRoll; // Auto-calculated
  final List<String> notGivenRolls; // Students who didn't take test
  
  final DateTime createdAt;
  final String createdBy; // Email of teacher who uploaded
  final DateTime? publishedAt;

  /// Get highest score in this test
  double get highestScore {
    if (marksByRoll.isEmpty) return 0;
    return marksByRoll.values.reduce((a, b) => a > b ? a : b);
  }

  /// Get lowest score (excluding NG)
  double get lowestScore {
    if (marksByRoll.isEmpty) return 0;
    return marksByRoll.values.reduce((a, b) => a < b ? a : b);
  }

  /// Get average score
  double get averageScore {
    if (marksByRoll.isEmpty) return 0;
    final sum = marksByRoll.values.fold<double>(0, (a, b) => a + b);
    return sum / marksByRoll.length;
  }

  /// Get class median
  double get medianScore {
    if (marksByRoll.isEmpty) return 0;
    final sorted = marksByRoll.values.toList()..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length % 2 == 1) {
      return sorted[mid].toDouble();
    } else {
      return (sorted[mid - 1] + sorted[mid]) / 2;
    }
  }

  /// Get students who scored above average
  List<String> get topPerformers {
    return marksByRoll.entries
        .where((e) => e.value > averageScore)
        .map((e) => e.key)
        .toList();
  }

  /// Get distribution stats for analytics
  Map<String, int> getScoreDistribution({int bucketSize = 10}) {
    final distribution = <String, int>{};
    for (int i = 0; i <= 100; i += bucketSize) {
      final label = '$i-${i + bucketSize - 1}%';
      distribution[label] = 0;
    }

    for (final percentage in percentageByRoll.values) {
      final bucket = (percentage ~/ bucketSize) * bucketSize;
      final label = '$bucket-${bucket + bucketSize - 1}%';
      distribution[label] = (distribution[label] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get pass/fail count (assuming 40% is pass)
  ({int passed, int failed, int absent}) getPassFailStats({double passPercentage = 40}) {
    int passed = 0;
    int failed = 0;
    int absent = notGivenRolls.length;

    for (final percentage in percentageByRoll.values) {
      if (percentage >= passPercentage) {
        passed++;
      } else {
        failed++;
      }
    }

    return (passed: passed, failed: failed, absent: absent);
  }

  /// Get test date display format
  String getDateDisplay() {
    final formatter = _DateFormatter();
    return formatter.format(createdAt);
  }

  /// Create from Firestore document
  factory EnhancedTestMarks.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final marksByRollMap = data['marks'] as Map<String, dynamic>?;
    final percentageByRollMap = data['percentageByRoll'] as Map<String, dynamic>?;
    final ranksByRollMap = data['ranksByRoll'] as Map<String, dynamic>?;

    return EnhancedTestMarks(
      id: doc.id,
      classLevel: data['classLevel'] as int,
      subject: data['subject'] as String,
      topic: data['topic'] as String,
      testName: data['testName'] as String,
      testType: data['testType'] as String,
      testKind: data['testKind'] as String,
      seriesId: data['seriesId'] as String?,
      maxMarks: (data['maxMarks'] as num).toDouble(),
      marksByRoll: marksByRollMap?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      percentageByRoll: percentageByRollMap?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      ranksByRoll: ranksByRollMap?.map((k, v) => MapEntry(k, v as int)) ?? {},
      notGivenRolls: (data['notGivenRolls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      publishedAt: data['publishedAt'] != null ? (data['publishedAt'] as Timestamp).toDate() : null,
    );
  }
}

/// Helper for date formatting
class _DateFormatter {
  String format(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Student performance analytics over time
class StudentPerformanceAnalytics {
  StudentPerformanceAnalytics({
    required this.rollNumber,
    required this.studentName,
    required this.classLevel,
    required this.testHistories,
  });

  final String rollNumber;
  final String studentName;
  final int classLevel;
  final List<StudentTestHistory> testHistories; // Sorted by date (latest first)

  /// Get overall average percentage
  double get overallAverage {
    if (testHistories.isEmpty) return 0;
    final sum = testHistories.fold<double>(0, (a, b) => a + b.percentage);
    return sum / testHistories.length;
  }

  /// Get trend (improving, stable, declining)
  PerformanceTrend get trend {
    if (testHistories.length < 2) return PerformanceTrend.stable;

    final recent = testHistories.take(3).toList();
    final recentAvg = recent.fold<double>(0, (a, b) => a + b.percentage) / recent.length;

    final older = testHistories.skip(3).take(3).toList();
    if (older.isEmpty) return PerformanceTrend.stable;

    final olderAvg = older.fold<double>(0, (a, b) => a + b.percentage) / older.length;

    if (recentAvg > olderAvg + 5) return PerformanceTrend.improving;
    if (recentAvg < olderAvg - 5) return PerformanceTrend.declining;
    return PerformanceTrend.stable;
  }

  /// Get best test performance
  double get bestPercentage {
    if (testHistories.isEmpty) return 0;
    return testHistories.map((e) => e.percentage).reduce((a, b) => a > b ? a : b);
  }

  /// Get worst test performance
  double get worstPercentage {
    if (testHistories.isEmpty) return 0;
    return testHistories.map((e) => e.percentage).reduce((a, b) => a < b ? a : b);
  }

  /// Get strongest subject based on average
  String? getStrongestSubject() {
    if (testHistories.isEmpty) return null;
    final subjectAvgs = <String, (double, int)>{};

    for (final test in testHistories) {
      final key = subjectAvgs[test.subject] ?? (0.0, 0);
      subjectAvgs[test.subject] = (key.$1 + test.percentage, key.$2 + 1);
    }

    String? strongestSubject;
    double highestAvg = 0;

    for (final entry in subjectAvgs.entries) {
      final avg = entry.value.$1 / entry.value.$2;
      if (avg > highestAvg) {
        highestAvg = avg;
        strongestSubject = entry.key;
      }
    }

    return strongestSubject;
  }

  /// Get weakest subject based on average
  String? getWeakestSubject() {
    if (testHistories.isEmpty) return null;
    final subjectAvgs = <String, (double, int)>{};

    for (final test in testHistories) {
      final key = subjectAvgs[test.subject] ?? (0.0, 0);
      subjectAvgs[test.subject] = (key.$1 + test.percentage, key.$2 + 1);
    }

    String? weakestSubject;
    double lowestAvg = 100;

    for (final entry in subjectAvgs.entries) {
      final avg = entry.value.$1 / entry.value.$2;
      if (avg < lowestAvg) {
        lowestAvg = avg;
        weakestSubject = entry.key;
      }
    }

    return weakestSubject;
  }
}

/// Individual test result for a student
class StudentTestHistory {
  StudentTestHistory({
    required this.testId,
    required this.testName,
    required this.subject,
    required this.topic,
    required this.testType,
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
    required this.classRank,
    required this.totalParticipants,
    required this.testDate,
    this.seriesId,
  });

  final String testId;
  final String testName;
  final String subject;
  final String topic;
  final String? seriesId;
  final String testType; // 'weekly', 'monthly', 'unit', 'term'
  final double marksObtained;
  final double maxMarks;
  final double percentage;
  final int classRank;
  final int totalParticipants;
  final DateTime testDate;

  /// Get performance band based on percentage
  String get performanceBand {
    if (percentage >= 80) return 'A+';
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }

  /// Check if passed (assuming 40% is pass)
  bool get isPassed => percentage >= 40;
}

enum PerformanceTrend {
  improving,
  stable,
  declining,
}
