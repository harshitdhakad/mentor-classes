import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Summary',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('classLevel', isEqualTo: classLevel)
            .orderBy('dateKey', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          try {
            // CRITICAL: Check waiting state FIRST
            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint('Student attendance summary: Waiting for data for class $classLevel');
              return const Center(child: Text('Loading live updates...'));
            }
            // Check error state AFTER waiting
            if (snapshot.hasError) {
              debugPrint('Attendance stream error: ${snapshot.error}');
              return const Center(child: Text('Syncing data...'));
            }
            // Check empty data AFTER error
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              debugPrint('Student attendance summary: No attendance documents found for class $classLevel');
              return Center(
                child: Text(
                  'No data available for Class $classLevel.',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            debugPrint('Student attendance summary: Found ${snapshot.data!.docs.length} attendance documents for class $classLevel');

            // Process attendance data
            int totalDays = 0;
            int presentDays = 0;
            int absentDays = 0;
            int holidays = 0;

            for (final doc in snapshot.data!.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final records = data['records'] as Map<String, dynamic>?;
                final isHoliday = data['isHoliday'] as bool? ?? false;

                if (isHoliday) {
                  holidays++;
                } else {
                  totalDays++;
                  if (records != null && records[rollNumber] == true) {
                    presentDays++;
                  } else {
                    absentDays++;
                  }
                }
              } catch (e) {
                debugPrint('Error processing attendance doc: $e');
              }
            }

            final attendancePercentage = totalDays > 0 ? (presentDays / totalDays * 100).toInt() : 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Stats Card
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
                            'Overall Attendance',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Present',
                                value: presentDays.toString(),
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Absent',
                                value: absentDays.toString(),
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Holidays',
                                value: holidays.toString(),
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Attendance: $attendancePercentage%',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: attendancePercentage >= 75
                                    ? Colors.green
                                    : attendancePercentage >= 50
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                            Text(
                              'Total: $totalDays days',
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
                ),
                const SizedBox(height: 16),
                Text(
                  'Attendance Records',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.deepBlue,
                  ),
                ),
                  const SizedBox(height: 8),
                  ...snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = data['dateKey'] as String? ?? data['date'] as String? ?? 'Unknown';
                    final records = data['records'] as Map<String, dynamic>?;
                    final isHoliday = data['isHoliday'] as bool? ?? false;
                    final isPresent = records != null && records[rollNumber] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isHoliday
                              ? Colors.orange.shade300
                              : isPresent
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isHoliday
                              ? Icons.beach_access
                              : isPresent
                                  ? Icons.check_circle
                                  : Icons.cancel,
                          color: isHoliday
                              ? Colors.orange
                              : isPresent
                                  ? Colors.green
                                  : Colors.red,
                        ),
                        title: Text(
                          date,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          isHoliday
                              ? 'Holiday'
                              : isPresent
                                  ? 'Present'
                                  : 'Absent',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: isHoliday
                                ? Colors.orange
                                : isPresent
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          } catch (e) {
            debugPrint('Attendance widget error: $e');
            return const Center(child: Text('Syncing data...'));
          }
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
