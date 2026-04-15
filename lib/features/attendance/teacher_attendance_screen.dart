import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../data/erp_repository.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';
import '../student/student_detail_screen.dart';

/// Teacher/Admin: mark attendance by class with holiday option and mark-all-present.
class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends ConsumerState<TeacherAttendanceScreen> {
  int _classLevel = 5;
  DateTime _date = DateTime.now();
  bool _isHoliday = false;
  final _holidayMsg = TextEditingController();
  final Map<String, bool> _present = {};
  bool _saving = false;
  bool _attendanceJustSaved = false;
  bool _isEditMode = false;
  bool _attendanceExists = false;

  @override
  void dispose() {
    _holidayMsg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isStaff || user.email == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(erpRepositoryProvider).saveAttendance(
            classLevel: _classLevel,
            date: DateTime(_date.year, _date.month, _date.day),
            isHoliday: _isHoliday,
            holidayMessage: _holidayMsg.text.trim().isEmpty ? null : _holidayMsg.text.trim(),
            presentByRoll: Map<String, bool>.from(_present),
            savedByEmail: user.email!,
          );

      if (mounted) {
        setState(() {
          _attendanceJustSaved = true;
          _attendanceExists = true;
          _isEditMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Attendance saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleEditMode() {
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<void> _copyToClipboard() async {
    try {
      final presentStudents = _present.entries.where((e) => e.value).map((e) => e.key).toList();
      final absentStudents = _present.entries.where((e) => !e.value).map((e) => e.key).toList();
      final dateStr = DateFormat('dd-MM-yyyy').format(_date);
      final text = '''Attendance Report - Class $_classLevel
Date: $dateStr
Present: ${presentStudents.length}
Absent: ${absentStudents.length}

Present Rolls: ${presentStudents.join(', ')}
Absent Rolls: ${absentStudents.join(', ')}''';

      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Attendance copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Class & date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue)),
                      if (_attendanceExists && !_isEditMode)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ Attendance Done',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _toggleEditMode,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: Text('Edit', style: GoogleFonts.poppins(fontSize: 12)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _classLevel,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            for (var c = StudentClassLevels.min; c <= StudentClassLevels.max; c++)
                              DropdownMenuItem(value: c, child: Text('Class $c')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _classLevel = v;
                              _present.clear();
                              _isHoliday = false;
                              _holidayMsg.clear();
                              _attendanceExists = false;
                              _isEditMode = false;
                              _attendanceJustSaved = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() {
                                _date = picked;
                                _attendanceExists = false;
                                _isEditMode = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(df.format(_date), style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Mark as holiday', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      'Whole day off — no per-student marks.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    value: _isHoliday,
                    activeThumbColor: AppTheme.deepBlue,
                    onChanged: _attendanceExists && !_isEditMode ? null : (v) => setState(() => _isHoliday = v),
                  ),
                  if (_isHoliday)
                    TextField(
                      controller: _holidayMsg,
                      decoration: const InputDecoration(
                        labelText: 'Message (e.g. Rain holiday)',
                        hintText: 'Due to rain, class is suspended today.',
                      ),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ref.watch(studentsByClassEnhancedProvider(_classLevel)).when(
            data: (students) {
              debugPrint('📊 Teacher attendance: Found ${students.length} students for class $_classLevel');

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No students found for Class $_classLevel.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please ensure students are registered in the system.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Initialize present map if empty
              if (_present.isEmpty) {
                for (final s in students) {
                  _present[s.rollNumber.toString()] = true;
                }
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .doc('$_classLevel-${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}')
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  try {
                    // CRITICAL: Check waiting state FIRST
                    if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    // Check error state AFTER waiting
                    if (attendanceSnapshot.hasError) {
                      debugPrint('Attendance records error: ${attendanceSnapshot.error}');
                      return const SizedBox.shrink();
                    }
                    // Check empty data AFTER error
                    if (attendanceSnapshot.hasData && attendanceSnapshot.data!.exists) {
                      final existing = attendanceSnapshot.data!.data() as Map<String, dynamic>;
                      setState(() => _attendanceExists = true);
                      if (existing['isHoliday'] == true) {
                        _isHoliday = true;
                        _holidayMsg.text = (existing['holidayMessage'] ?? '').toString();
                      } else if (existing['records'] is Map) {
                        final r = Map<String, dynamic>.from(existing['records'] as Map);
                        for (final s in students) {
                          _present[s.rollNumber.toString()] = r[s.rollNumber.toString()] == true;
                        }
                      }
                    } else {
                      setState(() => _attendanceExists = false);
                    }
                  } catch (e) {
                    debugPrint('Error loading existing attendance: $e');
                  }

                  return _isHoliday
                      ? Center(
                          child: Text(
                            'Holiday mode — save to notify parents & post notice.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.grey.shade700),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: students.length,
                          itemBuilder: (context, i) {
                            try {
                              final s = students[i];
                              final present = _present[s.rollNumber.toString()] ?? true;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => StudentDetailScreen(
                                          studentDocId: s.docId,
                                          studentName: s.name,
                                          studentRoll: s.rollNumber.toString(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: SwitchListTile(
                                    title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                    subtitle: Text('Roll ${s.rollNumber}', style: GoogleFonts.poppins(fontSize: 13)),
                                    value: present,
                                    activeThumbColor: Colors.green.shade700,
                                    inactiveThumbColor: Colors.red.shade300,
                                    onChanged: _attendanceExists && !_isEditMode ? null : (v) => setState(() => _present[s.rollNumber.toString()] = v),
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error rendering student item: $e');
                              return const SizedBox.shrink();
                            }
                          },
                        );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) {
              debugPrint('❌ Teacher attendance error: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading list: $error',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Save attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
              if (_attendanceJustSaved) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Clipboard'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
