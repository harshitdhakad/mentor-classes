import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
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
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  double _pct = 0;
  int _present = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final user = ref.read(authProvider);
    final repo = ref.read(erpRepositoryProvider);
    if (user == null || user.rollNumber == null) {
      setState(() => _loading = false);
      return;
    }
    final c = user.studentClass;
    if (!StudentClassLevels.isValid(c)) {
      setState(() => _loading = false);
      return;
    }
    final roll = user.rollNumber!;
    final docs = await repo.attendanceInMonth(c!, _month);
    var present = 0;
    var total = 0;
    for (final d in docs) {
      final data = d.data();
      if (data['isHoliday'] == true) continue;
      total++;
      final r = data['records'];
      if (r is Map && r[roll] == true) {
        present++;
      }
    }
    setState(() {
      _docs = docs;
      _present = present;
      _total = total;
      _pct = total == 0 ? 0 : (100 * present / total);
      _loading = false;
    });
  }

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
                      Text(
                        _loading ? '…' : '${_pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _loading ? '' : 'Present on $_present of $_total marked school days (holidays excluded).',
                          style: GoogleFonts.poppins(fontSize: 12, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _month = DateTime(_month.year, _month.month - 1));
                          _refresh();
                        },
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Prev'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _month = DateTime(_month.year, _month.month + 1));
                          _refresh();
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
          child: _loading
              ? const Center(child: Text('Loading attendance...'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MonthDotsGrid(
                    month: _month,
                    roll: roll,
                    classLevel: c,
                    attendanceDocs: _docs,
                  ),
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
      Color dot = Colors.grey.shade400;
      if (data != null) {
        if (data['isHoliday'] == true) {
          dot = Colors.blue.shade300;
        } else {
          final r = data['records'];
          if (r is Map && r[roll] == true) {
            dot = Colors.green.shade600;
          } else {
            dot = Colors.red.shade400;
          }
        }
      }
      cells.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: GoogleFonts.poppins(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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
