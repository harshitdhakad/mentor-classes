import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/excel_generator.dart';
import '../../data/erp_providers.dart';
import '../../models/performance_model.dart';
import '../auth/auth_service.dart';

/// Enhanced student detail screen with performance stats and Excel export
class EnhancedStudentDetailScreen extends ConsumerStatefulWidget {
  const EnhancedStudentDetailScreen({
    super.key,
    required this.studentDocId,
    required this.studentName,
    required this.studentRoll,
    required this.classLevel,
  });

  final String studentDocId;
  final String studentName;
  final String studentRoll;
  final int classLevel;

  @override
  ConsumerState<EnhancedStudentDetailScreen> createState() => _EnhancedStudentDetailScreenState();
}

class _EnhancedStudentDetailScreenState extends ConsumerState<EnhancedStudentDetailScreen> {
  late TextEditingController _totalFeesCtrl;
  late TextEditingController _paidCtrl;
  bool _savingFees = false;
  bool _generatingExcel = false;
  late StudentPerformance _performance;

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
    _performance = StudentPerformance(
      studentRoll: widget.studentRoll,
      studentName: widget.studentName,
      classLevel: widget.classLevel,
    );
  }

  @override
  void dispose() {
    _totalFeesCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  double _calculatePaidFees(double totalFees, double remainingFees) {
    final paid = totalFees - remainingFees;
    return paid.clamp(0.0, totalFees);
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

    setState(() => _savingFees = true);
    try {
      await ref.read(erpRepositoryProvider).updateStudentFees(
            studentDocId: widget.studentDocId,
            totalFees: total,
            paidAmount: paid,
          );

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
      if (mounted) setState(() => _savingFees = false);
    }
  }

  Future<void> _generatePTMExcel() async {
    setState(() => _generatingExcel = true);
    try {
      final repo = ref.read(erpRepositoryProvider);
      final db = FirebaseFirestore.instance;

      // Get all test series for this class
      final seriesSnap = await db
          .collection('test_series')
          .where('classLevel', isEqualTo: widget.classLevel)
          .get();

      final subjects = <String>{};
      final studentMarks = <Map<String, dynamic>>[];

      for (final seriesDoc in seriesSnap.docs) {
        final subject = seriesDoc.data()['subject'] ?? 'General';
        subjects.add(subject);
      }

      // Get marks for all students
      final marksSnap = await db
          .collection('test_marks')
          .where('classLevel', isEqualTo: widget.classLevel)
          .get();

      final marksMap = <String, Map<String, double>>{};

      for (final marksDoc in marksSnap.docs) {
        final data = marksDoc.data();
        final subject = data['subject'] ?? 'General';
        final marks = data['marks'] as Map<String, dynamic>?;

        if (marks != null) {
          for (final entry in marks.entries) {
            final roll = entry.key;
            final mark = _parseDouble(entry.value);
            marksMap.putIfAbsent(roll, () => {});
            marksMap[roll]![subject] = mark;
          }
        }
      }

      // Get all students in class
      final students = await repo.fetchStudentsByClass(widget.classLevel);

      for (final student in students) {
        studentMarks.add({
          'roll': student.roll,
          'name': student.name,
          'marks': marksMap[student.roll] ?? {},
        });
      }

      final excelBytes = await ExcelReportGenerator.generatePTMReport(
        classLevel: 'Class ${widget.classLevel}',
        reportTitle: 'PTM Report - Test Series Marks',
        studentMarks: studentMarks,
        subjects: subjects.toList()..sort(),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'PTM_Report_Class_${widget.classLevel}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excelBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel file saved to: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStaff = user?.isStaff ?? false;

    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('This information is only available to staff.')),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('test_marks')
          .where('classLevel', isEqualTo: widget.classLevel)
          .snapshots(),
      builder: (context, marksSnapshot) {
        if (marksSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('classLevel', isEqualTo: widget.classLevel)
              .snapshots(),
          builder: (context, attendanceSnapshot) {
            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: const Text('Loading...')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            // Calculate performance stats
            double totalMarks = 0;
            int testCount = 0;
            double highestMarks = 0;
            double lowestMarks = double.maxFinite;

            if (marksSnapshot.hasData) {
              for (final doc in marksSnapshot.data!.docs) {
                final data = doc.data();
                if (data == null) continue;
                final marks = (data as Map<String, dynamic>)['marks'] as Map<String, dynamic>?;
                final studentMark = marks?[widget.studentRoll];
                if (studentMark != null) {
                  final mark = _parseDouble(studentMark);
                  totalMarks += mark;
                  testCount++;
                  highestMarks = mark > highestMarks ? mark : highestMarks;
                  lowestMarks = mark < lowestMarks ? mark : lowestMarks;
                }
              }
            }

            _performance.totalTestsGiven = testCount;
            _performance.averageMarks = testCount > 0 ? totalMarks / testCount : 0;
            _performance.highestMarks = highestMarks == double.maxFinite ? 0 : highestMarks;
            _performance.lowestMarks = lowestMarks == double.maxFinite ? 0 : lowestMarks;

            // Calculate attendance stats
            int presentDays = 0;
            int totalDays = 0;

            if (attendanceSnapshot.hasData) {
              for (final doc in attendanceSnapshot.data!.docs) {
                final data = doc.data();
                if (data != null) {
                  final records = (data as Map<String, dynamic>)['records'] as Map<String, dynamic>?;
                  if (records != null && records.containsKey(widget.studentRoll)) {
                    if (records[widget.studentRoll] == true) {
                      presentDays++;
                    }
                    totalDays++;
                  }
                }
              }
            }

            _performance.totalClassesAttended = presentDays;
            _performance.totalClassesHeld = totalDays;

            // Determine category based on class averages
            var classAverages = <double>[];
            if (marksSnapshot.hasData) {
              for (final doc in marksSnapshot.data!.docs) {
                final data = doc.data();
                if (data == null) continue;
                final marks = (data as Map<String, dynamic>)['marks'] as Map<String, dynamic>?;
                if (marks != null) {
                  double sum = 0;
                  for (final mark in marks.values) {
                    sum += _parseDouble(mark);
                  }
                  if (marks.length > 0) {
                    classAverages.add(sum / marks.length);
                  }
                }
              }
            }

            _performance.updateCategory(classAverages);

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .doc(widget.studentDocId)
                  .snapshots(),
              builder: (context, studentSnapshot) {
                double totalFees = 0;
                double remainingFees = 0;

                if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
                  final data = studentSnapshot.data!.data() as Map<String, dynamic>?;
                  totalFees = _parseDouble(data?['total_fees'] ?? 0);
                  remainingFees = _parseDouble(data?['remaining_fees'] ?? totalFees);
                  
                  _totalFeesCtrl.text = totalFees > 0 ? totalFees.toString() : '';
                  _paidCtrl.text = _calculatePaidFees(totalFees, remainingFees).toStringAsFixed(2);
                }

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      widget.studentName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Performance Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Performance ${_performance.category.emoji}',
                                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(_performance.category).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _getCategoryColor(_performance.category)),
                                      ),
                                      child: Text(
                                        _performance.category.label,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: _getCategoryColor(_performance.category),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildStatRow('Tests Given', _performance.totalTestsGiven.toString()),
                                _buildStatRow('Average Marks', _performance.averageMarks.toStringAsFixed(2)),
                                _buildStatRow('Highest Marks', _performance.highestMarks.toStringAsFixed(2)),
                                _buildStatRow('Lowest Marks', _performance.lowestMarks.toStringAsFixed(2)),
                                _buildStatRow('Attendance', '${_performance.totalClassesAttended}/${_performance.totalClassesHeld} (${_performance.attendancePercentage.toStringAsFixed(1)}%)'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Fees Management Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fees Management',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _totalFeesCtrl,
                                  decoration: const InputDecoration(labelText: 'Total Fees'),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _paidCtrl,
                                  decoration: const InputDecoration(labelText: 'Paid Amount'),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Pending: ₹${_calculatedPending.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _calculatedPending > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _savingFees ? null : _updateFees,
                                  child: _savingFees ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update Fees'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Excel Export Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generatingExcel ? null : _generatePTMExcel,
                            icon: _generatingExcel ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                            label: const Text('Generate PTM Excel Report'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14)),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(PerformanceCategory category) {
    switch (category) {
      case PerformanceCategory.topper:
        return Colors.green;
      case PerformanceCategory.average:
        return Colors.orange;
      case PerformanceCategory.needsImprovement:
        return Colors.red;
    }
  }
}