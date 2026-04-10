/// Enhanced student list item with batch management info
class EnhancedStudentItem {
  EnhancedStudentItem({
    required this.rowIndex,
    required this.rollNumber,
    required this.name,
    required this.docId,
    required this.classLevel,
    required this.totalFees,
    required this.remainingFees,
    this.enrolledDate,
    this.isActive = true,
    this.password,
  });

  final int rowIndex;
  final String rollNumber;
  final String name;
  final String docId;
  final int classLevel;
  final double totalFees;
  final double remainingFees;
  final DateTime? enrolledDate;
  final bool isActive;
  final String? password;

  double get paidFees => (totalFees - remainingFees).clamp(0.0, totalFees);

  /// Get color index for display purposes
  int get colorIndex => rowIndex % 3;

  /// Get status label
  String get statusLabel {
    if (remainingFees <= 0) return 'Fees Paid ✓';
    if (remainingFees < 1000) return 'Minor Dues';
    return 'Pending';
  }

  /// Get dues percentage
  int get duesPercentage {
    if (totalFees == 0) return 0;
    return ((remainingFees / totalFees) * 100).toInt();
  }
}

/// Student performance summary for dashboard
class StudentPerformanceSummary {
  StudentPerformanceSummary({
    required this.rollNumber,
    required this.name,
    required this.classLevel,
    this.lastTestScore,
    this.lastTestPercentage,
    this.averagePercentage,
    this.classRank,
    this.testsGiven = 0,
  });

  final String rollNumber;
  final String name;
  final int classLevel;
  final double? lastTestScore;
  final double? lastTestPercentage;
  final double? averagePercentage;
  final int? classRank;
  final int testsGiven;

  /// Get performance color category
  PerformanceCategory get performanceCategory {
    final avg = averagePercentage ?? 0;
    if (avg >= 80) return PerformanceCategory.excellent;
    if (avg >= 60) return PerformanceCategory.good;
    if (avg >= 40) return PerformanceCategory.average;
    return PerformanceCategory.needsImprovement;
  }

  /// Get performance text
  String get performanceText {
    switch (performanceCategory) {
      case PerformanceCategory.excellent:
        return 'Excellent';
      case PerformanceCategory.good:
        return 'Good';
      case PerformanceCategory.average:
        return 'Average';
      case PerformanceCategory.needsImprovement:
        return 'Needs Improvement';
    }
  }
}

enum PerformanceCategory {
  excellent,
  good,
  average,
  needsImprovement,
}
