import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../auth/auth_service.dart';

/// Admin Fees Panel - View and manage fees for all students
/// Admin only screen to see remaining fees, update fees, etc.
class AdminFeesPanelScreen extends ConsumerStatefulWidget {
  const AdminFeesPanelScreen({super.key});

  @override
  ConsumerState<AdminFeesPanelScreen> createState() =>
      _AdminFeesPanelScreenState();
}

class _AdminFeesPanelScreenState extends ConsumerState<AdminFeesPanelScreen> {
  int _selectedClass = 5;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    
    // Authentication check - admin only
    if (user == null || user.role.name != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'Access Denied: This section is for admin only',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Admin Fees Panel'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBluePrimary,
      ),
      body: Column(
        children: [
          // Class Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Class',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(6, (index) {
                      final classNum = index + 5;
                      final isSelected = _selectedClass == classNum;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('Class $classNum'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedClass = classNum);
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: AppTheme.deepBlue.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppTheme.deepBlue : Colors.black87,
                          ),
                        ),
                      );
                    }),
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
                  .where('studentClass', isEqualTo: _selectedClass)
                  .snapshots(),
              builder: (context, snapshot) {
                try {
                  // CRITICAL: Check waiting state FIRST
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Text('Loading live student list...'),
                    );
                  }
                  // Check error state AFTER waiting
                  if (snapshot.hasError) {
                    debugPrint('Fees panel error: ${snapshot.error}');
                    return const Center(
                      child: Text('Error loading list'),
                    );
                  }
                  // Check empty data AFTER error
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No students found for this class.'),
                    );
                  }

                  final students = snapshot.data!.docs;
                  int totalPaid = 0;
                  int totalPending = 0;

                  for (final doc in students) {
                    try {
                      final data = doc.data() as Map<String, dynamic>;
                      final total = (data['total_fees'] as num?)?.toDouble() ?? 0.0;
                      final remaining = (data['remaining_fees'] as num?)?.toDouble() ?? total;
                      final paid = total - remaining;
                      totalPaid += paid.toInt();
                      totalPending += remaining.toInt();
                    } catch (e) {
                      debugPrint('Error processing fee data: $e');
                    }
                  }

                  return Column(
                    children: [
                      // Summary Card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SummaryItem(
                              label: 'Total Students',
                              value: students.length.toString(),
                              color: AppTheme.deepBlue,
                            ),
                            _SummaryItem(
                              label: 'Total Paid',
                              value: '₹$totalPaid',
                              color: Colors.green,
                            ),
                            _SummaryItem(
                              label: 'Total Pending',
                              value: '₹$totalPending',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                      // Students List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            try {
                              final doc = students[index];
                              final data = doc.data() as Map<String, dynamic>;
                              // Mandatory fields: Name, RollNo, Class, Password
                              final name = data['displayName'] as String? ?? data['name'] as String? ?? 'Unknown';
                              final rollNumber = data['rollNumber'] as String? ?? data['rollNo'] as String? ?? data['roll'] as String? ?? '';
                              final studentClass = data['studentClass'] as int? ?? data['class'] as int? ?? data['classLevel'] as int? ?? 0;
                              final password = data['password'] as String? ?? '';
                              
                              // Fees data with defaults
                              final total = (data['total_fees'] as num?)?.toDouble() ?? 0.0;
                              final remaining = (data['remaining_fees'] as num?)?.toDouble() ?? total;
                              final paid = total - remaining;
                              final percentage = total > 0 ? (paid / total * 100).toInt() : 0;
                              
                              // Verify mandatory fields are present
                              if (name.isEmpty || rollNumber.isEmpty || studentClass == 0 || password.isEmpty) {
                                debugPrint('Missing mandatory fields for student: name=$name, rollNo=$rollNumber, class=$studentClass, password=${password.isNotEmpty ? "***" : ""}');
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: remaining > 0 ? Colors.red.shade300 : Colors.green.shade300,
                                  ),
                                ),
                                child: ExpansionTile(
                                  title: Text(
                                    '$name ($rollNumber)',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Pending: ₹${remaining.toInt()}',
                                    style: GoogleFonts.poppins(
                                      color: remaining > 0 ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$percentage%',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: percentage == 100
                                              ? Colors.green
                                              : percentage > 50
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        'Paid',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _FeesDetailRow(
                                            label: 'Total Fees',
                                            value: '₹${total.toInt()}',
                                            color: Colors.black87,
                                          ),
                                          _FeesDetailRow(
                                            label: 'Paid Fees',
                                            value: '₹${paid.toInt()}',
                                            color: Colors.green,
                                          ),
                                          _FeesDetailRow(
                                            label: 'Pending Fees',
                                            value: '₹${remaining.toInt()}',
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          LinearProgressIndicator(
                                            value: percentage / 100,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              percentage == 100
                                                  ? Colors.green
                                                  : percentage > 50
                                                      ? Colors.orange
                                                      : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _showUpdateFeesDialog(doc.id, paid, total),
                                                  icon: const Icon(Icons.edit),
                                                  label: const Text('Update Fees'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppTheme.deepBluePrimary,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error rendering fee card: $e');
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ],
                  );
                } catch (e) {
                  debugPrint('Fees panel widget error: $e');
                  return const Center(child: Text('Error loading fees data'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateFeesDialog(String docId, double currentTotal, double currentRemaining) async {
    final currentPaid = currentTotal - currentRemaining;
    final totalController = TextEditingController(text: currentTotal.toStringAsFixed(0));
    final paidController = TextEditingController(text: currentPaid.toStringAsFixed(0));
    double remainingFees = currentRemaining;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Update Fees',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total Fees (Read-only)
              TextField(
                controller: totalController,
                decoration: InputDecoration(
                  labelText: 'Total Fees',
                  prefixText: '₹',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: const Icon(Icons.lock, size: 20, color: Colors.grey),
                ),
                keyboardType: TextInputType.number,
                enabled: false,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // Paid Fees (Editable)
              TextField(
                controller: paidController,
                decoration: InputDecoration(
                  labelText: 'Paid Fees',
                  prefixText: '₹',
                  border: const OutlineInputBorder(),
                  helperText: 'Enter amount paid by student',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final paid = double.tryParse(value) ?? 0;
                  final total = double.tryParse(totalController.text) ?? 0;
                  setDialogState(() {
                    remainingFees = total - paid;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Remaining Fees (Auto-calculated, Read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: remainingFees <= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: remainingFees <= 0 ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Fees',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${remainingFees.toInt()}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: remainingFees <= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final total = double.tryParse(totalController.text) ?? currentTotal;
      final paid = double.tryParse(paidController.text) ?? currentPaid;
      final newRemaining = total - paid;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .update({
          'total_fees': total,
          'remaining_fees': newRemaining,
          'paid_fees': paid,
          'fees_updated_at': FieldValue.serverTimestamp(),
        });

        // Trigger global refresh to update all screens immediately
        ref.invalidate(refreshTriggerProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Fees updated: Paid ₹${paid.toInt()}, Remaining ₹${newRemaining.toInt()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating fees in users collection: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error updating fees: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    totalController.dispose();
    paidController.dispose();
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
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

class _FeesDetailRow extends StatelessWidget {
  const _FeesDetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
