import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Admin Fees Management Screen - View and update student fee status
class AdminFeesManagementScreen extends ConsumerStatefulWidget {
  const AdminFeesManagementScreen({super.key});

  @override
  ConsumerState<AdminFeesManagementScreen> createState() =>
      _AdminFeesManagementScreenState();
}

class _AdminFeesManagementScreenState
    extends ConsumerState<AdminFeesManagementScreen> {
  String? _selectedClass;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Fees Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
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
                    hintText: 'Search by student name or ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          // Fees List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text('Loading fees data...'));
                }

                var students = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                // Filter by class
                if (_selectedClass != null) {
                  students = students
                      .where((s) => s['studentClass']?.toString() == _selectedClass)
                      .toList();
                }

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  students = students
                      .where((s) =>
                          (s['displayName'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery) ||
                          (s['rollNumber'] ?? '')
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
                    final feesPaid = (student['fees_paid'] ?? 0) as num?;
                    final feesTotal = (student['fees_total'] ?? 0) as num?;
                    final feesRemaining = (feesTotal ?? 0) - (feesPaid ?? 0);
                    final isPaid = feesRemaining == 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          student['displayName'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Roll: ${student['rollNumber'] ?? 'N/A'} | Class: ${student['studentClass'] ?? 'N/A'}',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fees: ₹${feesPaid ?? 0} / ₹${feesTotal ?? 0}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPaid ? 'PAID' : 'PENDING',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isPaid
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showFeeEditDialog(
                            context,
                            student,
                            snapshot.data!.docs[index].id,
                          ),
                        ),
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

  void _showFeeEditDialog(
    BuildContext context,
    Map<String, dynamic> student,
    String docId,
  ) {
    final feesPaidController =
        TextEditingController(text: '${student['fees_paid'] ?? 0}');
    final totalFees = (student['fees_total'] ?? 0) as num?;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Update Fees - ${student['name']}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total Fees - Read Only
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Fees:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₹${totalFees ?? 0}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Fees Paid - Editable
            TextField(
              controller: feesPaidController,
              decoration: const InputDecoration(
                labelText: 'Fees Paid',
                border: OutlineInputBorder(),
                helperText: 'Enter amount paid by student',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final feesPaid =
                  double.tryParse(feesPaidController.text) ?? 0;

              if (feesPaid < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fees paid cannot be negative')),
                );
                return;
              }

              FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .update({
                'fees_paid': feesPaid,
              }).then((_) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fees updated successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }).catchError((e) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              });
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
