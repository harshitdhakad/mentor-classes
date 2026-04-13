import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

typedef UserModel = AppUser;

/// Enhanced leaderboard with test series support and performance categorization
class EnhancedLeaderboardScreen extends ConsumerStatefulWidget {
  const EnhancedLeaderboardScreen({super.key});

  @override
  ConsumerState<EnhancedLeaderboardScreen> createState() => _EnhancedLeaderboardScreenState();
}

class _EnhancedLeaderboardScreenState extends ConsumerState<EnhancedLeaderboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedClass = 5;
  String _selectedTest = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final user = ref.read(authProvider);
    if (user != null && user.role.name == 'student' && user.studentClass != null) {
      _selectedClass = user.studentClass!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leaderboards', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                // Class Selector - only show for teachers/staff
                if (!isStudent)
                  Padding(
                    padding: const EdgeInsets.all(8),
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
                                setState(() {
                                  _selectedClass = classNum;
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: AppTheme.deepBlue.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? AppTheme.deepBlue : Colors.black87,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Recent Test'),
                    Tab(text: 'Overall'),
                    Tab(text: 'Series'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTestWiseLeaderboard(_selectedClass, user),
            _buildOverallLeaderboard(_selectedClass, user),
            _buildSeriesWiseLeaderboard(_selectedClass, user),
          ],
        ),
      ),
    );
  }

  Widget _buildTestWiseLeaderboard(int classLevel, UserModel? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .where('testKind', isEqualTo: 'single')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading tests'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No tests found', style: GoogleFonts.poppins()));
        }

        final testNames = snapshot.data!.docs
            .map((doc) {
              final data = doc.data();
              if (data == null) return '';
              return (data as Map<String, dynamic>)['testName'] as String? ?? '';
            })
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();

        if (_selectedTest.isEmpty && testNames.isNotEmpty) {
          _selectedTest = testNames.first;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButton<String>(
                value: _selectedTest.isNotEmpty && testNames.contains(_selectedTest) ? _selectedTest : testNames.first,
                onChanged: (value) => setState(() => _selectedTest = value ?? ''),
                items: testNames.map((test) => DropdownMenuItem(value: test, child: Text(test))).toList(),
              ),
            ),
            Expanded(
              child: _TestWiseLeaderboard(
                classLevel: classLevel,
                testName: _selectedTest.isNotEmpty && testNames.contains(_selectedTest) ? _selectedTest : testNames.first,
                user: user,
              ),
            ),
          ],
        );
      },
    );
  }

  /// New: Overall Performance combining all recent tests
  Widget _buildOverallLeaderboard(int classLevel, UserModel? user) {
    return _OverallPerformanceLeaderboard(classLevel: classLevel, user: user);
  }

  Widget _buildSeriesWiseLeaderboard(int classLevel, UserModel? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .where('testKind', isEqualTo: 'series')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading series'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No test series found', style: GoogleFonts.poppins()));
        }

        final seriesNames = snapshot.data!.docs
            .map((doc) {
              final data = doc.data();
              if (data == null) return '';
              return (data as Map<String, dynamic>)['seriesId'] as String?;
            })
            .where((name) => name != null && name.isNotEmpty)
            .toSet()
            .toList();

        return _SeriesWiseLeaderboard(classLevel: classLevel, seriesNames: seriesNames.whereType<String>().toList(), user: user);
      },
    );
  }
}

class _TestWiseLeaderboard extends ConsumerWidget {
  final int classLevel;
  final String testName;
  final UserModel? user;

  const _TestWiseLeaderboard({
    required this.classLevel,
    required this.testName,
    this.user,
  });

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .where('testName', isEqualTo: testName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading data'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No marks found', style: GoogleFonts.poppins()));
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final marksByRoll = data['marksByRoll'] as Map<String, dynamic>?;
        final rankByRoll = data['rankByRoll'] as Map<String, dynamic>?;
        final notGivenRolls = (data['notGivenRolls'] as List<dynamic>?)?.cast<String>() ?? [];
        final maxMarks = _parseDouble(data['maxMarks'] ?? 100);

        if (marksByRoll == null) {
          return Center(child: Text('No marks data found', style: GoogleFonts.poppins()));
        }

        // Fetch student names
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('studentClass', isEqualTo: classLevel)
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Text('Loading students...'));
            }
            if (!studentsSnapshot.hasData || studentsSnapshot.data!.docs.isEmpty) {
              return Center(child: Text('No students found', style: GoogleFonts.poppins()));
            }

            final studentDataMap = <String, String>{};
            for (final doc in studentsSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data != null) {
                studentDataMap[data['rollNumber']?.toString() ?? data['rollNo']?.toString() ?? data['roll']?.toString() ?? ''] = data['displayName']?.toString() ?? data['name']?.toString() ?? 'Unknown';
              }
            }

            final leaderboard = <Map<String, dynamic>>[];
            marksByRoll.forEach((roll, mark) {
              final isNg = notGivenRolls.contains(roll);
              leaderboard.add({
                'roll': roll.toString(),
                'name': studentDataMap[roll.toString()] ?? 'Unknown',
                'mark': isNg ? 0.0 : _parseDouble(mark),
                'rank': isNg ? 0 : (rankByRoll?[roll] ?? 0),
                'isNg': isNg,
              });
            });

            // Add students who were not given marks
            for (final roll in notGivenRolls) {
              if (!marksByRoll.containsKey(roll)) {
                leaderboard.add({
                  'roll': roll,
                  'name': studentDataMap[roll] ?? 'Unknown',
                  'mark': 0.0,
                  'rank': 0,
                  'isNg': true,
                });
              }
            }

            leaderboard.sort((a, b) => (b['rank'] as int).compareTo(a['rank'] as int));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaderboard.length,
              itemBuilder: (context, index) {
                final entry = leaderboard[index];
                final rank = entry['rank'] as int;
                final roll = entry['roll'] as String;
                final name = entry['name'] as String;
                final mark = entry['mark'] as double;
                final isNg = entry['isNg'] as bool;
                final percentage = (mark / maxMarks * 100).toStringAsFixed(1);
                final isCurrentUser = user?.role.name == 'student' && user?.rollNumber == roll;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isCurrentUser ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isCurrentUser
                        ? BorderSide(color: AppTheme.deepBlue, width: 2)
                        : BorderSide.none,
                  ),
                  color: isNg ? Colors.grey[200] : (isCurrentUser ? Colors.blue.shade50 : Colors.white),
                  child: ListTile(
                    leading: isNg
                        ? Icon(Icons.close, color: Colors.grey)
                        : Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getRankColor(rank),
                            ),
                            child: Center(
                              child: Text(
                                isNg ? 'NG' : '$rank',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        Text(roll, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isNg ? 'N/G' : '$mark / $maxMarks',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          rank == 0 ? '—' : '$percentage%',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey;
    if (rank == 3) return Colors.brown;
    return AppTheme.deepBlue;
  }
}

class _SeriesWiseLeaderboard extends ConsumerWidget {
  final int classLevel;
  final List<String> seriesNames;
  final UserModel? user;

  const _SeriesWiseLeaderboard({
    required this.classLevel,
    required this.seriesNames,
    this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seriesNames.length,
      itemBuilder: (context, index) => _SeriesCard(
        classLevel: classLevel,
        seriesName: seriesNames[index],
        user: user,
      ),
    );
  }
}

class _SeriesCard extends ConsumerWidget {
  final int classLevel;
  final String seriesName;
  final UserModel? user;

  const _SeriesCard({
    required this.classLevel,
    required this.seriesName,
    this.user,
  });

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(seriesName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('test_marks')
                .where('classLevel', isEqualTo: classLevel)
                .where('seriesId', isEqualTo: seriesName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 50, child: Center(child: Text('Loading...')));
              }
              if (snapshot.hasError) {
                return const SizedBox(height: 50, child: Center(child: Text('Error loading data')));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No test data available', style: GoogleFonts.poppins()),
                    ],
                  ),
                );
              }

              // Define target subjects for total score calculation
              const targetSubjects = {'SST', 'Science', 'Maths', 'English'};
              
              // Calculate overall scores by combining tests from target subjects
              final studentScores = <String, double>{};
              final studentStats = <String, Map<String, dynamic>>{};
              final studentSubjectScores = <String, Map<String, double>>{};

              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final subject = (data['subject'] as String? ?? '').toLowerCase();
                final marks = data['marksByRoll'] as Map<String, dynamic>? ?? {};

                // Only include tests from target subjects
                final isTargetSubject = targetSubjects.any((s) => subject.contains(s.toLowerCase()));
                if (!isTargetSubject) continue;

                marks.forEach((roll, mark) {
                  studentScores.putIfAbsent(roll, () => 0);
                  studentScores[roll] = studentScores[roll]! + _parseDouble(mark);
                });
              }

              final ranked = studentScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: ranked.length,
                itemBuilder: (context, idx) {
                  final entry = ranked[idx];
                  final roll = entry.key;
                  final isCurrentUser = user?.role.name == 'student' && user?.rollNumber == roll;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: isCurrentUser ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isCurrentUser
                          ? BorderSide(color: AppTheme.deepBlue, width: 2)
                          : BorderSide.none,
                    ),
                    color: isCurrentUser ? Colors.blue.shade50 : Colors.white,
                    child: ListTile(
                      leading: _buildRankBadge(idx + 1),
                      title: Row(
                        children: [
                          Text(roll, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          if (isCurrentUser)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'YOU',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(entry.value.toStringAsFixed(2), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          // Hide percentage for series - show marks only
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color;
    String emoji;

    if (rank == 1) {
      color = Colors.amber;
      emoji = '🥇';
    } else if (rank == 2) {
      color = Colors.grey;
      emoji = '🥈';
    } else if (rank == 3) {
      color = Colors.brown;
      emoji = '🥉';
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.deepBlue),
        child: Center(child: Text(rank.toString(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}

/// NEW TAB: Overall Performance combining all tests across subjects (SST, Science, Maths, English)
class _OverallPerformanceLeaderboard extends ConsumerWidget {
  final int classLevel;
  final UserModel? user;

  const _OverallPerformanceLeaderboard({
    required this.classLevel,
    this.user,
  });

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading data'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No test data available', style: GoogleFonts.poppins()),
              ],
            ),
          );
        }

        // Define target subjects for total score calculation
        const targetSubjects = {'SST', 'Science', 'Maths', 'English'};
        
        // Calculate overall scores by combining tests from target subjects
        final studentStats = <String, Map<String, dynamic>>{};
        final studentSubjectScores = <String, Map<String, double>>{};

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = (data['subject'] as String? ?? '').toLowerCase();
          final marks = data['marksByRoll'] as Map<String, dynamic>? ?? {};

          // Only include tests from target subjects
          final isTargetSubject = targetSubjects.any((s) => subject.contains(s.toLowerCase()));
          if (!isTargetSubject) continue;

          marks.forEach((roll, mark) {
            if (!studentStats.containsKey(roll)) {
              studentStats[roll] = {
                'totalMarks': 0.0,
                'testCount': 0,
                'maxMarks': 0.0,
                'subjects': <String>{},
              };
              studentSubjectScores[roll] = {};
            }
            
            // Track per-subject scores (take the best score per subject)
            if (!studentSubjectScores[roll]!.containsKey(subject)) {
              studentSubjectScores[roll]![subject] = 0.0;
            }
            final currentSubjectScore = studentSubjectScores[roll]![subject]!;
            final newScore = _parseDouble(mark);
            if (newScore > currentSubjectScore) {
              studentSubjectScores[roll]![subject] = newScore;
            }
            
            studentStats[roll]!['totalMarks'] = studentSubjectScores[roll]!.values.reduce((a, b) => a + b);
            studentStats[roll]!['subjects'] = studentSubjectScores[roll]!.keys.toSet();
            studentStats[roll]!['testCount'] = studentStats[roll]!['subjects'].length;
            studentStats[roll]!['maxMarks'] = studentStats[roll]!['testCount'] * 100.0; // Assuming 100 marks per subject
          });
        }

        // Convert to list and sort by average score
        final rankedStudents = studentStats.entries.map((entry) {
          final totalMarks = _parseDouble(entry.value['totalMarks']);
          final maxMarks = _parseDouble(entry.value['maxMarks']);
          final percentage = maxMarks > 0 ? (totalMarks / maxMarks) * 100 : 0.0;
          return {
            'roll': entry.key,
            'totalMarks': totalMarks,
            'maxMarks': maxMarks,
            'percentage': percentage,
            'testCount': entry.value['testCount'],
          };
        }).toList()
          ..sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Stats
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
                    Text(
                      'Overall Statistics',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tests Analyzed', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              Text(
                                snapshot.data!.docs.length.toString(),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Students Ranked', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              Text(
                                rankedStudents.length.toString(),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Top Score', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              Text(
                                rankedStudents.isNotEmpty
                                    ? '${(rankedStudents.first['percentage'] as double).toStringAsFixed(1)}%'
                                    : '—',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Leaderboard
            Text(
              'Ranking',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
            ),
            const SizedBox(height: 12),
            ...rankedStudents.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final student = entry.value;
              final roll = student['roll'] as String;
              final percentage = student['percentage'] as double;
              final totalMarks = student['totalMarks'] as double;
              final maxMarks = student['maxMarks'] as double;
              final isCurrentUser = user?.role.name == 'student' && user?.rollNumber == roll;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isCurrentUser ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isCurrentUser
                      ? BorderSide(color: AppTheme.deepBlue, width: 2)
                      : BorderSide(color: rank <= 3 ? Colors.grey.shade300 : Colors.grey.shade200),
                ),
                color: rank == 1 ? Colors.amber.shade50 : rank == 2 ? Colors.grey.shade100 : (isCurrentUser ? Colors.blue.shade50 : Colors.white),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey
                              : rank == 3
                                  ? Colors.brown
                                  : AppTheme.deepBlue,
                    ),
                    child: Center(
                      child: Text(
                        rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank',
                        style: GoogleFonts.poppins(
                          color: rank <= 3 ? Colors.white : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  title: Text(roll, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Avg: ${(totalMarks / (student['testCount'] as int)).toStringAsFixed(1)} per test',
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        '${totalMarks.toStringAsFixed(0)}/${maxMarks.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}