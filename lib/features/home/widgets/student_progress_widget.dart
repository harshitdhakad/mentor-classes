import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_service.dart';

/// Student Progress Graph Widget - Shows score trends across tests
class StudentProgressGraph extends ConsumerWidget {
  final int classLevel;

  const StudentProgressGraph({
    Key? key,
    required this.classLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null || user.rollNumber == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .doc(classLevel.toString())
          .collection('tests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading data'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Performance',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No tests taken yet',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final roll = user.rollNumber!;
        final scores = <_TestScore>[];
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final marks = data['marks'] as Map?;
          final notGivenRolls = (data['notGivenRolls'] as List?)?.cast<String>() ?? [];

          if (marks != null && marks.containsKey(roll) && !notGivenRolls.contains(roll)) {
            final score = (marks[roll] as num?)?.toDouble() ?? 0.0;
            final maxMarks = (data['maxMarks'] as num?)?.toDouble() ?? 100.0;
            final percentage = (score / maxMarks * 100).clamp(0.0, 100.0);

            scores.add(_TestScore(
              testName: data['testName']?.toString() ?? 'Test',
              subject: data['subject']?.toString() ?? 'General',
              score: score,
              maxMarks: maxMarks,
              percentage: percentage,
              date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ));
          }
        }

        // Sort by date
        scores.sort((a, b) => a.date.compareTo(b.date));
        
        if (scores.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Performance',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No tests taken yet',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _ProgressChartCard(scores: scores);
      },
    );
  }
}

class _ProgressChartCard extends StatelessWidget {
  final List<_TestScore> scores;

  const _ProgressChartCard({required this.scores});

  @override
  Widget build(BuildContext context) {
    final avg = scores.isEmpty ? 0.0 : scores.map((s) => s.percentage).reduce((a, b) => a + b) / scores.length;
    final best = scores.isEmpty ? 0.0 : scores.map((s) => s.percentage).reduce((a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Performance',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${scores.length} ${scores.length == 1 ? 'test' : 'tests'} taken',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatBadge(label: 'AVG', value: '${avg.toStringAsFixed(1)}%'),
                    const SizedBox(height: 4),
                    _StatBadge(label: 'BEST', value: '${best.toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < scores.length) {
                            return Text(
                              'T${idx + 1}',
                              style: GoogleFonts.poppins(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: GoogleFonts.poppins(fontSize: 10),
                        ),
                        interval: 20,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (scores.length - 1).toDouble().clamp(0, 10),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: scores.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.percentage);
                      }).toList(),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [AppTheme.deepBlue, AppTheme.successGreen],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppTheme.deepBlue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.deepBlue.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test list
            if (scores.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: scores.length,
                  itemBuilder: (context, idx) {
                    final score = scores[idx];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            score.testName,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            score.subject,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${score.score.toStringAsFixed(0)}/${score.maxMarks.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          Text(
                            '${score.percentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: score.percentage >= 70
                                  ? Colors.green
                                  : score.percentage >= 50
                                      ? Colors.orange
                                      : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.deepBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestScore {
  final String testName;
  final String subject;
  final double score;
  final double maxMarks;
  final double percentage;
  final DateTime date;

  _TestScore({
    required this.testName,
    required this.subject,
    required this.score,
    required this.maxMarks,
    required this.percentage,
    required this.date,
  });
}
