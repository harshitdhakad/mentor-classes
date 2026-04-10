import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Detailed Attendance Summary Screen for Students
/// Shows: Total Working Days, Attendance %, Holidays, Absent Days, Monthly Breakdown
class DetailedAttendanceSummaryScreen extends ConsumerStatefulWidget {
  const DetailedAttendanceSummaryScreen({super.key});

  @override
  ConsumerState<DetailedAttendanceSummaryScreen> createState() =>
      _DetailedAttendanceSummaryScreenState();
}

class _DetailedAttendanceSummaryScreenState
    extends ConsumerState<DetailedAttendanceSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null || user.rollNumber == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Attendance Summary',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Sign in as a student to view attendance.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    if (!StudentClassLevels.isValid(user.studentClass)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Attendance Summary',
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
          'Attendance Summary',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<dynamic>(
        future: ref.read(erpRepositoryProvider).getStudentAttendanceSummary(
              classLevel: classLevel,
              rollNumber: rollNumber,
              studentName: studentName,
            ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: SizedBox.shrink());
          }

          final summary = snapshot.data;

          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info Card
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
                            'Student Information',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                    'Roll Number',
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
                                    'Class',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Class $classLevel',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Period: ${summary.dateRange}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Attendance Status Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Color(summary.statusColor).withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(summary.statusColor),
                            child: Text(
                              summary.formattedPercentage,
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Overall Attendance',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(summary.statusColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              summary.statusLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (summary.isAttendanceLow())
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '⚠️ Attendance is below 75%. Please maintain better attendance.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Key Statistics Grid
                  Text(
                    'Attendance Breakdown',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final items = [
                        {
                          'icon': Icons.calendar_today,
                          'label': 'Total Working Days',
                          'value': summary.totalWorkingDays.toString(),
                          'color': AppTheme.deepBlue,
                        },
                        {
                          'icon': Icons.check_circle,
                          'label': 'Present Days',
                          'value': summary.presentDays.toString(),
                          'color': Colors.green,
                        },
                        {
                          'icon': Icons.cancel,
                          'label': 'Absent Days',
                          'value': summary.absentDays.toString(),
                          'color': Colors.red,
                        },
                        {
                          'icon': Icons.event_busy,
                          'label': 'Holidays',
                          'value': summary.holidayCount.toString(),
                          'color': Colors.orange,
                        },
                      ];

                      final item = items[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 32,
                                color: item['color'] as Color,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['value'] as String,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: item['color'] as Color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['label'] as String,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Monthly Breakdown
                  if (summary.monthlyBreakdown.isNotEmpty) ...[
                    Text(
                      'Monthly Breakdown',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: summary.monthlyBreakdown.entries
                              .toList()
                              .reversed
                              .map((entry) {
                                final monthStr = entry.key;
                                final presentInMonth = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        monthStr,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$presentInMonth days',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Footer Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📌 Attendance is typically calculated from April to March (academic year). Regular attendance ensures academic success and school policies compliance.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
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
