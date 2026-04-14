import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('syllabus')
            .doc(classLevel.toString())
            .collection('subjects')
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          final subjects = snapshot.data!.docs;
          return _buildSyllabusContent(subjects, classLevel);
        },
      ),
    );
  }

  Widget _buildSyllabusContent(List<QueryDocumentSnapshot> subjects, int classLevel) {
    if (subjects.isEmpty) {
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
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subjectDoc = subjects[index];
        final subjectName = subjectDoc.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('syllabus')
                  .doc(classLevel.toString())
                  .collection('subjects')
                  .doc(subjectName)
                  .collection('chapters')
                  .orderBy('addedAt')
                  .snapshots(),
              builder: (context, chaptersSnapshot) {
                if (chaptersSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                final chapters = chaptersSnapshot.data?.docs ?? [];
                final completedCount = chapters.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['completed'] == true;
                }).length;
                final totalChapters = chapters.length;
                final progress = totalChapters > 0 ? (completedCount / totalChapters) * 100 : 0.0;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subjectName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getProgressColor(progress).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${progress.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getProgressColor(progress),
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
                        value: progress / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(progress),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completedCount/$totalChapters chapters completed',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    // Chapters List
                    if (chapters.isEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'No chapters added yet',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ] else ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      ...chapters.map((chapterDoc) {
                        final chapterData = chapterDoc.data() as Map<String, dynamic>;
                        final chapterName = chapterData['chapterName'] as String? ?? 'Unknown';
                        final isCompleted = chapterData['completed'] as bool? ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isCompleted ? Colors.green : Colors.grey.shade400,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chapterName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted
                                        ? Colors.grey.shade500
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}
