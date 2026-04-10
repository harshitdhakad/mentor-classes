import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../auth/auth_service.dart';

/// Student view: personal fees information (private to own account only).
class StudentFeesScreen extends ConsumerStatefulWidget {
  const StudentFeesScreen({super.key});

  @override
  ConsumerState<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends ConsumerState<StudentFeesScreen> {
  bool _loading = true;
  double _totalFees = 0;
  double _paidFees = 0;
  double _remainingFees = 0;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider);
      if (user == null || user.role.name != 'student') {
        throw 'Access denied: Students only';
      }

      final repo = ref.read(erpRepositoryProvider);
      final data = await repo.getStudentWithFees(user.id);
      if (data != null) {
        final totalFees = _parseDouble(data['total_fees'] ?? 0);
        final remainingFees = _parseDouble(data['remaining_fees'] ?? totalFees);
        _totalFees = totalFees;
        _remainingFees = remainingFees;
        _paidFees = (totalFees - remainingFees).clamp(0.0, totalFees);
        _lastUpdated = (data['fees_updated_at'] as dynamic)?.toDate() as DateTime?;
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

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fees'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: Text('Loading fees data...'))
          : user?.role.name != 'student'
              ? Center(
                  child: Text(
                    'This section is for students only',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Main Fees Summary Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: AppTheme.lightGrey,
                                child: Text(
                                  '₹',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Fees Summary',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Total Fees
                              _FeesSummaryRow(
                                label: 'Total Fees',
                                amount: _totalFees,
                                color: AppTheme.infoBlue,
                              ),
                              const SizedBox(height: 16),

                              // Amount Paid
                              _FeesSummaryRow(
                                label: 'Amount Paid',
                                amount: _paidFees,
                                color: AppTheme.successGreen,
                              ),
                              const SizedBox(height: 16),

                              // Pending/Remaining
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _remainingFees > 0
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _remainingFees > 0
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pending Amount',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    Text(
                                      '₹${_remainingFees.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: _remainingFees > 0
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
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

                      // Payment Status
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _remainingFees == 0
                                        ? Icons.check_circle
                                        : Icons.info,
                                    color: _remainingFees == 0
                                        ? AppTheme.successGreen
                                        : AppTheme.warningOrange,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _remainingFees == 0
                                          ? 'Payment Complete'
                                          : 'Pending Payment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _remainingFees == 0
                                    ? 'All fees have been paid. Thank you!'
                                    : '₹${_remainingFees.toStringAsFixed(2)} remaining. Please contact the office for payment details.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Last Updated
                      if (_lastUpdated != null)
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Last updated: ${DateFormat('d MMM yyyy, h:mm a').format(_lastUpdated!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}

class _FeesSummaryRow extends StatelessWidget {
  const _FeesSummaryRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkGrey,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
