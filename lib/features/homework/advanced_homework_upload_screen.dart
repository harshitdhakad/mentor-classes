import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/homework_model.dart';
import '../auth/auth_service.dart';

/// Advanced Teacher Homework Upload Screen
/// - Class selector (5-10)
/// - Subject selector (Maths, Science, SST, English)
/// - Text content input
class AdvancedHomeworkUploadScreen extends ConsumerStatefulWidget {
  const AdvancedHomeworkUploadScreen({super.key});

  @override
  ConsumerState<AdvancedHomeworkUploadScreen> createState() => _AdvancedHomeworkUploadScreenState();
}

class _AdvancedHomeworkUploadScreenState extends ConsumerState<AdvancedHomeworkUploadScreen> {
  int _selectedClass = 5;
  String _selectedSubject = 'Maths';
  final _textController = TextEditingController();
  bool _saving = false;
  bool _homeworkJustSaved = false;
  String? _lastSavedText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _copyHomeworkToClipboard() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('📚 HOMEWORK DETAILS');
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('Subject: $_selectedSubject');
      buffer.writeln('Class: $_selectedClass');
      buffer.writeln('═══════════════════════════════════════');
      
      if (_lastSavedText != null && _lastSavedText!.isNotEmpty) {
        buffer.writeln('📝 TEXT CONTENT:');
        buffer.writeln(_lastSavedText);
        buffer.writeln('═══════════════════════════════════════');
      }
      
      buffer.writeln('📅 Assigned: ${DateTime.now().toString()}');
      buffer.writeln('═══════════════════════════════════════');

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Homework copied to clipboard'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error copying: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Save homework (overwrites existing for same class+subject)
  Future<void> _saveHomework() async {
    final textContent = _textController.text.trim();
    final user = ref.read(authProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not authenticated')),
      );
      return;
    }

    if (textContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please add homework description'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Check-and-Create path initialization
      final db = FirebaseFirestore.instance;
      final homeworkRef = db.collection('homework')
          .doc(_selectedClass.toString())
          .collection('subjects')
          .doc(_selectedSubject)
          .collection('current');
      final currentDocRef = homeworkRef.doc('current');
      
      // Check if path exists, if not create dummy initialization
      final subjectDoc = await currentDocRef.get();
      if (!subjectDoc.exists) {
        await currentDocRef.set({
          'initialized': true,
          'classLevel': _selectedClass,
          'subject': _selectedSubject,
          'createdAt': DateTime.now(),
        });
      }

      // Save to Firestore without file attachments
      await ref.read(erpRepositoryProvider).saveHomeworkForClassAndSubject(
            classLevel: _selectedClass,
            subject: _selectedSubject,
            textContent: textContent,
            imageUrls: [],
            attachments: [],
            assignedBy: user.email ?? 'Unknown',
          );

      // Trigger global refresh to update all screens immediately
      ref.invalidate(refreshTriggerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Homework published successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Show copy to clipboard popup
        setState(() {
          _homeworkJustSaved = true;
          _lastSavedText = textContent;
        });

        // Auto-dismiss popup after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _homeworkJustSaved = false;
            });
          }
        });

        // Clear UI
        _textController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    
    // Authentication check
    if (user == null || !user.isStaff) {
      return const Center(
        child: Text(
          'Access Denied',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Upload Homework',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Publish homework for a class and subject. New homework overwrites previous.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

          // CLASS SELECTOR
          Text(
            'Select Class',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedClass,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.school),
            ),
            items: HomeworkConstants.classLevels
                .map((c) => DropdownMenuItem(value: c, child: Text('Class $c')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedClass = value);
            },
          ),
          const SizedBox(height: 16),

          // SUBJECT SELECTOR
          Text(
            'Select Subject',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.subject),
            ),
            items: HomeworkConstants.subjects
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedSubject = value);
            },
          ),
          const SizedBox(height: 20),

          // TEXT CONTENT
          Text(
            'Homework Description',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter homework text, instructions, or notes...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // PUBLISH BUTTON
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveHomework,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Publish Homework',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Publishing replaces the previous homework for this class and subject.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomSheet: _homeworkJustSaved
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.green.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Homework Published!',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'Copy to clipboard to share with students',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _copyHomeworkToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          )
        : null,
    );
  }
}
