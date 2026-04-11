import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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
                          selectedColor: AppTheme.deepBlue.withOpacity(0.2),
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
                  .collection('students')
                  .where('classLevel', isEqualTo: _selectedClass)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Text('Loading...'),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading fees data'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('object-not-found'),
                  );
                }

                final students = snapshot.data!.docs;
                int totalPaid = 0;
                int totalPending = 0;

                for (final doc in students) {
                  final data = doc.data() as Map<String, dynamic>;
                  final total = (data['total_fees'] as num?)?.toDouble() ?? 0.0;
                  final remaining = (data['remaining_fees'] as num?)?.toDouble() ?? total;
                  final paid = total - remaining;
                  totalPaid += paid.toInt();
                  totalPending += remaining.toInt();
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
                          final doc = students[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] as String? ?? 'Unknown';
                          final rollNumber = data['rollNumber'] as String? ?? '';
                          final total = (data['total_fees'] as num?)?.toDouble() ?? 0.0;
                          final remaining = (data['remaining_fees'] as num?)?.toDouble() ?? total;
                          final paid = total - remaining;
                          final percentage = total > 0 ? (paid / total * 100).toInt() : 0;

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
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateFeesDialog(String docId, double currentTotal, double currentRemaining) async {
    final totalController = TextEditingController(text: currentTotal.toStringAsFixed(0));
    final remainingController = TextEditingController(text: currentRemaining.toStringAsFixed(0));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Fees',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalController,
              decoration: const InputDecoration(
                labelText: 'Total Fees',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remainingController,
              decoration: const InputDecoration(
                labelText: 'Remaining Fees',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
    );

    if (result == true) {
      final newTotal = double.tryParse(totalController.text) ?? currentTotal;
      final newRemaining = double.tryParse(remainingController.text) ?? currentRemaining;

      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(docId)
            .update({
          'total_fees': newTotal,
          'remaining_fees': newRemaining,
          'fees_updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Fees updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
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
    remainingController.dispose();
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
