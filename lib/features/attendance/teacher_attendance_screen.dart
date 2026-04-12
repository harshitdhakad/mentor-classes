import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  int _classLevel = 8;
  DateTime _date = DateTime.now();
  bool _isHoliday = false;
  final _holidayMsg = TextEditingController();
  final Map<String, bool> _present = {};
  bool _saving = false;
  bool _attendanceJustSaved = false;

  @override
  void dispose() {
    _holidayMsg.dispose();
    super.dispose();
  }

  Future<void> _cleanupOldHomework() async {
    debugPrint('🧹 Starting auto-delete homework cleanup...');
    
    try {
      // Fetch ALL homework documents from Firestore
      final homeworkSnapshot = await FirebaseFirestore.instance
          .collection('homework')
          .get();
      
      debugPrint('📊 Found ${homeworkSnapshot.docs.length} homework documents');
      
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      debugPrint('📅 Today\'s date: $todayStr');
      
      int deletedCount = 0;
      int failedCount = 0;
      
      for (final doc in homeworkSnapshot.docs) {
        final data = doc.data();
        final uploadDate = data['uploadDate'] as String?;
        final fileUrl = data['fileUrl'] as String?;
        
        if (uploadDate == null || fileUrl == null) {
          debugPrint('⚠️ Skipping document ${doc.id} - missing uploadDate or fileUrl');
          continue;
        }
        
        // Check if uploadDate is NOT today
        if (uploadDate != todayStr) {
          debugPrint('🗑️ Old homework found - uploadDate: $uploadDate, fileUrl: $fileUrl');
          
          try {
            // Delete file from Firebase Storage
            final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
            await storageRef.delete();
            debugPrint('✅ Deleted file from Storage: ${doc.id}');
            
            // Delete document from Firestore
            await doc.reference.delete();
            debugPrint('✅ Deleted document from Firestore: ${doc.id}');
            
            deletedCount++;
          } catch (e) {
            debugPrint('❌ Failed to delete ${doc.id}: $e');
            failedCount++;
          }
        }
      }
      
      debugPrint('🧹 Cleanup complete - Deleted: $deletedCount, Failed: $failedCount');
    } catch (e) {
      debugPrint('❌ Cleanup failed with error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
    }
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isStaff || user.email == null) return;

    setState(() => _saving = true);
    try {
      // STEP 1: Trigger auto-delete homework cleanup
      await _cleanupOldHomework();
      
      // STEP 2: Save attendance
      await ref.read(erpRepositoryProvider).saveAttendance(
            classLevel: _classLevel,
            date: DateTime(_date.year, _date.month, _date.day),
            isHoliday: _isHoliday,
            holidayMessage: _holidayMsg.text.trim().isEmpty ? null : _holidayMsg.text.trim(),
            presentByRoll: Map<String, bool>.from(_present),
            savedByEmail: user.email!,
          );
      
      // Update current homework date if different
      final currentHomeworkDate = ref.read(currentHomeworkDateProvider);
      if (!DateUtils.isSameDay(currentHomeworkDate, _date)) {
        ref.read(currentHomeworkDateProvider.notifier).setDate(_date);
      }
      
      if (mounted) {
        setState(() => _attendanceJustSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved. Old homework cleaned up.')),
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

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: ''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Text copied to clipboard'),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                  Text('Class & date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue)),
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
                              setState(() => _date = picked);
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
                    onChanged: (v) => setState(() => _isHoliday = v),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .where('classLevel', isEqualTo: _classLevel)
                .snapshots(),
            builder: (context, snapshot) {
              try {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Text('Loading...'));
                }
                if (snapshot.hasError) {
                  debugPrint('Teacher attendance error: ${snapshot.error}');
                  return const Center(child: Text('Error loading students'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students in Class $_classLevel. Upload via Excel first.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey.shade700),
                    ),
                  );
                }

                final students = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return StudentListItem(
                    docId: doc.id,
                    roll: data['roll']?.toString() ?? '',
                    name: data['name']?.toString() ?? 'Unknown',
                  );
                }).toList();

                // Initialize present map if empty
                if (_present.isEmpty) {
                  for (final s in students) {
                    _present[s.roll] = true;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .where('classLevel', isEqualTo: _classLevel)
                      .where('date', isEqualTo: DateTime(_date.year, _date.month, _date.day).toString().split(' ')[0])
                      .snapshots(),
                  builder: (context, attendanceSnapshot) {
                    try {
                      if (attendanceSnapshot.hasData && attendanceSnapshot.data!.docs.isNotEmpty) {
                        final existing = attendanceSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        if (existing['isHoliday'] == true) {
                          _isHoliday = true;
                          _holidayMsg.text = (existing['holidayMessage'] ?? '').toString();
                        } else if (existing['records'] is Map) {
                          final r = Map<String, dynamic>.from(existing['records'] as Map);
                          for (final s in students) {
                            _present[s.roll] = r[s.roll] == true;
                          }
                        }
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
                                final present = _present[s.roll] ?? true;
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
                                            studentRoll: s.roll,
                                          ),
                                        ),
                                      );
                                    },
                                    child: SwitchListTile(
                                      title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                      subtitle: Text('Roll ${s.roll}', style: GoogleFonts.poppins(fontSize: 13)),
                                      value: present,
                                      activeThumbColor: Colors.green.shade700,
                                      inactiveThumbColor: Colors.red.shade300,
                                      onChanged: (v) => setState(() => _present[s.roll] = v),
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
              } catch (e) {
                debugPrint('Teacher attendance widget error: $e');
                return const Center(child: Text('Error loading students'));
              }
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
