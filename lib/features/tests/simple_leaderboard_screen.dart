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

            leaderboard.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));

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
          .collection('test_series')
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
              'No test series available for Class $_selectedClass',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        final seriesDoc = snapshot.data!.docs.first;
        final seriesData = seriesDoc.data() as Map<String, dynamic>;
        final testName = seriesData['testName']?.toString() ?? 'Test Series';
        final seriesId = seriesData['seriesId']?.toString() ?? 'Unknown';
        final subjects = seriesData['subjects'] as List? ?? [];
        final overallMarks = seriesData['overallMarks'] as Map<String, dynamic>? ?? {};
        final overallRanks = seriesData['overallRanks'] as Map<String, dynamic>? ?? {};
        final overallNotGivenRolls = (seriesData['overallNotGivenRolls'] as List?)?.map((e) => e.toString()).toSet() ?? {};
        final subjectData = seriesData['subjectData'] as Map<String, dynamic>? ?? {};
        final maxMarks = (seriesData['maxMarks'] as num?)?.toDouble() ?? 100.0;
        final totalMaxMarks = maxMarks * subjects.length;

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

            overallMarks.forEach((roll, mark) {
              final isNg = overallNotGivenRolls.contains(roll);
              final percentage = isNg ? 0.0 : ((mark as num?)?.toDouble() ?? 0.0) / totalMaxMarks * 100;
              final rank = (overallRanks[roll] as num?)?.toInt() ?? 0;

              // Get subject-wise marks
              final subjectMarks = <String, double>{};
              for (final subject in subjects) {
                final subjectInfo = subjectData[subject] as Map<String, dynamic>? ?? {};
                final marksMap = subjectInfo['marks'] as Map<String, dynamic>? ?? {};
                final notGivenRolls = (subjectInfo['notGivenRolls'] as List?)?.map((e) => e.toString()).toSet() ?? {};
                if (marksMap.containsKey(roll) && !notGivenRolls.contains(roll)) {
                  subjectMarks[subject] = (marksMap[roll] as num?)?.toDouble() ?? 0.0;
                } else {
                  subjectMarks[subject] = 0.0;
                }
              }

              leaderboard.add({
                'roll': roll,
                'name': studentDataMap[roll] ?? 'Unknown',
                'mark': (mark as num?)?.toDouble() ?? 0.0,
                'percentage': percentage,
                'rank': rank,
                'isNg': isNg,
                'subjectMarks': subjectMarks,
              });
            });

            leaderboard.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));

            return _buildTestSeriesLeaderboardList(
              leaderboard,
              testName,
              subjects,
              maxMarks,
              totalMaxMarks,
              isStudent,
              user?.rollNumber,
            );
          },
        );
      },
    );
  }

  Widget _buildTestSeriesLeaderboardList(
    List<Map<String, dynamic>> leaderboard,
    String testName,
    List<dynamic> subjects,
    double maxMarks,
    double totalMaxMarks,
    bool isStudent,
    String? currentUserRoll,
  ) {
    // Find current user's data for highlighting
    Map<String, dynamic>? currentUserData;
    if (isStudent && currentUserRoll != null) {
      currentUserData = leaderboard.firstWhere(
        (entry) => entry['roll'] == currentUserRoll,
        orElse: () => {},
      );
    }

    final studentRank = currentUserData?['rank'] as int?;
    final studentMark = currentUserData?['mark'] as double?;
    final studentPercentage = currentUserData?['percentage'] as double?;
    final studentIsNg = currentUserData?['isNg'] as bool?;
    final studentSubjectMarks = currentUserData?['subjectMarks'] as Map<String, double>?;

    return Column(
      children: [
        // Test Info Header with Gradient
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.deepBlue, AppTheme.deepBlue.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Text(
                testName,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${subjects.join(', ')} (${subjects.length} subjects)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Max Marks: $maxMarks per subject',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Current User's Rank Card
        if (currentUserData != null && currentUserData!.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.deepBlue.withValues(alpha: 0.15),
                  AppTheme.deepBlue.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.deepBlue.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Performance',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    if (studentRank != null && studentRank > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.deepBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$studentRank',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Score',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          studentIsNg == true ? 'N/A' : '${studentMark?.toStringAsFixed(0) ?? 0} / ${totalMaxMarks.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Percentage',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          studentIsNg == true ? 'N/A' : '${studentPercentage?.toStringAsFixed(1) ?? 0}%',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: studentIsNg == true ? Colors.grey : (studentPercentage ?? 0) >= 75 ? Colors.green : (studentPercentage ?? 0) >= 50 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (studentSubjectMarks != null && studentSubjectMarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Subject-wise Marks',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subjects.map((subject) {
                      final subjectMark = studentSubjectMarks[subject.toString()] ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Text(
                              subject.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${subjectMark.toStringAsFixed(0)}/$maxMarks',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        // Leaderboard List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final entry = leaderboard[index];
              final rank = entry['rank'] as int;
              final roll = entry['roll'] as String;
              final name = entry['name'] as String;
              final mark = entry['mark'] as double;
              final percentage = entry['percentage'] as double;
              final isNg = entry['isNg'] as bool;
              final subjectMarks = entry['subjectMarks'] as Map<String, double>?;

              final isCurrentUser = isStudent && roll == currentUserRoll;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isCurrentUser ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCurrentUser ? AppTheme.deepBlue : Colors.grey.shade200,
                    width: isCurrentUser ? 2 : 1,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _getRankGradient(rank),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isCurrentUser ? AppTheme.deepBlue : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Roll: $roll',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isNg ? 'N/A' : '${mark.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isNg ? Colors.grey : AppTheme.deepBlue,
                        ),
                      ),
                      Text(
                        isNg ? 'N/A' : '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isNg ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (subjectMarks != null && subjectMarks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subject-wise Marks',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((subject) {
                                final subjectMark = subjectMarks[subject.toString()] ?? 0.0;
                                final subjectPercentage = maxMarks > 0 ? (subjectMark / maxMarks) * 100 : 0.0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        subject.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '${subjectMark.toStringAsFixed(0)}/$maxMarks',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.deepBlue,
                                        ),
                                      ),
                                      Text(
                                        '${subjectPercentage.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  LinearGradient _getRankGradient(int rank) {
    if (rank == 1) {
      return LinearGradient(colors: [Colors.amber, Colors.amber.shade700]);
    } else if (rank == 2) {
      return LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade500]);
    } else if (rank == 3) {
      return LinearGradient(colors: [Colors.brown.shade300, Colors.brown.shade600]);
    }
    return LinearGradient(colors: [AppTheme.deepBlue.withValues(alpha: 0.8), AppTheme.deepBlue]);
  }

  Widget _buildLeaderboardList(
    List<Map<String, dynamic>> leaderboard,
    String testName,
    String subject,
    double maxMarks,
    bool isStudent,
    String? currentUserRoll,
  ) {
    // Find current user's data for highlighting
    Map<String, dynamic>? currentUserData;
    if (isStudent && currentUserRoll != null) {
      currentUserData = leaderboard.firstWhere(
        (entry) => entry['roll'] == currentUserRoll,
        orElse: () => {},
      );
    }

    final studentRank = currentUserData?['rank'] as int?;
    final studentMark = currentUserData?['mark'] as double?;
    final studentPercentage = currentUserData?['percentage'] as double?;
    final studentIsNg = currentUserData?['isNg'] as bool?;

    return Column(
      children: [
        // Test Info Header with Gradient
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.deepBlue, AppTheme.deepBlue.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Text(
                testName,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subject,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Max Marks: $maxMarks',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Current User's Rank Card
        if (currentUserData != null && currentUserData!.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.deepBlue.withValues(alpha: 0.15),
                  AppTheme.deepBlue.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.deepBlue, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepBlue.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildRankBadge(studentRank ?? 0, 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Performance',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        studentIsNg == true ? 'Not Given' : '${studentMark?.toStringAsFixed(1)}/$maxMarks',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: studentPercentage! >= 60 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${studentPercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isCurrentUser 
                      ? AppTheme.deepBlue.withValues(alpha: 0.08) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isCurrentUser
                      ? Border.all(color: AppTheme.deepBlue, width: 2)
                      : Border.all(color: Colors.grey.shade200),
                  boxShadow: isCurrentUser
                      ? [
                          BoxShadow(
                            color: AppTheme.deepBlue.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildRankBadge(rank, 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isCurrentUser ? AppTheme.deepBlue : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll No. $roll',
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
                            isNg ? 'NG' : '${mark.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isNg
                                  ? Colors.orange
                                  : mark >= maxMarks * 0.6
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          if (!isNg) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: percentage >= 60 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: percentage >= 60 ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildRankBadge(int rank, double size) {
    IconData icon;
    Color color;
    
    if (rank == 1) {
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (rank == 2) {
      icon = Icons.military_tech;
      color = Colors.grey.shade400;
    } else if (rank == 3) {
      icon = Icons.workspace_premium;
      color = Colors.brown.shade400;
    } else if (rank == 0) {
      icon = Icons.help_outline;
      color = Colors.grey.shade300;
    } else {
      icon = Icons.numbers;
      color = AppTheme.deepBlue;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: rank <= 3
            ? Icon(icon, color: Colors.white, size: size * 0.5)
            : Text(
                '#$rank',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.35,
                  color: Colors.white,
                ),
              ),
      ),
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
        // Header with gradient
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.deepBlue, AppTheme.deepBlue.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Text(
            seriesName ?? 'Overall Performance',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Student's own rank display (for students)
        if (isStudent && studentRank != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.deepBlue.withValues(alpha: 0.15),
                  AppTheme.deepBlue.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.deepBlue, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepBlue.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildRankBadge(studentRank, 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Overall Rank',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${studentAvgPercentage?.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: studentAvgPercentage! >= 60
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$studentTestCount tests',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final entry = leaderboard[index];
              final roll = entry['roll'] as String;
              final name = entry['name'] as String;
              final avgPercentage = entry['avgPercentage'] as double;
              final testCount = entry['testCount'] as int;
              final isCurrentUser = isStudent && currentUserRoll == roll;
              final rank = index + 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isCurrentUser 
                      ? AppTheme.deepBlue.withValues(alpha: 0.08) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isCurrentUser
                      ? Border.all(color: AppTheme.deepBlue, width: 2)
                      : Border.all(color: Colors.grey.shade200),
                  boxShadow: isCurrentUser
                      ? [
                          BoxShadow(
                            color: AppTheme.deepBlue.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildRankBadge(rank, 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isCurrentUser ? AppTheme.deepBlue : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll No. $roll',
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
                              fontSize: 18,
                              color: avgPercentage >= 60 ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.deepBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$testCount tests',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepBlue,
                              ),
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
