import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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
    extends ConsumerState<DetailedStudentPerformanceScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Tests'),
            Tab(text: 'Test Series'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTestsView(classLevel, rollNumber, studentName),
          _buildTestSeriesView(classLevel, rollNumber, studentName),
        ],
      ),
    );
  }

  Widget _buildAllTestsView(int classLevel, String rollNumber, String studentName) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('test_marks')
            .doc(classLevel.toString())
            .collection('tests')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          try {
            // CRITICAL: Check waiting state FIRST
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Text('Loading live updates...'));
            }
            // Check error state AFTER waiting
            if (snapshot.hasError) {
              debugPrint('All tests view error: ${snapshot.error}');
              return const Center(child: Text('Syncing data...'));
            }
            // Check empty data AFTER error
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          // Process data from StreamBuilder
          final data = <(String, String, double, double)>[];
          for (final doc in snapshot.data!.docs) {
            final docData = doc.data() as Map<String, dynamic>;
            final marks = docData['marks'] as Map<String, dynamic>?;
            final notGivenRolls = (docData['notGivenRolls'] as List?)?.cast<String>() ?? [];
            
            if (marks != null && marks.containsKey(rollNumber) && !notGivenRolls.contains(rollNumber)) {
              final score = (marks[rollNumber] as num?)?.toDouble() ?? 0.0;
              final maxMarks = (docData['maxMarks'] as num?)?.toDouble() ?? 100.0;
              final testName = docData['testName']?.toString() ?? 'Test';
              final subject = docData['subject']?.toString() ?? 'General';
              data.add((testName, subject, score, maxMarks));
            }
          }

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
                    'No test marks available for you',
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
                                      color: performanceColor.withValues(alpha: 0.1),
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
        } catch (e) {
          debugPrint('Error processing all tests view data: $e');
          return const Center(child: Text('Syncing data...'));
        }
        },
      );
  }

  Widget _buildTestSeriesView(int classLevel, String rollNumber, String studentName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .doc(classLevel.toString())
          .collection('test_series')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        try {
          // CRITICAL: Check waiting state FIRST
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading live updates...'));
          }
          // Check error state AFTER waiting
          if (snapshot.hasError) {
            debugPrint('Test series view error: ${snapshot.error}');
            return const Center(child: Text('Syncing data...'));
          }
          // Check empty data AFTER error
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No test series data available.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final docData = doc.data() as Map<String, dynamic>;

            final testName = docData['testName'] as String? ?? 'Test Series';
            final seriesId = docData['seriesId'] as String? ?? 'Unknown';
            final subjects = docData['subjects'] as List? ?? [];
            final subjectData = docData['subjectData'] as Map<String, dynamic>? ?? {};
            final overallMarks = docData['overallMarks'] as Map<String, dynamic>? ?? {};
            final overallNotGivenRolls = (docData['overallNotGivenRolls'] as List?)?.cast<String>() ?? [];
            final overallRanks = docData['overallRanks'] as Map<String, dynamic>? ?? {};
            final maxMarks = _parseDouble(docData['maxMarks'] ?? 100);

            // Get student's overall marks
            final studentOverallMarks = overallMarks.containsKey(rollNumber)
                ? _parseDouble(overallMarks[rollNumber])
                : 0.0;
            final totalMaxMarks = maxMarks * subjects.length;
            final overallPercentage = totalMaxMarks > 0 ? (studentOverallMarks / totalMaxMarks) * 100 : 0.0;
            final studentRank = overallRanks.containsKey(rollNumber)
                ? (overallRanks[rollNumber] as num?)?.toInt() ?? 0
                : 0;

            // Get subject-wise marks
            final subjectMarks = <String, double>{};
            final subjectRanks = <String, int>{};
            for (final subject in subjects) {
              final subjectInfo = subjectData[subject] as Map<String, dynamic>? ?? {};
              final marksMap = subjectInfo['marks'] as Map<String, dynamic>? ?? {};
              final ranksMap = subjectInfo['ranks'] as Map<String, dynamic>? ?? {};
              if (marksMap.containsKey(rollNumber)) {
                subjectMarks[subject] = _parseDouble(marksMap[rollNumber]);
                subjectRanks[subject] = (ranksMap[rollNumber] as num?)?.toInt() ?? 0;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ExpansionTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $seriesId • ${subjects.length} subjects',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall Score
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Score',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${studentOverallMarks.toStringAsFixed(0)} / ${totalMaxMarks.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Percentage',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${overallPercentage.toStringAsFixed(1)}%',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: overallPercentage >= 75
                                          ? Colors.green
                                          : overallPercentage >= 50
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Class Rank',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    studentRank > 0 ? '#$studentRank' : 'N/A',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subject-wise breakdown
                        Text(
                          'Subject-wise Marks',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...subjects.map((subject) {
                          final marks = subjectMarks[subject] ?? 0.0;
                          final rank = subjectRanks[subject] ?? 0;
                          final subjectPercentage = maxMarks > 0 ? (marks / maxMarks) * 100 : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${subjectPercentage.toStringAsFixed(1)}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${marks.toStringAsFixed(0)}/$maxMarks',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        rank > 0 ? 'Rank: #$rank' : 'N/A',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } catch (e) {
        debugPrint('Error processing test series view data: $e');
        return const Center(child: Text('Syncing data...'));
      }
      },
    );
  }
}
