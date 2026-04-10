import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Detailed Student Performance Screen
/// Shows test scores, subject-wise averages, performance insights, and trends
class DetailedStudentPerformanceScreen extends ConsumerStatefulWidget {
  const DetailedStudentPerformanceScreen({super.key});

  @override
  ConsumerState<DetailedStudentPerformanceScreen> createState() =>
      _DetailedStudentPerformanceScreenState();
}

class _DetailedStudentPerformanceScreenState
    extends ConsumerState<DetailedStudentPerformanceScreen> {
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Calculate subject-wise averages
  Map<String, Map<String, dynamic>> _calculateSubjectStats(
    List<(String, String, double, double)> data,
  ) {
    final stats = <String, Map<String, dynamic>>{};

    for (final record in data) {
      final subject = record.$2;
      final marks = record.$3;
      final maxMarks = record.$4;

      if (!stats.containsKey(subject)) {
        stats[subject] = {
          'totalMarks': 0.0,
          'maxMarks': 0.0,
          'count': 0,
          'tests': <Map<String, dynamic>>[],
        };
      }

      stats[subject]!['totalMarks'] =
          _parseDouble(stats[subject]!['totalMarks']) + marks;
      stats[subject]!['maxMarks'] =
          _parseDouble(stats[subject]!['maxMarks']) + maxMarks;
      stats[subject]!['count'] = (stats[subject]!['count'] as int) + 1;

      final percentage =
          maxMarks > 0 ? (marks / maxMarks) * 100 : 0.0;
      (stats[subject]!['tests'] as List<Map<String, dynamic>>).add({
        'marks': marks,
        'maxMarks': maxMarks,
        'percentage': percentage,
        'topic': record.$1,
      });
    }

    // Calculate averages
    for (final entry in stats.entries) {
      final data = entry.value;
      final totalMarks = _parseDouble(data['totalMarks']);
      final maxMarks = _parseDouble(data['maxMarks']);
      final count = data['count'] as int;

      data['average'] = count > 0 ? totalMarks / count : 0.0;
      data['averagePercentage'] =
          maxMarks > 0 ? (totalMarks / maxMarks) * 100 : 0.0;
      data['lowestScore'] = ((data['tests'] as List).isNotEmpty)
          ? (data['tests'] as List)
              .map((t) => _parseDouble(t['percentage']))
              .reduce((a, b) => a < b ? a : b)
          : 0.0;
      data['highestScore'] = ((data['tests'] as List).isNotEmpty)
          ? (data['tests'] as List)
              .map((t) => _parseDouble(t['percentage']))
              .reduce((a, b) => a > b ? a : b)
          : 0.0;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null || user.rollNumber == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Performance Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Sign in as a student to view performance.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    if (!StudentClassLevels.isValid(user.studentClass)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Performance Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Your class is not set. Ask admin to update your profile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    final classLevel = user.studentClass!;
    final rollNumber = user.rollNumber!;
    final studentName = user.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Performance Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<(String, String, double, double)>>(
        future: ref.read(erpRepositoryProvider).marksHistoryForStudent(
              classLevel: classLevel,
              roll: rollNumber,
            ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading performance data...'));
          }

          final data = snapshot.data!;

          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assessment,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No test marks found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final subjectStats = _calculateSubjectStats(data);
          final sortedSubjects = subjectStats.entries.toList()
            ..sort((a, b) {
              final aAvg = _parseDouble(a.value['averagePercentage']);
              final bAvg = _parseDouble(b.value['averagePercentage']);
              return bAvg.compareTo(aAvg);
            });

          // Overall average
          double totalMarks = 0;
          double totalMaxMarks = 0;
          for (final record in data) {
            totalMarks += record.$3;
            totalMaxMarks += record.$4;
          }
          final overallPercentage =
              totalMaxMarks > 0 ? (totalMarks / totalMaxMarks) * 100 : 0.0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Name',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    studentName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Roll',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    rollNumber,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tests',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    data.length.toString(),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Overall Performance Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.deepBlue,
                            child: Text(
                              '${overallPercentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Overall Average',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalMarks.toStringAsFixed(0)} / ${totalMaxMarks.toStringAsFixed(0)} marks',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subject-wise Performance
                  Text(
                    'Subject-wise Performance',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedSubjects.map((entry) {
                    final subject = entry.key;
                    final stats = entry.value;
                    final avgPercentage =
                        _parseDouble(stats['averagePercentage']);
                    final highestScore = _parseDouble(stats['highestScore']);
                    final lowestScore = _parseDouble(stats['lowestScore']);
                    final testCount = stats['count'] as int;

                    // Color based on performance
                    Color performanceColor;
                    if (avgPercentage >= 85) {
                      performanceColor = Colors.green;
                    } else if (avgPercentage >= 75) {
                      performanceColor = Colors.blue;
                    } else if (avgPercentage >= 60) {
                      performanceColor = Colors.orange;
                    } else {
                      performanceColor = Colors.red;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$testCount test${testCount > 1 ? 's' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: performanceColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${avgPercentage.toStringAsFixed(1)}%',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: performanceColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: avgPercentage / 100,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    performanceColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Stats row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Highest',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${highestScore.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Average',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${avgPercentage.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: performanceColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lowest',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${lowestScore.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
