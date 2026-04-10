import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../models/performance_analytics_model.dart';

/// Enhanced performance analytics screen with graphs and detailed history
class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({
    required this.classLevel,
    required this.rollNumber,
    required this.studentName,
    super.key,
  });

  final int classLevel;
  final String rollNumber;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(
      studentPerformanceProvider((classLevel, rollNumber, studentName)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$studentName - Performance'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBluePrimary,
        elevation: 0,
      ),
      body: analyticsAsync.when(
        data: (analytics) {
          if (analytics == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No test data available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                _buildSummaryCards(analytics),
                const SizedBox(height: 24),

                // Performance Trend Chart
                _buildPerformanceTrendChart(analytics),
                const SizedBox(height: 24),

                // Analytics Info
                _buildAnalyticsInfo(analytics),
                const SizedBox(height: 24),

                // Test History
                _buildTestHistory(analytics),
              ],
            ),
          );
        },
        loading: () => const Center(child: Text('Loading analytics...')),
        error: (err, stack) => Center(
          child: Text('Error loading analytics. Please try again.'),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(StudentPerformanceAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Overall Performance',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // Summary Metrics
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildMetricCard(
              label: 'Average Score',
              value: '${analytics.overallAverage.toStringAsFixed(1)}%',
              icon: '📊',
              color: Colors.blue,
            ),
            _buildMetricCard(
              label: 'Best Score',
              value: '${analytics.bestPercentage.toStringAsFixed(1)}%',
              icon: '🏆',
              color: Colors.green,
            ),
            _buildMetricCard(
              label: 'Tests Given',
              value: '${analytics.testHistories.length}',
              icon: '✏️',
              color: Colors.orange,
            ),
            _buildMetricCard(
              label: 'Trend',
              value: _getTrendText(analytics.trend),
              icon: _getTrendIcon(analytics.trend),
              color: _getTrendColor(analytics.trend),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String icon,
    required Color color,
  }) {
    return MentorGlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrendChart(StudentPerformanceAnalytics analytics) {
    if (analytics.testHistories.isEmpty) {
      return const SizedBox.shrink();
    }

    final chartData = analytics.testHistories.reversed.toList();
    final maxPercentage = 100.0;

    return MentorGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Trend',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxPercentage,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      interval: 20,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        chartData[index].percentage,
                      ),
                    ),
                    isCurved: true,
                    color: AppTheme.deepBluePrimary,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: AppTheme.deepBluePrimary,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsInfo(StudentPerformanceAnalytics analytics) {
    final strongSubject = analytics.getStrongestSubject() ?? 'N/A';
    final weakSubject = analytics.getWeakestSubject() ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject Analysis',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MentorGlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💪', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Strongest',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                strongSubject,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
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
            const SizedBox(width: 12),
            Expanded(
              child: MentorGlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Needs Work',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                weakSubject,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ],
        ),
      ],
    );
  }

  Widget _buildTestHistory(StudentPerformanceAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test History (${analytics.testHistories.length} tests)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: analytics.testHistories.length,
          itemBuilder: (context, index) {
            final test = analytics.testHistories[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: MentorGlassCard(
                padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              test.testName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  test.subject,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPerformanceColor(test.percentage)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    test.performanceBand,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _getPerformanceColor(test.percentage),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${test.percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _getPerformanceColor(test.percentage),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rank: ${test.classRank}/${test.totalParticipants}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: test.percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        _getPerformanceColor(test.percentage),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${test.marksObtained}/${test.maxMarks}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDate(test.testDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
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
      ],
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTrendText(PerformanceTrend trend) {
    switch (trend) {
      case PerformanceTrend.improving:
        return '📈 Up';
      case PerformanceTrend.stable:
        return '➡️ Stable';
      case PerformanceTrend.declining:
        return '📉 Down';
    }
  }

  String _getTrendIcon(PerformanceTrend trend) {
    switch (trend) {
      case PerformanceTrend.improving:
        return '📈';
      case PerformanceTrend.stable:
        return '➡️';
      case PerformanceTrend.declining:
        return '📉';
    }
  }

  Color _getTrendColor(PerformanceTrend trend) {
    switch (trend) {
      case PerformanceTrend.improving:
        return Colors.green;
      case PerformanceTrend.stable:
        return Colors.blue;
      case PerformanceTrend.declining:
        return Colors.orange;
    }
  }
}
