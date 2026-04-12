import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/syllabus_tracker_model.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Teacher only: manage syllabus by selecting chapters for core subjects
class SyllabusTrackerTeacherScreen extends ConsumerStatefulWidget {
  const SyllabusTrackerTeacherScreen({super.key});

  @override
  ConsumerState<SyllabusTrackerTeacherScreen> createState() => _SyllabusTrackerTeacherScreenState();
}

class _SyllabusTrackerTeacherScreenState extends ConsumerState<SyllabusTrackerTeacherScreen> {
  int _selectedClass = 5;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addChapter(String subjectName) async {
    final titleController = TextEditingController();
    final chapterNumController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Chapter - $subjectName', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: chapterNumController,
              decoration: const InputDecoration(
                labelText: 'Chapter Number',
                hintText: 'e.g., 1, 2, 3',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Chapter Title',
                hintText: 'e.g., Introduction to Photosynthesis',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter chapter title')),
                );
                return;
              }

              try {
                await ref.read(erpRepositoryProvider).addChapterToSyllabus(
                      classLevel: _selectedClass,
                      subjectName: subjectName,
                      title: titleController.text.trim(),
                      chapterNumber: int.tryParse(chapterNumController.text),
                    );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Chapter added to $subjectName')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleChapterCompletion(
    String subjectName,
    SyllabusChapter chapter,
  ) async {
    try {
      await ref.read(erpRepositoryProvider).toggleChapterCompletion(
            classLevel: _selectedClass,
            subjectName: subjectName,
            chapterId: chapter.id,
            isCompleted: !chapter.isCompleted,
          );
          } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _removeChapter(String subjectName, String chapterId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Chapter?'),
        content: const Text('This will remove the chapter permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(erpRepositoryProvider).removeChapterFromSyllabus(
            classLevel: _selectedClass,
            subjectName: subjectName,
            chapterId: chapterId,
          );
            ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Chapter removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null || !user.isStaff) {
      return Center(
        child: Text('Teachers only', style: GoogleFonts.poppins()),
      );
    }

    return Column(
      children: [
        // Class Selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Class',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClass,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: List.generate(
                      StudentClassLevels.max - StudentClassLevels.min + 1,
                      (i) => DropdownMenuItem(
                        value: StudentClassLevels.min + i,
                        child: Text('Class ${StudentClassLevels.min + i}'),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedClass = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Subjects List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('syllabus')
                .where('classLevel', isEqualTo: _selectedClass)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Text('Loading...'));
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading syllabus'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No syllabus data for Class $_selectedClass',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }

              final doc = snapshot.data!.docs.first;
              final data = doc.data() as Map<String, dynamic>;
              final syllabus = ClassSyllabus.fromFirestore(data, doc.id);

              final coreSubjects = syllabus.getAllCoreSubjects();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: coreSubjects.length,
                itemBuilder: (context, index) {
                  final subjectName = coreSubjects.keys.elementAt(index);
                  final subject = coreSubjects[subjectName]!;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subjectName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppTheme.deepBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${subject.completedChapters}/${subject.totalChapters} chapters completed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _addChapter(subjectName),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                              ),
                            ],
                          ),

                          // Progress Bar
                          if (subject.totalChapters > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: subject.progressPercentage / 100,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(
                                  subject.progressPercentage >= 75
                                      ? Colors.green
                                      : subject.progressPercentage >= 50
                                          ? Colors.orange
                                          : Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${subject.progressPercentage.toStringAsFixed(1)}% complete',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],

                          // Chapters List
                          if (subject.chapters.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            ...subject.chapters.asMap().entries.map(
                              (entry) {
                                final chapter = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: chapter.isCompleted,
                                        onChanged: (_) =>
                                            _toggleChapterCompletion(subjectName, chapter),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chapter.chapterNumber != null
                                                  ? 'Ch ${chapter.chapterNumber}: ${chapter.title}'
                                                  : chapter.title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                decoration: chapter.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            if (chapter.isCompleted && chapter.completedDate != null)
                                              Text(
                                                'Completed ${chapter.completedDate!.toLocal().toString().split(' ')[0]}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.green,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        onPressed: () =>
                                            _removeChapter(subjectName, chapter.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No chapters added yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
