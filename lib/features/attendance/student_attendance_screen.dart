import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_repository.dart' show ErpRepository;
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Student/parent view: attendance % and month calendar with red/green dots.
class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends ConsumerState<StudentAttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || user.rollNumber == null) {
      return Center(child: Text('Sign in as a student.', style: GoogleFonts.poppins()));
    }
    if (!StudentClassLevels.isValid(user.studentClass)) {
      return Center(
        child: Text(
          'Your class is not set. Ask admin to update your profile.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(),
        ),
      );
    }

    final roll = user.rollNumber!;
    final c = user.studentClass!;

    // Real-time attendance stream for the selected month
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final monthStartKey = ErpRepository.dateKey(monthStart);
    final monthEndKey = ErpRepository.dateKey(monthEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance overview',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${DateFormat.yMMMM().format(_month)} · Class $c · Roll $roll',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _month = DateTime(_month.year, _month.month - 1));
                        },
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Prev'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _month = DateTime(_month.year, _month.month + 1));
                        },
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('classLevel', isEqualTo: c)
                .where('dateKey', isGreaterThanOrEqualTo: monthStartKey)
                .where('dateKey', isLessThanOrEqualTo: monthEndKey)
                .orderBy('dateKey')
                .snapshots(),
            builder: (context, snapshot) {
              try {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Text('Loading...'));
                }
                if (snapshot.hasError) {
                  debugPrint('Student attendance error: ${snapshot.error}');
                  return const Center(child: Text('Error loading attendance'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No attendance data for this month'));
                }

                final docs = snapshot.data!.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                var present = 0;
                var total = 0;
                var holidays = 0;
                var absent = 0;
                for (final d in docs) {
                  try {
                    final data = d.data() as Map<String, dynamic>?;
                    if (data == null) continue;
                    if (data['isHoliday'] == true) {
                      holidays++;
                      continue;
                    }
                    total++;
                    final r = data['records'] as Map<String, dynamic>?;
                    if (r != null && r[roll] == true) {
                      present++;
                    } else {
                      absent++;
                    }
                  } catch (e) {
                    debugPrint('Error processing attendance doc: $e');
                  }
                }

                return Column(
                  children: [
                    // Stats Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(label: 'Work Days', value: '$total', color: Colors.black87),
                              _StatItem(label: 'Present', value: '$present', color: Colors.green),
                              _StatItem(label: 'Absent', value: '$absent', color: Colors.red),
                              _StatItem(label: 'Holidays', value: '$holidays', color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Calendar Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _MonthDotsGrid(
                          month: _month,
                          roll: roll,
                          classLevel: c,
                          attendanceDocs: docs,
                        ),
                      ),
                    ),
                  ],
                );
              } catch (e) {
                debugPrint('Student attendance widget error: $e');
                return const Center(child: Text('Error loading attendance'));
              }
            },
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _MonthDotsGrid extends StatelessWidget {
  const _MonthDotsGrid({
    required this.month,
    required this.roll,
    required this.classLevel,
    required this.attendanceDocs,
  });

  final DateTime month;
  final String roll;
  final int classLevel;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs;

  Map<String, Map<String, dynamic>> get _byDate {
    final m = <String, Map<String, dynamic>>{};
    for (final d in attendanceDocs) {
      final dk = d.data()['dateKey']?.toString();
      if (dk != null) m[dk] = d.data();
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final startWeekday = first.weekday % 7;
    final daysInMonth = last.day;
    final cells = <Widget>[];

    const headers = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (final h in headers) {
      cells.add(
        Center(
          child: Text(h, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.deepBlue)),
        ),
      );
    }
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final dk = ErpRepository.dateKey(DateTime(month.year, month.month, day));
      final data = _byDate[dk];
      Color circleColor = Colors.grey.shade400;
      if (data != null) {
        if (data['isHoliday'] == true) {
          circleColor = Colors.blue.shade600;
        } else {
          final r = data['records'];
          if (r is Map && r[roll] == true) {
            circleColor = Colors.green.shade600;
          } else {
            circleColor = Colors.red.shade600;
          }
        }
      }
      cells.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 0.85,
      children: cells,
    );
  }
}
