import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
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
  bool _isAdding = false;

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

    final selectedClass = ref.read(selectedClassProvider);

    await FirebaseFirestore.instance
        .collection('chapters')
        .add({
      'classLevel': selectedClass,
      'subject': _selectedSubject,
      'chapterName': _chapterController.text.trim(),
      'completed': false,
      'addedBy': user.email ?? 'Unknown',
      'addedAt': FieldValue.serverTimestamp(),
    });

    _chapterController.clear();
    setState(() => _isAdding = false);
  }

  Future<void> _toggleChapter(String docId, bool currentValue) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (user.role.name == 'student') return;

    await FirebaseFirestore.instance
        .collection('chapters')
        .doc(docId)
        .update({'completed': !currentValue});
  }

  Future<void> _deleteChapter(String docId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (user.role.name == 'student') return;

    await FirebaseFirestore.instance.collection('chapters').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';
    final selectedClass = ref.watch(selectedClassProvider);

    return Scaffold(
      body: Column(
        children: [
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
                      selectedColor: AppTheme.deepBlue.withOpacity(0.2),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chapters')
                  .where('classLevel', isEqualTo: selectedClass)
                  .where('subject', isEqualTo: _selectedSubject)
                  .orderBy('addedAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text('Loading chapters...'));
                }

                final chapters = snapshot.data!.docs;

                if (chapters.isEmpty) {
                  return Center(
                    child: Text(
                      isStudent
                          ? 'No chapters added yet for $_selectedSubject'
                          : 'No chapters added yet. Add chapters to track progress.',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  );
                }

                final completedCount = chapters
                    .where((doc) => (doc.data() as Map)['completed'] == true)
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
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
