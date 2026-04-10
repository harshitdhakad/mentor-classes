import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Enhanced leaderboard with test series support and performance categorization
class EnhancedLeaderboardScreen extends ConsumerStatefulWidget {
  const EnhancedLeaderboardScreen({super.key});

  @override
  ConsumerState<EnhancedLeaderboardScreen> createState() => _EnhancedLeaderboardScreenState();
}

class _EnhancedLeaderboardScreenState extends ConsumerState<EnhancedLeaderboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTest = '';
  List<String> _testNames = [];
  List<String> _seriesNames = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTests();
  }

  Future<void> _loadTests() async {
    final db = FirebaseFirestore.instance;
    final user = ref.read(authProvider);
    if (user == null || !StudentClassLevels.isValid(user.studentClass)) return;

    final classLevel = user.studentClass!;

    // Get all test names
    final testsSnap = await db
        .collection('test_marks')
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final tests = <String>{};
    final series = <String>{};

    for (final doc in testsSnap.docs) {
      tests.add(doc.data()['testName'] ?? '');
      if (doc.data()['testKind'] == 'series') {
        series.add(doc.data()['seriesId'] ?? '');
      }
    }

    setState(() {
      _testNames = tests.where((e) => e.isNotEmpty).toList();
      _seriesNames = series.where((e) => e.isNotEmpty).toList();
      if (_testNames.isNotEmpty) _selectedTest = _testNames.first;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || !StudentClassLevels.isValid(user.studentClass)) {
      return const Center(child: Text('Please select a class'));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leaderboards', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Recent Test'),
              Tab(text: 'Overall'),
              Tab(text: 'Series'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTestWiseLeaderboard(user.studentClass!),
            _buildOverallLeaderboard(user.studentClass!),
            _buildSeriesWiseLeaderboard(user.studentClass!),
          ],
        ),
      ),
    );
  }

  Widget _buildTestWiseLeaderboard(int classLevel) {
    if (_testNames.isEmpty) {
      return Center(child: Text('No tests found', style: GoogleFonts.poppins()));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButton<String>(
            value: _selectedTest.isNotEmpty ? _selectedTest : _testNames.first,
            onChanged: (value) => setState(() => _selectedTest = value ?? ''),
            items: _testNames.map((test) => DropdownMenuItem(value: test, child: Text(test))).toList(),
          ),
        ),
        Expanded(
          child: _TestWiseLeaderboard(
            classLevel: classLevel,
            testName: _selectedTest.isNotEmpty ? _selectedTest : _testNames.first,
          ),
        ),
      ],
    );
  }

  /// New: Overall Performance combining all recent tests
  Widget _buildOverallLeaderboard(int classLevel) {
    return _OverallPerformanceLeaderboard(classLevel: classLevel);
  }

  Widget _buildSeriesWiseLeaderboard(int classLevel) {
    if (_seriesNames.isEmpty) {
      return Center(child: Text('No test series found', style: GoogleFonts.poppins()));
    }

    return _SeriesWiseLeaderboard(classLevel: classLevel, seriesNames: _seriesNames);
  }
}

class _TestWiseLeaderboard extends ConsumerWidget {
  final int classLevel;
  final String testName;

  const _TestWiseLeaderboard({required this.classLevel, required this.testName});

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .where('testName', isEqualTo: testName)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: SizedBox.shrink());

        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No marks found', style: GoogleFonts.poppins()));
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final marks = data['marks'] as Map<String, dynamic>;
        final rankByRoll = data['rankByRoll'] as Map<String, dynamic>?;
        final maxMarks = _parseDouble(data['maxMarks'] ?? 100);

        final leaderboard = <Map<String, dynamic>>[];
        marks.forEach((roll, mark) {
          leaderboard.add({
            'roll': roll,
            'mark': _parseDouble(mark),
            'rank': rankByRoll?[roll] ?? 0,
          });
        });

        leaderboard.sort((a, b) => (b['rank'] as int).compareTo(a['rank'] as int));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaderboard.length,
          itemBuilder: (context, index) {
            final entry = leaderboard[index];
            final rank = entry['rank'] as int;
            final roll = entry['roll'] as String;
            final mark = entry['mark'] as double;
            final percentage = (mark / maxMarks * 100).toStringAsFixed(1);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              color: rank == 0 ? Colors.grey[200] : Colors.white,
              child: ListTile(
                leading: rank == 0
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
                            rank == 0 ? 'NG' : '$rank',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                title: Text(roll, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rank == 0 ? 'N/G' : '$mark / $maxMarks',
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

  const _SeriesWiseLeaderboard({required this.classLevel, required this.seriesNames});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seriesNames.length,
      itemBuilder: (context, index) => _SeriesCard(
        classLevel: classLevel,
        seriesName: seriesNames[index],
      ),
    );
  }
}

class _SeriesCard extends ConsumerWidget {
  final int classLevel;
  final String seriesName;

  const _SeriesCard({required this.classLevel, required this.seriesName});

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
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('test_marks')
                .where('classLevel', isEqualTo: classLevel)
                .where('seriesId', isEqualTo: seriesName)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 50, child: SizedBox.shrink());

              final studentScores = <String, double>{};
              var maxMark = 0.0;

              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final marks = data['marks'] as Map<String, dynamic>;
                maxMark += _parseDouble(data['maxMarks'] ?? 100);

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
                  final percentage = (entry.value / maxMark * 100).toStringAsFixed(1);

                  return ListTile(
                    leading: _buildRankBadge(idx + 1),
                    title: Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(entry.value.toStringAsFixed(2), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        Text('$percentage%', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      ],
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

/// NEW TAB: Overall Performance combining all tests
class _OverallPerformanceLeaderboard extends ConsumerWidget {
  final int classLevel;

  const _OverallPerformanceLeaderboard({required this.classLevel});

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: SizedBox.shrink());

        if (snapshot.data!.docs.isEmpty) {
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

        // Calculate overall scores by combining all tests
        final studentStats = <String, Map<String, dynamic>>{};
        var totalMaxMarks = 0.0;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final marks = data['marksByRoll'] as Map<String, dynamic>? ?? {};
          final maxMarks = _parseDouble(data['maxMarks'] ?? 100);
          totalMaxMarks += maxMarks;

          marks.forEach((roll, mark) {
            if (!studentStats.containsKey(roll)) {
              studentStats[roll] = {'totalMarks': 0.0, 'testCount': 0, 'maxMarks': 0.0};
            }
            studentStats[roll]!['totalMarks'] = _parseDouble(studentStats[roll]!['totalMarks']) + _parseDouble(mark);
            studentStats[roll]!['testCount'] = (studentStats[roll]!['testCount'] as int) + 1;
            studentStats[roll]!['maxMarks'] = _parseDouble(studentStats[roll]!['maxMarks']) + maxMarks;
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

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: rank <= 3 ? Colors.grey.shade300 : Colors.grey.shade200),
                ),
                color: rank == 1 ? Colors.amber.shade50 : rank == 2 ? Colors.grey.shade100 : Colors.white,
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