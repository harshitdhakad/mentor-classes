import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// Staff Class Performance Widget - Shows class analytics and top/bottom performers
class StaffClassPerformanceWidget extends ConsumerWidget {
  final int classLevel;

  const StaffClassPerformanceWidget({
    Key? key,
    required this.classLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('test_marks')
            .where('classLevel', isEqualTo: classLevel)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          try {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Text('Loading...'));
            }
            if (snapshot.hasError) {
              debugPrint('Class performance error: ${snapshot.error}');
              return const Center(child: Text('Error loading data'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No test data available for Class $classLevel',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }

            // Process data from StreamBuilder
            final data = _processClassPerformanceData(snapshot.data!.docs, classLevel);
            return SingleChildScrollView(
              child: Column(
                children: [
                  _ClassStatsCard(data: data),
                  const SizedBox(height: 12),
                  _TopPerformersCard(
                    title: '🥇 Top 3 Performers',
                    students: data.topThree,
                  ),
                  const SizedBox(height: 12),
                  _TopPerformersCard(
                    title: '⭐ Top 5 Performers',
                    students: data.topFive,
                  ),
                  const SizedBox(height: 12),
                  _NeedsImprovementCard(students: data.needsImprovement),
                  const SizedBox(height: 12),
                ],
              ),
            );
          } catch (e) {
            debugPrint('Class performance widget error: $e');
            return const Center(child: Text('Error loading data'));
          }
        },
      );
    } catch (e) {
      debugPrint('Class performance build error: $e');
      return const Center(child: Text('Error loading widget'));
    }
  }

  static _ClassPerformanceData _processClassPerformanceData(
    List<QueryDocumentSnapshot> docs,
    int classLevel,
  ) {
    try {
      // Calculate average score per student
      final studentAverages = <String, _StudentAverage>{};
      int totalTests = 0;

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final marks = data['marks'] as Map?;
        final maxMarks = (data['maxMarks'] as num?)?.toDouble() ?? 100.0;
        final notGivenRolls =
            (data['notGivenRolls'] as List?)?.cast<String>() ?? [];

        if (marks != null) {
          totalTests++;

          for (final entry in marks.entries) {
            final roll = entry.key as String;
            if (notGivenRolls.contains(roll)) continue;

            final score = (entry.value as num?)?.toDouble() ?? 0.0;
            final percentage = (score / maxMarks * 100).clamp(0.0, 100.0);

            if (!studentAverages.containsKey(roll)) {
              studentAverages[roll] = _StudentAverage(
                roll: roll,
                totalScore: 0,
                testCount: 0,
              );
            }

            studentAverages[roll]!.totalScore += percentage;
            studentAverages[roll]!.testCount++;
          }
        }
      }

      // Calculate averages (without student names for now)
      final scores = studentAverages.entries
          .map((e) => _StudentPerformance(
                roll: e.key,
                name: 'Student ${e.key}',
                average: e.value.testCount > 0
                    ? e.value.totalScore / e.value.testCount
                    : 0.0,
              ))
          .toList();

      // Sort by average
      scores.sort((a, b) => b.average.compareTo(a.average));

      // Get top 3, top 5, and needs improvement
      final topThree = scores.take(3).toList();
      final topFive = scores.take(5).toList();
      final needsImprovement =
          scores.where((s) => s.average < 50 && s.average > 0).toList();

      final avg = scores.isEmpty
          ? 0.0
          : scores.map((s) => s.average).reduce((a, b) => a + b) / scores.length;

      return _ClassPerformanceData(
        classLevel: classLevel,
        totalTests: totalTests,
        totalStudents: scores.length,
        classAverage: avg,
        topThree: topThree,
        topFive: topFive,
        needsImprovement: needsImprovement,
      );
    } catch (e) {
      debugPrint('Error processing class performance: $e');
      return _ClassPerformanceData(
        classLevel: classLevel,
        totalTests: 0,
        totalStudents: 0,
        classAverage: 0,
        topThree: [],
        topFive: [],
        needsImprovement: [],
      );
    }
  }
}

class _ClassStatsCard extends StatelessWidget {
  final _ClassPerformanceData data;

  const _ClassStatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.deepBlue, AppTheme.deepBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Class ${data.classLevel} Performance Overview',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Tests',
                value: '${data.totalTests}',
                icon: Icons.assignment,
              ),
              _StatItem(
                label: 'Students',
                value: '${data.totalStudents}',
                icon: Icons.people,
              ),
              _StatItem(
                label: 'Class Avg',
                value: '${data.classAverage.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopPerformersCard extends StatelessWidget {
  final String title;
  final List<_StudentPerformance> students;

  const _TopPerformersCard({
    required this.title,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$title - No data',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepBlue,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final medals = ['🥇', '🥈', '🥉'];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: index < students.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      index < medals.length ? medals[index] : '${index + 1}',
                      style: GoogleFonts.poppins(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Roll ${student.roll}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.deepBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${student.average.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NeedsImprovementCard extends StatelessWidget {
  final List<_StudentPerformance> students;

  const _NeedsImprovementCard({required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Text(
              'All students performing well!',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '⚠️ Students Needing Improvement (<50%)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningOrange,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final statusColor = student.average < 30
                  ? Colors.red
                  : student.average < 40
                      ? Colors.orange
                      : Colors.amber;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: index < students.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Roll ${student.roll}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${student.average.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ClassPerformanceData {
  final int classLevel;
  final int totalTests;
  final int totalStudents;
  final double classAverage;
  final List<_StudentPerformance> topThree;
  final List<_StudentPerformance> topFive;
  final List<_StudentPerformance> needsImprovement;

  _ClassPerformanceData({
    required this.classLevel,
    required this.totalTests,
    required this.totalStudents,
    required this.classAverage,
    required this.topThree,
    required this.topFive,
    required this.needsImprovement,
  });
}

class _StudentPerformance {
  final String roll;
  final String name;
  final double average;

  _StudentPerformance({
    required this.roll,
    required this.name,
    required this.average,
  });
}

class _StudentAverage {
  final String roll;
  double totalScore;
  int testCount;

  _StudentAverage({
    required this.roll,
    required this.totalScore,
    required this.testCount,
  });
}
