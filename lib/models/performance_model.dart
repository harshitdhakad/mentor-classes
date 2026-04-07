/// Performance metrics for a student
class StudentPerformance {
  final String studentRoll;
  final String studentName;
  final int classLevel;
  
  int totalTestsGiven = 0;
  int totalClassesAttended = 0;
  int totalClassesHeld = 0;
  double averageMarks = 0.0;
  double highestMarks = 0.0;
  double lowestMarks = 0.0;
  
  // Performance category
  PerformanceCategory category;

  StudentPerformance({
    required this.studentRoll,
    required this.studentName,
    required this.classLevel,
    this.category = PerformanceCategory.average,
  });

  double get attendancePercentage {
    if (totalClassesHeld == 0) return 0.0;
    return (totalClassesAttended / totalClassesHeld * 100).clamp(0.0, 100.0);
  }

  // Determine performance category based on average marks
  void updateCategory(List<double> allClassAverages) {
    if (allClassAverages.isEmpty) {
      category = PerformanceCategory.average;
      return;
    }

    allClassAverages.sort((a, b) => b.compareTo(a));
    final topThreshold = allClassAverages.length > 2 ? allClassAverages[2] : allClassAverages.first;
    final bottomThreshold = allClassAverages.length > 2 ? allClassAverages[allClassAverages.length - 3] : allClassAverages.last;

    if (averageMarks >= topThreshold) {
      category = PerformanceCategory.topper;
    } else if (averageMarks <= bottomThreshold) {
      category = PerformanceCategory.needsImprovement;
    } else {
      category = PerformanceCategory.average;
    }
  }
}

enum PerformanceCategory {
  topper,
  average,
  needsImprovement,
}

extension PerformanceCategoryExt on PerformanceCategory {
  String get label {
    switch (this) {
      case PerformanceCategory.topper:
        return 'Topper';
      case PerformanceCategory.average:
        return 'Average';
      case PerformanceCategory.needsImprovement:
        return 'Needs Improvement';
    }
  }

  String get emoji {
    switch (this) {
      case PerformanceCategory.topper:
        return '⭐';
      case PerformanceCategory.average:
        return '📊';
      case PerformanceCategory.needsImprovement:
        return '⚠️';
    }
  }
}