import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/syllabus_tracker_model.dart';

/// Simple and clean syllabus tracker for teachers - rebuilt from root with improved UI
class SimpleSyllabusTrackerTeacherScreen extends ConsumerStatefulWidget {
  const SimpleSyllabusTrackerTeacherScreen({super.key});

  @override
  ConsumerState<SimpleSyllabusTrackerTeacherScreen> createState() => _SimpleSyllabusTrackerTeacherScreenState();
}

class _SimpleSyllabusTrackerTeacherScreenState extends ConsumerState<SimpleSyllabusTrackerTeacherScreen> {
  int _selectedClass = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Syllabus Tracker', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Class Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
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
          ),
          // Syllabus Content
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('syllabus')
                  .doc('class_$_selectedClass')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading syllabus',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No syllabus data for Class $_selectedClass',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _initializeSyllabus(),
                          icon: const Icon(Icons.add),
                          label: const Text('Initialize Syllabus'),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) {
                  return const Center(child: Text('No syllabus data available'));
                }
                final syllabus = ClassSyllabus.fromFirestore(data, snapshot.data!.id);

                return _buildSyllabusContent(syllabus);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusContent(ClassSyllabus syllabus) {
    final subjectsList = syllabus.subjects.values.toList();

    if (subjectsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No subjects added yet',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Subject feature coming soon')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subjectsList.length,
      itemBuilder: (context, index) {
        final subject = subjectsList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subject.subjectName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getProgressColor(subject.progressPercentage).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${subject.progressPercentage.toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getProgressColor(subject.progressPercentage),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: subject.progressPercentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(subject.progressPercentage),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${subject.completedChapters}/${subject.totalChapters} chapters completed',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                // Chapters List
                if (subject.chapters.isEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  ...subject.chapters.asMap().entries.map((entry) {
                    final chapter = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Checkbox(
                            value: chapter.isCompleted,
                            onChanged: (_) => _toggleChapter(subject.subjectName, chapter),
                            activeColor: Colors.green,
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
                                    fontSize: 14,
                                    decoration: chapter.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (chapter.isCompleted && chapter.completedDate != null)
                                  Text(
                                    'Completed: ${_formatDate(chapter.completedDate!)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else
                  Center(
                    child: Text(
                      'No chapters added yet',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Add Chapter Button
                FilledButton.tonal(
                  onPressed: () => _addChapter(subject.subjectName),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('Add Chapter'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return AppTheme.deepBlue;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _initializeSyllabus() async {
    try {
      await ref.read(erpRepositoryProvider).getClassSyllabus(_selectedClass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Syllabus initialized')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addChapter(String subjectName) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Chapter feature coming soon')),
    );
  }

  void _toggleChapter(String subjectName, dynamic chapter) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Toggle Chapter feature coming soon')),
    );
  }
}
