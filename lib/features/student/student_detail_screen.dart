import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../auth/auth_service.dart';

/// Teacher/Admin view: student detail with fees management (role-based access).
class StudentDetailScreen extends ConsumerStatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentDocId,
    required this.studentName,
    required this.studentRoll,
  });

  final String studentDocId;
  final String studentName;
  final String studentRoll;

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  late TextEditingController _totalFeesCtrl;
  late TextEditingController _paidCtrl;
  bool _loading = true;
  bool _saving = false;
  double _currentTotalFees = 0;
  double _currentRemainingFees = 0;
  int _studentClass = 0;

  /// Helper to parse dynamic values to double
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _totalFeesCtrl = TextEditingController();
    _paidCtrl = TextEditingController();
    _loadFees();
  }

  @override
  void dispose() {
    _totalFeesCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFees() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(erpRepositoryProvider);
      final data = await repo.getStudentWithFees(widget.studentDocId);
      if (data != null) {
        _currentTotalFees = _parseDouble(data['total_fees'] ?? 0);
        _currentRemainingFees = _parseDouble(data['remaining_fees'] ?? _currentTotalFees);
        _totalFeesCtrl.text = _currentTotalFees > 0 ? _currentTotalFees.toString() : '';
        _paidCtrl.text = _calculatePaidFees().toStringAsFixed(2);
        _studentClass = data['studentClass'] ?? 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fees: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _calculatePaidFees() {
    final paid = _currentTotalFees - _currentRemainingFees;
    return paid.clamp(0.0, _currentTotalFees);
  }

  double get _calculatedPending {
    final total = double.tryParse(_totalFeesCtrl.text) ?? 0;
    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    final pending = (total - paid).clamp(0.0, total);
    return pending;
  }

  Future<void> _updateFees() async {
    final total = double.tryParse(_totalFeesCtrl.text) ?? 0;
    final paid = double.tryParse(_paidCtrl.text) ?? 0;

    if (total < 0 || paid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid amounts (≥0)')),
      );
      return;
    }

    if (paid > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid amount cannot exceed total fees')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(erpRepositoryProvider).updateStudentFees(
            studentDocId: widget.studentDocId,
            totalFees: total,
            paidAmount: paid,
          );
      _currentTotalFees = total;
      _currentRemainingFees = (total - paid).clamp(0.0, total);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fees updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating fees: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStaff = user?.isStaff ?? false;

    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Fees information is only available to staff.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.studentName),
            Text(
              'Roll: ${widget.studentRoll}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: Text('Loading student details...'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student Info Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Information',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Name:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                widget.studentName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Roll No:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                widget.studentRoll,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Attendance Summary Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Summary (Year)',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _studentClass > 0
                              ? StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('attendance')
                                      .where('classLevel', isEqualTo: _studentClass)
                                      .orderBy('dateKey', descending: false)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Text('No attendance data available');
                                    }

                                    int totalDays = 0;
                                    int presentDays = 0;
                                    int absentDays = 0;
                                    int holidays = 0;

                                    for (final doc in snapshot.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final records = data['records'] as Map<String, dynamic>?;
                                      final isHoliday = data['isHoliday'] as bool? ?? false;

                                      if (isHoliday) {
                                        holidays++;
                                      } else {
                                        totalDays++;
                                        if (records != null && records[widget.studentRoll] == true) {
                                          presentDays++;
                                        } else {
                                          absentDays++;
                                        }
                                      }
                                    }

                                    final attendancePercentage = totalDays > 0 ? (presentDays / totalDays * 100).toInt() : 0;

                                    return Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildAttendanceStat('Present', presentDays, Colors.green),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildAttendanceStat('Absent', absentDays, Colors.red),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildAttendanceStat('Holidays', holidays, Colors.orange),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: attendancePercentage >= 75
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : attendancePercentage >= 50
                                                    ? Colors.orange.withValues(alpha: 0.1)
                                                    : Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: attendancePercentage >= 75
                                                  ? Colors.green
                                                  : attendancePercentage >= 50
                                                      ? Colors.orange
                                                      : Colors.red,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Attendance: $attendancePercentage%',
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: attendancePercentage >= 75
                                                    ? Colors.green
                                                    : attendancePercentage >= 50
                                                        ? Colors.orange
                                                        : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : const Text('Loading class data...'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fees Section
                  Text(
                    'Fees Management',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Total Fees Input
                  TextField(
                    controller: _totalFeesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Fees (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_outlined),
                      hintText: 'e.g., 5000',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Amount Paid Input
                  TextField(
                    controller: _paidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (₹)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      hintText: 'e.g., 2000',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // Pending Amount Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Amount:',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        Text(
                          '₹${_calculatedPending.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _calculatedPending > 0
                                ? AppTheme.warningOrange
                                : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Update Button
                  FilledButton.icon(
                    onPressed: _saving ? null : _updateFees,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Saving...' : 'Update Fees'),
                  ),
                  const SizedBox(height: 16),

                  // View Performance Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const Text('Enhanced Detail'), // Placeholder
                        ),
                      );
                    },
                    icon: const Icon(Icons.assessment),
                    label: const Text('View Performance Stats'),
                  ),
                  const SizedBox(height: 40),

                  // Info Section
                  Card(
                    color: AppTheme.lightGrey,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Privacy Notice',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This fees information is private and only visible to staff (Admins & Teachers). Students do not see their fees in the app yet.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.5,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttendanceStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
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
            value.toString(),
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
