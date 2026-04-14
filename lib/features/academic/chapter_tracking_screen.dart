import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

class ChapterTrackingScreen extends ConsumerStatefulWidget {
  const ChapterTrackingScreen({super.key});

  @override
  ConsumerState<ChapterTrackingScreen> createState() =>
      _ChapterTrackingScreenState();
}

class _ChapterTrackingScreenState
    extends ConsumerState<ChapterTrackingScreen> {
  final _chapterController = TextEditingController();
  String _selectedSubject = 'Civics';
  int _selectedClass = 8;

  final List<String> _subjects = [
    'Civics',
    'History',
    'Economics',
    'Geography',
    'Science',
    'Maths',
    'English',
  ];

  @override
  void dispose() {
    _chapterController.dispose();
    super.dispose();
  }

  Future<void> _addChapter() async {
    if (_chapterController.text.trim().isEmpty) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      // Ensure the class document exists
      final classDocRef = FirebaseFirestore.instance
          .collection('syllabus')
          .doc(_selectedClass.toString());
      
      final classDoc = await classDocRef.get();
      if (!classDoc.exists) {
        await classDocRef.set({
          'classLevel': _selectedClass,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Ensure the subject document exists
      final subjectDocRef = classDocRef.collection('subjects').doc(_selectedSubject);
      
      final subjectDoc = await subjectDocRef.get();
      if (!subjectDoc.exists) {
        await subjectDocRef.set({
          'subjectName': _selectedSubject,
          'classLevel': _selectedClass,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Add chapter to the chapters subcollection
      await subjectDocRef.collection('chapters').add({
        'classLevel': _selectedClass,
        'subject': _selectedSubject,
        'chapterName': _chapterController.text.trim(),
        'completed': false,
        'addedBy': user.email ?? 'Unknown',
        'addedAt': FieldValue.serverTimestamp(),
      });

      _chapterController.clear();
      
      // Trigger global refresh to update all screens immediately
      ref.invalidate(refreshTriggerProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding chapter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding chapter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleChapter(String docId, bool currentValue) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (user.role.name == 'student') return;

    try {
      await FirebaseFirestore.instance
          .collection('syllabus')
          .doc(_selectedClass.toString())
          .collection('subjects')
          .doc(_selectedSubject)
          .collection('chapters')
          .doc(docId)
          .update({'completed': !currentValue});
      
      // Trigger global refresh to update all screens immediately
      ref.invalidate(refreshTriggerProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentValue ? 'Chapter marked as completed' : 'Chapter marked as incomplete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling chapter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating chapter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteChapter(String docId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (user.role.name == 'student') return;

    try {
      await FirebaseFirestore.instance
          .collection('syllabus')
          .doc(_selectedClass.toString())
          .collection('subjects')
          .doc(_selectedSubject)
          .collection('chapters')
          .doc(docId)
          .delete();
      
      // Trigger global refresh to update all screens immediately
      ref.invalidate(refreshTriggerProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting chapter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chapter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';
    
    // For students, use their class; for teachers, use selected class
    final displayClass = isStudent ? user?.studentClass : _selectedClass;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chapter Progress',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Class Selector (Teachers only)
          if (!isStudent)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
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
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClass,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      for (var c = StudentClassLevels.min; c <= StudentClassLevels.max; c++)
                        DropdownMenuItem(value: c, child: Text('Class $c')),
                    ],
                    onChanged: (v) => setState(() => _selectedClass = v ?? 8),
                  ),
                ],
              ),
            ),

          // Subject Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Subject',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subjects.map((subject) {
                    final isSelected = _selectedSubject == subject;
                    return FilterChip(
                      label: Text(subject),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedSubject = subject);
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: AppTheme.deepBlue.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.deepBlue : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Add Chapter Section (Teachers/Admins only)
          if (!isStudent)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Chapter',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chapterController,
                          decoration: InputDecoration(
                            hintText: 'Enter chapter name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: AppTheme.deepBlue,
                        onPressed: _addChapter,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Chapters List
          Expanded(
            child: displayClass == null
                ? const Center(child: Text('No class selected'))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('syllabus')
                  .doc(displayClass.toString())
                  .collection('subjects')
                  .doc(_selectedSubject)
                  .collection('chapters')
                  .orderBy('addedAt')
                  .snapshots(),
              builder: (context, snapshot) {
                try {
                  // CRITICAL: Check waiting state FIRST
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Check error state AFTER waiting
                  if (snapshot.hasError) {
                    debugPrint('Chapter tracking error: ${snapshot.error}');
                    return const Center(child: Text('Syncing data...'));
                  }
                  // Check empty data AFTER error AND only if ConnectionState is active
                  if (snapshot.connectionState == ConnectionState.active &&
                      (!snapshot.hasData || snapshot.data!.docs.isEmpty)) {
                    return Center(
                      child: Text(
                        isStudent
                            ? 'No data available for this class.'
                            : 'No data available for this class.',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  final chapters = snapshot.data!.docs;

                  final completedCount = chapters
                      .where((doc) {
                        try {
                          return (doc.data() as Map)['completed'] == true;
                        } catch (e) {
                          debugPrint('Error checking chapter completion: $e');
                          return false;
                        }
                      })
                      .length;

                  final progress = completedCount / chapters.length;

                  return Column(
                    children: [
                      // Progress Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.deepBlue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chapters List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: chapters.length,
                          itemBuilder: (context, index) {
                            try {
                              final doc = chapters[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final chapterName = data['chapterName'] as String? ?? '';
                              final completed = data['completed'] as bool? ?? false;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: completed,
                                    onChanged: isStudent
                                        ? null
                                        : (_) => _toggleChapter(doc.id, completed),
                                  ),
                                  title: Text(
                                    chapterName,
                                    style: GoogleFonts.poppins(
                                      decoration:
                                          completed ? TextDecoration.lineThrough : null,
                                      color: completed ? Colors.grey : null,
                                    ),
                                  ),
                                  trailing: !isStudent
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent),
                                          onPressed: () => _deleteChapter(doc.id),
                                        )
                                      : null,
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error rendering chapter item: $e');
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ],
                  );
                } catch (e) {
                  debugPrint('Chapter tracking widget error: $e');
                  return const Center(child: Text('Error loading chapters'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
