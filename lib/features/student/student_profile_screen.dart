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
  @override
  void initState() {
    super.initState();
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .snapshots(),
        builder: (context, studentSnapshot) {
          try {
            // CRITICAL: Check waiting state FIRST
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Check error state AFTER waiting
            if (studentSnapshot.hasError) {
              debugPrint('Student profile error: ${studentSnapshot.error}');
              return const Center(child: Text('Syncing data...'));
            }
            // Check empty data AFTER error
            if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
              return const Center(child: Text('No data available for this class.'));
            }

            final studentData = studentSnapshot.data!.data();

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .snapshots(),
              builder: (context, feesSnapshot) {
                try {
                  // CRITICAL: Check waiting state FIRST
                  if (feesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Check error state AFTER waiting
                  if (feesSnapshot.hasError) {
                    debugPrint('Fees snapshot error: ${feesSnapshot.error}');
                    return const Center(child: Text('Syncing data...'));
                  }
                  // Check empty data AFTER error
                  if (!feesSnapshot.hasData || !feesSnapshot.data!.exists) {
                    return const Center(child: Text('No data available for this class.'));
                  }
                  final feesData = feesSnapshot.data?.data();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('classLevel', isEqualTo: user.studentClass)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  try {
                    // CRITICAL: Check waiting state FIRST
                    if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Check error state AFTER waiting
                    if (attendanceSnapshot.hasError) {
                      debugPrint('Attendance snapshot error: ${attendanceSnapshot.error}');
                      return const Center(child: Text('Syncing data...'));
                    }
                    // Check empty data AFTER error
                    if (!attendanceSnapshot.hasData || attendanceSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No data available for this class.',
                              style: GoogleFonts.poppins(),
                            ),
                          ],
                        ),
                      );
                    }
                    int present = 0;
                    int total = 0;

                  if (attendanceSnapshot.hasData) {
                    for (final doc in attendanceSnapshot.data!.docs) {
                      final data = doc.data();
                      if (data == null) continue;
                      final records = (data as Map<String, dynamic>)['records'] as Map<String, dynamic>?;
                      if (records != null && records.containsKey(user.rollNumber)) {
                        total++;
                        if (records[user.rollNumber] == true) {
                          present++;
                        }
                      }
                    }
                  }

                  final attendancePercentage = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';

                  return SingleChildScrollView(
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
                                    user.displayName[0].toUpperCase(),
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
                                        user.displayName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Roll: ${user.rollNumber}',
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
                  _buildInfoCard('Name', user.displayName),
                  _buildInfoCard('Roll Number', user.rollNumber ?? 'N/A'),
                  _buildInfoCard('Class', '${user.studentClass ?? 'N/A'}'),
                  _buildInfoCard('Email', user.email ?? 'N/A'),
                  _buildInfoCard('Role', user.role.label),
                  _buildInfoCard('Password', (studentData as Map<String, dynamic>?)?['password'] ?? 'N/A'),
                  _buildInfoCard('Phone', (studentData as Map<String, dynamic>?)?['phone'] ?? 'N/A'),
                  _buildInfoCard('Parent Name', (studentData as Map<String, dynamic>?)?['parentName'] ?? 'N/A'),
                  _buildInfoCard('Parent Phone', (studentData as Map<String, dynamic>?)?['parentPhone'] ?? 'N/A'),
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
                          _buildFeesRow('Total Fees', '${(feesData as Map<String, dynamic>?)?['total_fees'] ?? 'N/A'}'),
                          const Divider(),
                          _buildFeesRow('Fees Paid', '${((feesData as Map<String, dynamic>?)?['total_fees'] ?? 0) - ((feesData as Map<String, dynamic>?)?['remaining_fees'] ?? 0)}'),
                          const Divider(),
                          _buildFeesRow('Remaining Fees', '${(feesData as Map<String, dynamic>?)?['remaining_fees'] ?? 'N/A'}', isRemaining: true),
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
                          _buildAttendanceRow('Total Classes', '$total'),
                          const Divider(),
                          _buildAttendanceRow('Present', '$present', color: Colors.green),
                          const Divider(),
                          _buildAttendanceRow('Absent', '${total - present}', color: Colors.red),
                          const SizedBox(height: 12),
                          if (total > 0)
                            LinearProgressIndicator(
                              value: total > 0 ? present / total : 0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          if (total > 0)
                            const SizedBox(height: 8),
                          if (total > 0)
                            Text(
                              'Attendance: $attendancePercentage%',
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
                  _buildInfoCard('Guardian', (studentData as Map<String, dynamic>?)?['emergencyContact'] ?? 'N/A'),
                ],
              ),
            );
                } catch (e) {
                  debugPrint('Error processing attendance data: $e');
                  return const Center(child: Text('Syncing data...'));
                }
                },
              );
            } catch (e) {
              debugPrint('Error processing fees data: $e');
              return const Center(child: Text('Syncing data...'));
            }
            },
          );
        } catch (e) {
          debugPrint('Error processing student profile data: $e');
          return const Center(child: Text('Syncing data...'));
        }
        },
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
