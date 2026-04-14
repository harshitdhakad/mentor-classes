import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../data/erp_repository.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Student: charts, subject-wise averages, and overall series rank.
class StudentPerformanceScreen extends ConsumerStatefulWidget {
  const StudentPerformanceScreen({super.key});

  @override
  ConsumerState<StudentPerformanceScreen> createState() => _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState extends ConsumerState<StudentPerformanceScreen> {
  bool _bar = false;

  Map<String, double> _subjectAverages(List<(String, String, double, double)> data) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final t in data) {
      final sub = t.$2;
      final pct = t.$4 == 0 ? 0.0 : (100 * t.$3 / t.$4);
      sums[sub] = (sums[sub] ?? 0) + pct;
      counts[sub] = (counts[sub] ?? 0) + 1;
    }
    final out = <String, double>{};
    sums.forEach((k, v) {
      final c = counts[k] ?? 1;
      out[k] = v / c;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || user.rollNumber == null || !StudentClassLevels.isValid(user.studentClass)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Performance charts need your class and roll from Firestore.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    final roll = user.rollNumber!;
    final classLevel = user.studentClass!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: classLevel)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        try {
          // CRITICAL: Check waiting state FIRST
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading live updates...'));
          }
          // Check error state AFTER waiting
          if (snap.hasError) {
            debugPrint('Student performance error: ${snap.error}');
            return const Center(child: Text('Syncing data...'));
          }
          // Check empty data AFTER error
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No data available for this class.',
                style: GoogleFonts.poppins(),
              ),
            );
          }

        // Process data from StreamBuilder
        final data = <(String, String, double, double)>[];
        for (final doc in snap.data!.docs) {
          final docData = doc.data() as Map<String, dynamic>;
          final marks = docData['marksByRoll'] as Map<String, dynamic>?;
          final notGivenRolls = (docData['notGivenRolls'] as List?)?.map((e) => e.toString()).toSet() ?? {};
          
          if (marks != null) {
            // Try to find the roll number in marks (could be string or int)
            bool found = false;
            double score = 0.0;
            
            // Check as string
            if (marks.containsKey(roll)) {
              score = (marks[roll] as num?)?.toDouble() ?? 0.0;
              found = true;
            }
            // Check as int
            else if (marks.containsKey(int.tryParse(roll))) {
              score = (marks[int.tryParse(roll)!] as num?)?.toDouble() ?? 0.0;
              found = true;
            }
            
            if (found && !notGivenRolls.contains(roll)) {
              final maxMarks = (docData['maxMarks'] as num?)?.toDouble() ?? 100.0;
              final testName = docData['testName']?.toString() ?? 'Test';
              final subject = docData['subject']?.toString() ?? 'General';
              data.add((testName, subject, score, maxMarks));
            }
          }
        }

        if (data.isEmpty) {
          return Center(
            child: Text(
              'No test marks available for you yet.',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        final spots = <FlSpot>[];
        for (var i = 0; i < data.length; i++) {
          final pct = data[i].$4 == 0 ? 0.0 : (100 * data[i].$3 / data[i].$4);
          spots.add(FlSpot(i.toDouble(), pct));
        }

        final bySubject = _subjectAverages(data);
        final subjectEntries = bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My scores (% of max)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Line')),
                      ButtonSegment(value: true, label: Text('Bar')),
                    ],
                    selected: {_bar},
                    onSelectionChanged: (s) => setState(() => _bar = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: _bar
                        ? BarChart(
                            BarChartData(
                              maxY: 100,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= data.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'T${i + 1}',
                                          style: GoogleFonts.poppins(fontSize: 9),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    getTitlesWidget: (v, m) => Text(
                                      '${v.toInt()}',
                                      style: GoogleFonts.poppins(fontSize: 10),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(show: true, drawVerticalLine: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                for (var i = 0; i < data.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: data[i].$4 == 0 ? 0 : (100 * data[i].$3 / data[i].$4),
                                        color: AppTheme.deepBlue,
                                        width: 14,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              gridData: FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= data.length) return const SizedBox();
                                      return Text('${i + 1}', style: GoogleFonts.poppins(fontSize: 10));
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, m) => Text(
                                      '${v.toInt()}',
                                      style: GoogleFonts.poppins(fontSize: 10),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: AppTheme.deepBlue,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppTheme.deepBlue.withValues(alpha: 0.12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              MentorGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject-wise performance',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                    ),
                    const SizedBox(height: 8),
                    ...subjectEntries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: GoogleFonts.poppins(fontSize: 13))),
                            Text(
                              '${e.value.toStringAsFixed(1)}% avg',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('test_marks')
                      .where('classLevel', isEqualTo: classLevel)
                      .where('testKind', isEqualTo: 'series')
                      .snapshots(),
                  builder: (context, seriesSnap) {
                    try {
                      // CRITICAL: Check waiting state FIRST
                      if (seriesSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Text('Loading live updates...'));
                      }
                      // Check error state AFTER waiting
                      if (seriesSnap.hasError) {
                        debugPrint('Series rank error: ${seriesSnap.error}');
                        return const Center(child: Text('Syncing data...'));
                      }
                      // Check empty data AFTER error
                      if (!seriesSnap.hasData || seriesSnap.data!.docs.isEmpty) {
                        return ListView(
                          children: [
                            Text(
                              'No data available for this class.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 12),
                            Text('Tests (detail)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            ...data.map(
                              (t) => ListTile(
                                dense: true,
                                title: Text(t.$1, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(
                                  '${t.$2} · ${t.$3.toStringAsFixed(1)} / ${t.$4.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    return _SeriesRankBlock(
                      repo: ref.read(erpRepositoryProvider),
                      classLevel: classLevel,
                      roll: roll,
                      seriesDocs: seriesSnap.data!.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
                      testDetailTiles: data
                          .map(
                            (t) => ListTile(
                              dense: true,
                              title: Text(t.$1, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                '${t.$2} · ${t.$3.toStringAsFixed(1)} / ${t.$4.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  } catch (e) {
                    debugPrint('Error processing series rank data: $e');
                    return const Center(child: Text('Syncing data...'));
                  }
                  },
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('Error processing student performance data: $e');
        return const Center(child: Text('Syncing data...'));
      }
      },
    );
  }
}

class _SeriesRankBlock extends StatefulWidget {
  const _SeriesRankBlock({
    required this.repo,
    required this.classLevel,
    required this.roll,
    required this.seriesDocs,
    required this.testDetailTiles,
  });

  final ErpRepository repo;
  final int classLevel;
  final String roll;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> seriesDocs;
  final List<Widget> testDetailTiles;

  @override
  State<_SeriesRankBlock> createState() => _SeriesRankBlockState();
}

class _SeriesRankBlockState extends State<_SeriesRankBlock> {
  late String _seriesId;

  @override
  void initState() {
    super.initState();
    _seriesId = widget.seriesDocs.first.id;
  }

  List<MapEntry<String, double>> _processSeriesRanking(List<QueryDocumentSnapshot> docs, String currentRoll) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final max = _parseDouble(data['maxMarks'] ?? 100);
      if (max <= 0) continue;
      
      final ng = ((data['notGivenRolls'] as List?) ?? []).map((e) => e.toString()).toSet();
      final marks = data['marks'];
      if (marks is! Map) continue;
      
      marks.forEach((k, v) {
        final roll = k.toString();
        if (ng.contains(roll)) return;
        final sc = _parseDouble(v);
        sums[roll] = (sums[roll] ?? 0) + (100 * sc / max);
        counts[roll] = (counts[roll] ?? 0) + 1;
      });
    }
    
    final agg = <MapEntry<String, double>>[];
    sums.forEach((roll, rollSum) {
      final c = counts[roll] ?? 0;
      if (c == 0) return;
      agg.add(MapEntry(roll, rollSum / c));
    });
    agg.sort((a, b) => b.value.compareTo(a.value));
    return agg;
  }
  
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        MentorGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Overall series rank',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _seriesId,
                decoration: const InputDecoration(labelText: 'Test series'),
                isExpanded: true,
                items: [
                  for (final d in widget.seriesDocs)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        d.data()['name']?.toString() ?? 'Series',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _seriesId = v);
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('test_marks')
                    .where('classLevel', isEqualTo: widget.classLevel)
                    .where('seriesId', isEqualTo: _seriesId)
                    .snapshots(),
                builder: (context, rankSnap) {
                  if (rankSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: Text('Loading...')),
                    );
                  }
                  if (rankSnap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: Text('Error loading data')),
                    );
                  }
                  if (!rankSnap.hasData || rankSnap.data!.docs.isEmpty) {
                    return Text(
                      'You have no scored tests in this series yet (or all were NG).',
                      style: GoogleFonts.poppins(fontSize: 12),
                    );
                  }
                  
                  // Process series ranking in real-time
                  final ranking = _processSeriesRanking(rankSnap.data!.docs, widget.roll);
                  if (ranking.isEmpty) {
                    return Text(
                      'You have no scored tests in this series yet (or all were NG).',
                      style: GoogleFonts.poppins(fontSize: 12),
                    );
                  }
                  
                  final idx = ranking.indexWhere((e) => e.key == widget.roll);
                  if (idx < 0) {
                    return Text(
                      'You have no scored tests in this series yet (or all were NG).',
                      style: GoogleFonts.poppins(fontSize: 12),
                    );
                  }
                  final rank = idx + 1;
                  final pct = ranking[idx].value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your rank: #$rank of ${ranking.length}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        'Series average: ${pct.toStringAsFixed(1)}% (mean of % scores across topics)',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Tests (detail)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ...widget.testDetailTiles,
      ],
    );
  }
}
