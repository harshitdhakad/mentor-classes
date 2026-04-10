import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

/// Admin/Teacher Student Management Screen
class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  String? _selectedClass;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedStudentIds = {};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStaff = user?.isStaff ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedStudentIds.length} Selected'
              : 'Student Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedStudentIds.isEmpty
                  ? null
                  : () => _deleteSelectedStudents(),
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedStudentIds.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Class Filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                  ),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: '${i + 1}',
                      child: Text('Class ${i + 1}'),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _selectedClass = value),
                ),
                const SizedBox(height: 12),
                // Search
                TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or roll number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          // Students List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text('Loading students...'));
                }

                var students = snapshot.data!.docs;

                // Filter by class
                if (_selectedClass != null) {
                  students = students
                      .where((doc) =>
                          (doc['studentClass'] ?? '').toString() ==
                          _selectedClass)
                      .toList();
                }

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  students = students
                      .where((doc) =>
                          (doc['displayName'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery) ||
                          (doc['rollNumber'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery))
                      .toList();
                }

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found',
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final data = student.data() as Map<String, dynamic>;
                    final isSelected = _selectedStudentIds.contains(student.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? AppTheme.deepBlue.withValues(alpha: 0.1) : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStudentIds.add(student.id);
                                    } else {
                                      _selectedStudentIds.remove(student.id);
                                    }
                                  });
                                },
                              )
                            : CircleAvatar(
                                backgroundColor: AppTheme.deepBlue,
                                child: Text(
                                  (data['displayName'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        title: Text(
                          data['displayName'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Roll: ${data['rollNumber'] ?? 'N/A'} | Class: ${data['studentClass'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: _isSelectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () => _navigateToDetails(
                                  context,
                                  student.id,
                                  data,
                                ),
                              ),
                        onLongPress: isStaff
                            ? () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedStudentIds.add(student.id);
                                });
                              }
                            : null,
                        onTap: _isSelectionMode && isStaff
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStudentIds.remove(student.id);
                                  } else {
                                    _selectedStudentIds.add(student.id);
                                  }
                                });
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(
    BuildContext context,
    String studentId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentDetailsScreen(studentId: studentId, studentData: data),
      ),
    );
  }

  Future<void> _deleteSelectedStudents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${_selectedStudentIds.length} Student(s)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.red),
        ),
        content: Text(
          'This will permanently delete the selected students from Firestore. This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final studentId in _selectedStudentIds) {
        // Delete from users collection
        batch.delete(FirebaseFirestore.instance.collection('users').doc(studentId));
        // Delete from students collection
        batch.delete(FirebaseFirestore.instance.collection('students').doc(studentId));
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedStudentIds.length} student(s) deleted successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error deleting students: $e')),
        );
      }
    }
  }
}

/// Student Details Screen
class StudentDetailsScreen extends ConsumerWidget {
  final String studentId;
  final Map<String, dynamic> studentData;

  const StudentDetailsScreen({
    super.key,
    required this.studentId,
    required this.studentData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesPaid = (studentData['fees_paid'] ?? 0) as num?;
    final feesTotal = (studentData['fees_total'] ?? 0) as num?;
    final feesRemaining = (feesTotal ?? 0) - (feesPaid ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.deepBlue,
                      child: Text(
                        (studentData['displayName'] ?? 'S')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentData['displayName'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Roll: ${studentData['rollNumber'] ?? 'N/A'} | Class: ${studentData['studentClass'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
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
            const SizedBox(height: 20),

            // Basic Info Section
            Text(
              'Basic Information',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoCard('Email', studentData['email'] ?? 'N/A'),
            _buildInfoCard(
                'Phone', studentData['mobileNumber'] ?? studentData['phone'] ?? 'N/A'),
            _buildInfoCard(
                'Guardian', studentData['emergencyContact'] ?? studentData['guardian_name'] ?? 'N/A'),
            const SizedBox(height: 20),

            // Fees Status Section
            Text(
              'Fee Status',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: feesRemaining == 0
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Fees',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '₹${feesTotal?.toInt() ?? 0}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fees Paid',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '₹${feesPaid?.toInt() ?? 0}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: feesRemaining == 0
                            ? Colors.green
                            : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        feesRemaining == 0
                            ? 'PAID'
                            : 'Pending: ₹${feesRemaining.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Attendance Summary
            Text(
              'Quick Stats',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Tests',
                    '${studentData['total_tests'] ?? 0}',
                    AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Score',
                    '${(studentData['avg_score'] ?? 0).toStringAsFixed(1)}%',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}
