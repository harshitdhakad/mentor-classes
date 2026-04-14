import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../models/syllabus_tracker_model.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Simple and clean syllabus tracker for students - rebuilt from root with improved UI
class SimpleSyllabusTrackerStudentScreen extends ConsumerWidget {
  const SimpleSyllabusTrackerStudentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null || !StudentClassLevels.isValid(user.studentClass)) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Syllabus Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.deepBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Syllabus progress requires your class on file',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(),
            ),
          ),
        ),
      );
    }

    final classLevel = user.studentClass!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Syllabus Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('syllabus')
            .doc('class_$classLevel')
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
                    'No syllabus data available for Class $classLevel',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
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
                          Icon(
                            chapter.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: chapter.isCompleted ? Colors.green : Colors.grey.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
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
                                    fontWeight: FontWeight.w500,
                                    decoration: chapter.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: chapter.isCompleted
                                        ? Colors.grey.shade600
                                        : Colors.black87,
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
                  }).toList(),
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
}
