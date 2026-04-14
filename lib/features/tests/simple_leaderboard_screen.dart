import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

/// Simple and clean leaderboard - rebuilt from root
class SimpleLeaderboardScreen extends ConsumerStatefulWidget {
  const SimpleLeaderboardScreen({super.key});

  @override
  ConsumerState<SimpleLeaderboardScreen> createState() => _SimpleLeaderboardScreenState();
}

class _SimpleLeaderboardScreenState extends ConsumerState<SimpleLeaderboardScreen> {
  int _selectedClass = 5;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';

    if (isStudent && user?.studentClass != null) {
      _selectedClass = user!.studentClass!;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leaderboard', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Class Selector
            if (!isStudent)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(6, (index) {
                      final classNum = index + 5;
                      final isSelected = _selectedClass == classNum;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('Class $classNum'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedClass = classNum);
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: AppTheme.deepBlue.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppTheme.deepBlue : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          // Tab Bar for Recent, Overall, Test Series
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TabBar(
              tabs: const [
                Tab(text: 'Recent'),
                Tab(text: 'Overall'),
                Tab(text: 'Test Series'),
              ],
              labelColor: AppTheme.deepBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.deepBlue,
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildRecentLeaderboard(),
                _buildOverallLeaderboard(),
                _buildTestSeriesLeaderboard(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRecentLeaderboard() {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .doc(_selectedClass.toString())
          .collection('tests')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No recent tests for Class $_selectedClass',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final marksByRoll = data['marks'] as Map<String, dynamic>?;
        final rankByRoll = data['rankByRoll'] as Map<String, dynamic>?;
        final notGivenRolls = (data['notGivenRolls'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};
        final maxMarks = (data['maxMarks'] as num?)?.toDouble() ?? 100.0;
        final testName = data['testName']?.toString() ?? 'Test';
        final subject = data['subject']?.toString() ?? '';

        if (marksByRoll == null) {
          return Center(
            child: Text(
              'No marks data found',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('studentClass', isEqualTo: _selectedClass)
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!studentsSnapshot.hasData || studentsSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No students found for Class $_selectedClass',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              );
            }

            final studentDataMap = <String, String>{};
            for (final doc in studentsSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final roll = (data['rollNumber'] ?? data['rollNo'] ?? data['roll'] ?? '').toString();
              final name = (data['displayName'] ?? data['name'] ?? 'Unknown').toString();
              studentDataMap[roll] = name;
            }

            final leaderboard = <Map<String, dynamic>>[];
            marksByRoll.forEach((roll, mark) {
              final isNg = notGivenRolls.contains(roll);
              leaderboard.add({
                'roll': roll.toString(),
                'name': studentDataMap[roll] ?? 'Unknown',
                'mark': isNg ? 0.0 : (mark as num?)?.toDouble() ?? 0.0,
                'rank': isNg ? 0 : (rankByRoll?[roll] ?? 0),
                'isNg': isNg,
                'percentage': isNg ? 0.0 : (((mark as num?)?.toDouble() ?? 0.0) / maxMarks * 100),
              });
            });

            leaderboard.sort((a, b) => (b['rank'] as int).compareTo(a['rank'] as int));

            return _buildLeaderboardList(leaderboard, testName, subject, maxMarks, isStudent, user?.rollNumber);
          },
        );
      },
    );
  }

  Widget _buildOverallLeaderboard() {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .doc(_selectedClass.toString())
          .collection('tests')
          .where('testKind', isEqualTo: 'single')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No tests available for Class $_selectedClass',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('studentClass', isEqualTo: _selectedClass)
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!studentsSnapshot.hasData || studentsSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No students found for Class $_selectedClass',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              );
            }

            final studentDataMap = <String, String>{};
            for (final doc in studentsSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final roll = (data['rollNumber'] ?? data['rollNo'] ?? data['roll'] ?? '').toString();
              final name = (data['displayName'] ?? data['name'] ?? 'Unknown').toString();
              studentDataMap[roll] = name;
            }

            final overallStats = <String, double>{};
            final testCounts = <String, int>{};

            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final marksByRoll = data['marks'] as Map<String, dynamic>?;
              final notGivenRolls = (data['notGivenRolls'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};
              final maxMarks = (data['maxMarks'] as num?)?.toDouble() ?? 100.0;

              if (marksByRoll != null) {
                marksByRoll.forEach((roll, mark) {
                  final isNg = notGivenRolls.contains(roll);
                  if (!isNg) {
                    final percentage = ((mark as num?)?.toDouble() ?? 0.0) / maxMarks * 100;
                    overallStats[roll] = (overallStats[roll] ?? 0) + percentage;
                    testCounts[roll] = (testCounts[roll] ?? 0) + 1;
                  }
                });
              }
            }

            final leaderboard = <Map<String, dynamic>>[];
            overallStats.forEach((roll, totalPercentage) {
              final avgPercentage = totalPercentage / (testCounts[roll] ?? 1);
              leaderboard.add({
                'roll': roll.toString(),
                'name': studentDataMap[roll] ?? 'Unknown',
                'avgPercentage': avgPercentage,
                'testCount': testCounts[roll] ?? 0,
              });
            });

            leaderboard.sort((a, b) => (b['avgPercentage'] as double).compareTo(a['avgPercentage'] as double));

            return _buildOverallLeaderboardList(leaderboard, isStudent, user?.rollNumber);
          },
        );
      },
    );
  }

  Widget _buildTestSeriesLeaderboard() {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .doc(_selectedClass.toString())
          .collection('tests')
          .where('testKind', isEqualTo: 'series')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No test series available for Class $_selectedClass',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        final seriesDocs = snapshot.data!.docs;
        if (seriesDocs.isEmpty) {
          return Center(
            child: Text(
              'No test series available',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        final firstSeries = seriesDocs.first;
        final seriesId = firstSeries.id;
        final seriesData = firstSeries.data() as Map<String, dynamic>?;
        final seriesName = seriesData != null ? (seriesData['name']?.toString() ?? 'Series') : 'Series';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('test_marks')
              .doc(_selectedClass.toString())
              .collection('tests')
              .where('seriesId', isEqualTo: seriesId)
              .snapshots(),
          builder: (context, seriesTestsSnapshot) {
            if (seriesTestsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!seriesTestsSnapshot.hasData || seriesTestsSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No tests in this series',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('studentClass', isEqualTo: _selectedClass)
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, studentsSnapshot) {
                if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!studentsSnapshot.hasData || studentsSnapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found for Class $_selectedClass',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  );
                }

                final studentDataMap = <String, String>{};
                for (final doc in studentsSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final roll = (data['rollNumber'] ?? data['rollNo'] ?? data['roll'] ?? '').toString();
                  final name = (data['displayName'] ?? data['name'] ?? 'Unknown').toString();
                  studentDataMap[roll] = name;
                }

                final seriesStats = <String, double>{};
                final testCounts = <String, int>{};

                for (final doc in seriesTestsSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final marksByRoll = data['marks'] as Map<String, dynamic>?;
                  final notGivenRolls = (data['notGivenRolls'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};
                  final maxMarks = (data['maxMarks'] as num?)?.toDouble() ?? 100.0;

                  if (marksByRoll != null) {
                    marksByRoll.forEach((roll, mark) {
                      final isNg = notGivenRolls.contains(roll);
                      if (!isNg) {
                        final percentage = ((mark as num?)?.toDouble() ?? 0.0) / maxMarks * 100;
                        seriesStats[roll] = (seriesStats[roll] ?? 0) + percentage;
                        testCounts[roll] = (testCounts[roll] ?? 0) + 1;
                      }
                    });
                  }
                }

                final leaderboard = <Map<String, dynamic>>[];
                seriesStats.forEach((roll, totalPercentage) {
                  final avgPercentage = totalPercentage / (testCounts[roll] ?? 1);
                  leaderboard.add({
                    'roll': roll.toString(),
                    'name': studentDataMap[roll] ?? 'Unknown',
                    'avgPercentage': avgPercentage,
                    'testCount': testCounts[roll] ?? 0,
                  });
                });

                leaderboard.sort((a, b) => (b['avgPercentage'] as double).compareTo(a['avgPercentage'] as double));

                return _buildOverallLeaderboardList(leaderboard, isStudent, user?.rollNumber, seriesName);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> leaderboard, String testName, String subject, double maxMarks, bool isStudent, String? currentUserRoll) {
    // Find current student's rank
    int? studentRank;
    double? studentMark;
    double? studentPercentage;
    bool? studentIsNg;

    if (isStudent && currentUserRoll != null) {
      final studentEntry = leaderboard.firstWhere(
        (e) => e['roll'] == currentUserRoll,
        orElse: () => {},
      );
      if (studentEntry.isNotEmpty) {
        studentRank = studentEntry['rank'] as int;
        studentMark = studentEntry['mark'] as double;
        studentPercentage = studentEntry['percentage'] as double;
        studentIsNg = studentEntry['isNg'] as bool;
      }
    }

    return Column(
      children: [
        // Student's own rank display (for students)
        if (isStudent && studentRank != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepBlue.withValues(alpha: 0.1), AppTheme.deepBlue.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.deepBlue, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: studentRank == 1
                        ? Colors.amber
                        : studentRank == 2
                            ? Colors.grey.shade400
                            : studentRank == 3
                                ? Colors.brown.shade400
                                : AppTheme.deepBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#$studentRank',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Rank',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        studentIsNg == true ? 'NG' : '${studentMark?.toStringAsFixed(1)}/$maxMarks',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: studentIsNg == true
                              ? Colors.orange
                              : studentMark! >= maxMarks * 0.6
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                if (studentPercentage != null && !studentIsNg!)
                  Text(
                    '${studentPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.deepBlue,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.deepBlue,
          child: Column(
            children: [
              Text(
                testName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subject,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max Marks: $maxMarks',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final entry = leaderboard[index];
              final rank = entry['rank'] as int;
              final roll = entry['roll'] as String;
              final name = entry['name'] as String;
              final mark = entry['mark'] as double;
              final percentage = entry['percentage'] as double;
              final isNg = entry['isNg'] as bool;
              final isCurrentUser = isStudent && currentUserRoll == roll;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isCurrentUser ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrentUser
                      ? BorderSide(color: AppTheme.deepBlue, width: 2)
                      : BorderSide.none,
                ),
                color: isCurrentUser ? AppTheme.deepBlue.withValues(alpha: 0.05) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? Colors.amber
                              : rank == 2
                                  ? Colors.grey.shade400
                                  : rank == 3
                                      ? Colors.brown.shade400
                                      : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Roll: $roll',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
                            isNg ? 'NG' : '${mark.toStringAsFixed(1)}/$maxMarks',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isNg
                                  ? Colors.orange
                                  : mark >= maxMarks * 0.6
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          if (!isNg)
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOverallLeaderboardList(List<Map<String, dynamic>> leaderboard, bool isStudent, String? currentUserRoll, [String? seriesName]) {
    // Find current student's rank
    int? studentRank;
    double? studentAvgPercentage;
    int? studentTestCount;

    if (isStudent && currentUserRoll != null) {
      final studentEntryIndex = leaderboard.indexWhere((e) => e['roll'] == currentUserRoll);
      if (studentEntryIndex != -1) {
        studentRank = studentEntryIndex + 1;
        studentAvgPercentage = leaderboard[studentEntryIndex]['avgPercentage'] as double;
        studentTestCount = leaderboard[studentEntryIndex]['testCount'] as int;
      }
    }

    return Column(
      children: [
        // Student's own rank display (for students)
        if (isStudent && studentRank != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepBlue.withValues(alpha: 0.1), AppTheme.deepBlue.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.deepBlue, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: studentRank == 1
                        ? Colors.amber
                        : studentRank == 2
                            ? Colors.grey.shade400
                            : studentRank == 3
                                ? Colors.brown.shade400
                                : AppTheme.deepBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#$studentRank',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Rank',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${studentAvgPercentage?.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: studentAvgPercentage! >= 60
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$studentTestCount tests',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ],
            ),
          ),
        if (seriesName != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.deepBlue,
            child: Text(
              seriesName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final entry = leaderboard[index];
              final rank = index + 1;
              final roll = entry['roll'] as String;
              final name = entry['name'] as String;
              final avgPercentage = entry['avgPercentage'] as double;
              final testCount = entry['testCount'] as int;
              final isCurrentUser = isStudent && currentUserRoll == roll;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isCurrentUser ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrentUser
                      ? BorderSide(color: AppTheme.deepBlue, width: 2)
                      : BorderSide.none,
                ),
                color: isCurrentUser ? AppTheme.deepBlue.withValues(alpha: 0.05) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? Colors.amber
                              : rank == 2
                                  ? Colors.grey.shade400
                                  : rank == 3
                                      ? Colors.brown.shade400
                                      : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Roll: $roll',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
                            '${avgPercentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: avgPercentage >= 60
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          Text(
                            '$testCount tests',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
