import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../../services/cleanup_service.dart';

/// Cleanup Dashboard Screen with test score calculation and class selector
/// Displays total score calculation based on SST, Science, Maths, English results
/// with class selector dropdown for test results criteria
class CleanupDashboardScreen extends ConsumerStatefulWidget {
  const CleanupDashboardScreen({super.key});

  @override
  ConsumerState<CleanupDashboardScreen> createState() =>
      _CleanupDashboardScreenState();
}

class _CleanupDashboardScreenState extends ConsumerState<CleanupDashboardScreen> {
  final CleanupService _cleanupService = CleanupService();
  int _selectedClass = 5;
  bool _isRunningCleanup = false;
  CleanupResult? _lastCleanupResult;

  final List<int> _classLevels = [5, 6, 7, 8, 9, 10];
  final List<String> _subjects = ['SST', 'Science', 'Maths', 'English'];

  @override
  void initState() {
    super.initState();
    _cleanupService.startPeriodicCleanup();
  }

  @override
  void dispose() {
    _cleanupService.stopPeriodicCleanup();
    super.dispose();
  }

  Future<void> _triggerManualCleanup() async {
    setState(() => _isRunningCleanup = true);
    
    final result = await _cleanupService.triggerManualCleanup();
    
    setState(() {
      _isRunningCleanup = false;
      _lastCleanupResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    
    // Authentication check
    if (user == null || !user.isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'Access Denied: This section is for staff only',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧹 Cleanup Dashboard'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBluePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Selector
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Class for Test Results',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedClass,
                      decoration: InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _classLevels.map((classLevel) {
                        return DropdownMenuItem<int>(
                          value: classLevel,
                          child: Text('Class $classLevel'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedClass = value ?? 5);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Test Score Calculation Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Score Calculation',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('test_marks')
                          .where('classLevel', isEqualTo: _selectedClass)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Text(
                              'Loading...',
                              style: TextStyle(fontSize: 14),
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Error loading test data',
                              style: TextStyle(fontSize: 14, color: Colors.red),
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'object-not-found',
                              style: TextStyle(fontSize: 14),
                            ),
                          );
                        }

                        // Calculate total scores by subject
                        final subjectScores = <String, double>{};
                        final subjectCounts = <String, int>{};
                        
                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final subject = data['subject'] as String? ?? 'General';
                          final marks = data['marks'] as Map<String, dynamic>?;
                          
                          if (marks != null && _subjects.contains(subject)) {
                            double total = 0;
                            int count = 0;
                            for (final mark in marks.values) {
                              if (mark is num) {
                                total += mark.toDouble();
                                count++;
                              }
                            }
                            subjectScores[subject] = (subjectScores[subject] ?? 0) + total;
                            subjectCounts[subject] = (subjectCounts[subject] ?? 0) + count;
                          }
                        }

                        // Display results
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._subjects.map((subject) {
                              final totalScore = subjectScores[subject] ?? 0;
                              final count = subjectCounts[subject] ?? 0;
                              final average = count > 0 ? totalScore / count : 0.0;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      subject,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    Text(
                                      'Total: ${totalScore.toStringAsFixed(1)} | Avg: ${average.toStringAsFixed(1)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.deepBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Grand Total',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  subjectScores.values.fold<double>(0, (sum, score) => sum + score).toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cleanup Controls
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Homework Cleanup Controls',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Periodic cleanup runs every 30 minutes automatically.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isRunningCleanup ? null : _triggerManualCleanup,
                      icon: _isRunningCleanup
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cleaning_services),
                      label: Text(
                        _isRunningCleanup ? 'Cleaning...' : 'Trigger Manual Cleanup',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepBluePrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_lastCleanupResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastCleanupResult!.success
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _lastCleanupResult!.success
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastCleanupResult!.success
                                  ? '✅ Cleanup Successful'
                                  : '❌ Cleanup Failed',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _lastCleanupResult!.success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deleted: ${_lastCleanupResult!.totalDeleted} documents',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            if (_lastCleanupResult!.deletedByClass.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'By Class: ${_lastCleanupResult!.deletedByClass.entries.map((e) => 'Class ${e.key}: ${e.value}').join(', ')}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ],
                            if (_lastCleanupResult!.error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Error: ${_lastCleanupResult!.error}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
