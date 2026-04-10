import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Student Profile Screen: Shows student's personal details including roll no, class, password, remaining fees, attendance, etc.
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _feesData;
  int _attendancePresent = 0;
  int _attendanceTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    try {
      // Fetch student data from users collection
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (studentDoc.exists) {
        setState(() {
          _studentData = studentDoc.data();
        });
      }

      // Fetch fees data
      final feesDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.id)
          .get();

      if (feesDoc.exists) {
        setState(() {
          _feesData = feesDoc.data();
        });
      }

      // Fetch attendance data
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classLevel', isEqualTo: user.studentClass)
          .get();

      int present = 0;
      int total = 0;

      for (final doc in attendanceSnap.docs) {
        final records = doc.data()['records'] as Map<String, dynamic>?;
        if (records != null && records.containsKey(user.rollNumber)) {
          total++;
          if (records[user.rollNumber] == true) {
            present++;
          }
        }
      }

      setState(() {
        _attendancePresent = present;
        _attendanceTotal = total;
      });
    } catch (e) {
      debugPrint('Error loading student data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null || user.role != UserRole.student) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('This screen is only for students.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: AppTheme.deepBlue,
                            child: Text(
                              (user.displayName ?? 'S')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Roll: ${user.rollNumber ?? 'N/A'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'Class: ${user.studentClass ?? 'N/A'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic Information Section
                  Text(
                    'Basic Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard('Name', user.displayName ?? 'N/A'),
                  _buildInfoCard('Roll Number', user.rollNumber ?? 'N/A'),
                  _buildInfoCard('Class', '${user.studentClass ?? 'N/A'}'),
                  _buildInfoCard('Email', user.email ?? 'N/A'),
                  _buildInfoCard('Mobile', _studentData?['mobileNumber'] ?? 'N/A'),
                  _buildInfoCard('Password', _studentData?['password'] ?? 'N/A'),
                  const SizedBox(height: 24),

                  // Fees Section
                  Text(
                    'Fees Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFeesRow('Total Fees', '${_feesData?['total_fees'] ?? 'N/A'}'),
                          const Divider(),
                          _buildFeesRow('Fees Paid', '${(_feesData?['total_fees'] ?? 0) - (_feesData?['remaining_fees'] ?? 0)}'),
                          const Divider(),
                          _buildFeesRow('Remaining Fees', '${_feesData?['remaining_fees'] ?? 'N/A'}', isRemaining: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Attendance Section
                  Text(
                    'Attendance Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildAttendanceRow('Total Classes', '$_attendanceTotal'),
                          const Divider(),
                          _buildAttendanceRow('Present', '$_attendancePresent', color: Colors.green),
                          const Divider(),
                          _buildAttendanceRow('Absent', '${_attendanceTotal - _attendancePresent}', color: Colors.red),
                          const SizedBox(height: 12),
                          if (_attendanceTotal > 0)
                            LinearProgressIndicator(
                              value: _attendanceTotal > 0 ? _attendancePresent / _attendanceTotal : 0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          if (_attendanceTotal > 0)
                            const SizedBox(height: 8),
                          if (_attendanceTotal > 0)
                            Text(
                              'Attendance: ${((_attendancePresent / _attendanceTotal) * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Emergency Contact
                  Text(
                    'Emergency Contact',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard('Guardian', _studentData?['emergencyContact'] ?? 'N/A'),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesRow(String label, String value, {bool isRemaining = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          '₹$value',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isRemaining ? Colors.red : AppTheme.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.darkGrey,
          ),
        ),
      ],
    );
  }
}
