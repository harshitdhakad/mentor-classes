import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../auth/auth_service.dart';

/// Enhanced marks upload screen with class and test type selection
class EnhancedMarksUploadScreen extends ConsumerStatefulWidget {
  const EnhancedMarksUploadScreen({super.key});

  @override
  ConsumerState<EnhancedMarksUploadScreen> createState() =>
      _EnhancedMarksUploadScreenState();
}

class _EnhancedMarksUploadScreenState
    extends ConsumerState<EnhancedMarksUploadScreen> {
  late TextEditingController _testNameController;
  late TextEditingController _maxMarksController;
  late TextEditingController _subjectController;
  late TextEditingController _topicController;
  late TextEditingController _seriesIdController;

  int _selectedClass = 5;
  String _selectedTestType = 'weekly';
  final List<String> _testTypes = ['weekly', 'monthly', 'series'];
  
  // Test series specific
  final List<String> _subjects = ['Maths', 'Science', 'English', 'SST'];
  int _currentSubjectIndex = 0;
  final Map<String, Map<String, Map<String, dynamic>>> _seriesMarksBySubject = {}; // subject -> {roll -> {marks, ng}}

  final Map<String, Map<String, dynamic>> _studentMarks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testNameController = TextEditingController();
    _maxMarksController = TextEditingController(text: '100');
    _subjectController = TextEditingController();
    _topicController = TextEditingController();
    _seriesIdController = TextEditingController();
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _maxMarksController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _seriesIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    // Prevent students from accessing this screen
    if (user?.role.name == 'student') {
      return const Scaffold(
        body: Center(child: Text('Access Denied: This section is for staff only')),
      );
    }

    // Watch students for selected class
    final studentsAsync = ref.watch(studentsByClassEnhancedProvider(_selectedClass));

    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Upload Marks'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBluePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class & Test Type Selection
            Text(
              'Test Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            
            // Class Selector
            MentorGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Class *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
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
                              setState(() {
                                _selectedClass = classNum;
                                _studentMarks.clear();
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.deepBluePrimary,
                            labelStyle: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Test Type Selector
            MentorGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Type *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _testTypes.map((type) {
                      final isSelected = _selectedTestType == type;
                      final displayName = type == 'weekly'
                          ? ' Weekly'
                          : type == 'monthly'
                              ? ' Monthly'
                              : type == 'series'
                                  ? ' Series'
                                  : ' Term';
                      return FilterChip(
                        label: Text(displayName),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedTestType = type),
                        backgroundColor: Colors.grey[100],
                        selectedColor: AppTheme.deepBluePrimary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.deepBluePrimary
                              : Colors.grey[700],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Test Name
            MentorGlassCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _testNameController,
                decoration: InputDecoration(
                  labelText: 'Test Name *',
                  hintText: 'e.g., Chapter 5 Quiz',
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
            const SizedBox(height: 12),

            // Max Marks & Subject
            Row(
              children: [
                Expanded(
                  child: MentorGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _maxMarksController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max Marks',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MentorGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject',
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
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Topic
            MentorGlassCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: 'Topic/Syllabus',
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
            const SizedBox(height: 12),

            // Series ID (only for test series)
            if (_selectedTestType == 'series')
              MentorGlassCard(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _seriesIdController,
                  decoration: InputDecoration(
                    labelText: 'Series ID *',
                    hintText: 'e.g., Series-2024-Q1',
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
            if (_selectedTestType == 'series') const SizedBox(height: 12),

            // Subject Selector (only for test series)
            if (_selectedTestType == 'series')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Series Progress',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  // Subject progress indicator
                  Row(
                    children: List.generate(_subjects.length, (index) {
                      final subject = _subjects[index];
                      final isCompleted = index < _currentSubjectIndex;
                      final isCurrent = index == _currentSubjectIndex;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: index < _subjects.length - 1 ? 4 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green
                                : isCurrent
                                    ? AppTheme.deepBluePrimary
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                isCompleted ? '✓' : '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Subject: ${_subjects[_currentSubjectIndex]}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBluePrimary,
                    ),
                  ),
                ],
              ),
            if (_selectedTestType == 'series') const SizedBox(height: 24),

            // Students Marks Entry
            Text(
              _selectedTestType == 'series'
                  ? '${_subjects[_currentSubjectIndex]} Marks'
                  : 'Student Marks',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'No students in Class $_selectedClass',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _buildStudentMarkInput(student);
                  },
                );
              },
              loading: () => const Center(child: Text('Loading students...')),
              error: (err, stack) => Center(
                child: Text('Error loading students. Please try again.'),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadMarks,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading 
                    ? 'Saving...' 
                    : _selectedTestType == 'series'
                        ? (_currentSubjectIndex == _subjects.length - 1
                            ? 'Save Test Series'
                            : 'Save ${_subjects[_currentSubjectIndex]} Marks')
                        : 'Save Marks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepBluePrimary,
                  disabledBackgroundColor: Colors.grey[400],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Edit Existing Marks Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _showEditMarksDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Existing Marks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.deepBluePrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditMarksDialog() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('test_marks')
        .where('classLevel', isEqualTo: _selectedClass)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    if (!mounted) return;

    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No test marks found for this class')),
      );
      return;
    }

    final selectedTest = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Test to Edit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.docs[index].data();
              return ListTile(
                title: Text(data['testName'] ?? 'Unknown'),
                subtitle: Text('${data['subject']} - ${data['date']}'),
                onTap: () => Navigator.pop(context, data),
              );
            },
          ),
        ),
      ),
    );

    if (selectedTest != null) {
      await _editMarks(selectedTest);
    }
  }

  Future<void> _editMarks(Map<String, dynamic> testData) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('test_marks')
        .where('testName', isEqualTo: testData['testName'])
        .where('classLevel', isEqualTo: testData['classLevel'])
        .where('date', isEqualTo: testData['date'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    final doc = snapshot.docs.first;
    final marksByRoll = doc.data()['marksByRoll'] as Map<String, dynamic>?;
    final notGivenRolls = (doc.data()['notGivenRolls'] as List<dynamic>?)?.cast<String>() ?? [];

    if (!mounted) return;

    final students = await ref.read(studentsByClassEnhancedProvider(_selectedClass).future);
    final editMarks = <String, TextEditingController>{};
    final editNg = <String, bool>{};

    for (final student in students) {
      final roll = student.rollNumber.toString();
      editMarks[roll] = TextEditingController(text: marksByRoll?[roll]?.toString() ?? '');
      editNg[roll] = notGivenRolls.contains(roll);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Marks: ${testData['testName']}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final roll = student.rollNumber.toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('${student.name} (${student.rollNumber})'),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: editMarks[roll],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Marks',
                            isDense: true,
                          ),
                          enabled: !editNg[roll]!,
                        ),
                      ),
                      Checkbox(
                        value: editNg[roll],
                        onChanged: (v) {
                          setDialogState(() {
                            editNg[roll] = v ?? false;
                            if (v == true) editMarks[roll]!.clear();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final newMarksByRoll = <String, double>{};
      final newNotGivenRolls = <String>[];

      for (final student in students) {
        final roll = student.rollNumber.toString();
        if (editNg[roll]!) {
          newNotGivenRolls.add(roll);
        } else {
          final mark = double.tryParse(editMarks[roll]!.text);
          if (mark != null) newMarksByRoll[roll] = mark;
        }
      }

      await doc.reference.update({
        'marksByRoll': newMarksByRoll,
        'notGivenRolls': newNotGivenRolls,
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marks updated successfully')),
        );
      }

      for (final controller in editMarks.values) {
        controller.dispose();
      }
    }
  }

  Widget _buildStudentMarkInput(dynamic student) {
    final markController = TextEditingController(
      text: _studentMarks[student.rollNumber]?['marks']?.toString() ?? '',
    );

    final isNg = (_studentMarks[student.rollNumber]?['ng'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: MentorGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Student Info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Roll: ${student.rollNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Mark Input
          Expanded(
            flex: 1,
            child: TextField(
              controller: markController,
              keyboardType: TextInputType.number,
              enabled: !isNg,
              decoration: InputDecoration(
                hintText: 'Marks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                filled: isNg,
                fillColor: Colors.grey[200],
              ),
              inputFormatters: [
                // Allow only integers
              ],
              onChanged: (value) {
                setState(() {
                  _studentMarks[student.rollNumber] = {
                    'marks': int.tryParse(value) ?? 0,
                    'ng': false,
                  };
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // NG Toggle Button (more prominent)
          GestureDetector(
            onTap: () {
              setState(() {
                final current = _studentMarks[student.rollNumber] ?? {'marks': 0, 'ng': false};
                _studentMarks[student.rollNumber] = {
                  'marks': current['marks'] as double? ?? 0,
                  'ng': !(current['ng'] as bool? ?? false),
                };
                if (!isNg) {
                  markController.clear();
                }
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: isNg
                    ? LinearGradient(
                        colors: [Colors.orange.shade400, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border.all(
                  color: isNg ? Colors.orange : Colors.grey[300]!,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isNg ? null : Colors.grey[100],
                boxShadow: isNg
                    ? [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isNg ? Icons.close_rounded : Icons.check_circle_rounded,
                    color: isNg ? Colors.white : Colors.grey[500],
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNg ? 'NG' : 'Give',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isNg ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _uploadMarks() async {
    if (_testNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter test name')),
      );
      return;
    }

    if (_selectedTestType == 'series' && _seriesIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Series ID')),
      );
      return;
    }

    if (_studentMarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter marks for at least one student')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(erpRepositoryProvider);
      final maxMarks = int.tryParse(_maxMarksController.text) ?? 100;

      // Validate marks against maxMarks
      for (final entry in _studentMarks.entries) {
        final data = entry.value;
        final isNg = (data['ng'] as bool?) ?? false;
        if (!isNg) {
          final marks = (data['marks'] as int?) ?? 0;
          if (marks > maxMarks) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Error: Marks for student ${entry.key} ($marks) cannot exceed Max Marks ($maxMarks)'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      // Prepare data
      final marksByRoll = <String, double>{};
      final percentageByRoll = <String, double>{};
      final notGivenRolls = <String>[];

      for (final entry in _studentMarks.entries) {
        final roll = entry.key;
        final data = entry.value;
        final isNg = (data['ng'] as bool?) ?? false;

        if (isNg) {
          notGivenRolls.add(roll);
        } else {
          final marks = (data['marks'] as int?) ?? 0;
          marksByRoll[roll] = marks.toDouble();
          final percentage = (marks / maxMarks) * 100;
          percentageByRoll[roll] = percentage;
        }
      }

      // Calculate ranks
      final ranksByRoll = <String, int>{};
      if (percentageByRoll.isNotEmpty) {
        final sorted = percentageByRoll.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (int i = 0; i < sorted.length; i++) {
          ranksByRoll[sorted[i].key] = i + 1;
        }
      }

      // Handle test series flow
      if (_selectedTestType == 'series') {
        final currentSubject = _subjects[_currentSubjectIndex];
        
        // Save current subject marks to series data
        _seriesMarksBySubject[currentSubject] = {
          for (final entry in _studentMarks.entries)
            entry.key: {
              'marks': (entry.value['marks'] as int?) ?? 0,
              'ng': (entry.value['ng'] as bool?) ?? false,
            }
        };

        if (_currentSubjectIndex < _subjects.length - 1) {
          // Move to next subject
          if (mounted) {
            setState(() {
              _studentMarks.clear();
              _currentSubjectIndex++;
              _isLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $currentSubject marks saved! Next: ${_subjects[_currentSubjectIndex]}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Copy to Clipboard',
                  textColor: Colors.white,
                  onPressed: () async {
                    final clipboardText = await _generateClipboardSummary(currentSubject, marksByRoll, notGivenRolls, ranksByRoll, maxMarks);
                    await Clipboard.setData(ClipboardData(text: clipboardText));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ),
            );
          }
          return;
        } else {
          // All subjects done, save test series to Firestore
          await _saveTestSeriesToFirestore(repo, maxMarks);
          return;
        }
      }

      // Single test save
      await repo.saveTestMarksExtended(
        classLevel: _selectedClass,
        subject: _subjectController.text.isEmpty ? 'General' : _subjectController.text,
        topic: _topicController.text.isEmpty ? '—' : _topicController.text,
        testName: _testNameController.text,
        testKind: 'single',
        seriesId: null,
        date: DateTime.now(),
        maxMarks: maxMarks.toDouble(),
        marksByRoll: marksByRoll,
        notGivenRolls: notGivenRolls,
        savedBy: 'teacher@mentorclasses.com', // TODO: Get from auth
      );

      if (mounted) {
        // Reset form
        _testNameController.clear();
        _subjectController.clear();
        _topicController.clear();
        _maxMarksController.text = '100';
        setState(() {
          _studentMarks.clear();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Marks saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Copy to Clipboard',
              textColor: Colors.white,
              onPressed: () async {
                final clipboardText = await _generateClipboardSummary(
                  _subjectController.text.isEmpty ? 'General' : _subjectController.text,
                  marksByRoll,
                  notGivenRolls,
                  ranksByRoll,
                  maxMarks,
                );
                await Clipboard.setData(ClipboardData(text: clipboardText));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                  );
                }
              },
            ),
          ),
        );

        // Refresh data
        // ignore: unused_result
        ref.refresh(
          testMarksForClassProvider((_selectedClass, _selectedTestType, null)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTestSeriesToFirestore(dynamic repo, int maxMarks) async {
    final seriesId = _seriesIdController.text;
    
    // Save each subject as a separate test document
    for (final subject in _subjects) {
      final subjectMarks = _seriesMarksBySubject[subject] ?? {};
      
      final marksByRoll = <String, double>{};
      final notGivenRolls = <String>[];
      
      for (final entry in subjectMarks.entries) {
        final isNg = (entry.value['ng'] as bool?) ?? false;
        if (isNg) {
          notGivenRolls.add(entry.key);
        } else {
          marksByRoll[entry.key] = (entry.value['marks'] as int?)?.toDouble() ?? 0;
        }
      }
      
      // Calculate ranks for this subject
      final percentageByRoll = <String, double>{};
      for (final entry in marksByRoll.entries) {
        percentageByRoll[entry.key] = (entry.value / maxMarks) * 100;
      }
      
      final ranksByRoll = <String, int>{};
      if (percentageByRoll.isNotEmpty) {
        final sorted = percentageByRoll.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        for (int i = 0; i < sorted.length; i++) {
          ranksByRoll[sorted[i].key] = i + 1;
        }
      }
      
      await repo.saveTestMarksExtended(
        classLevel: _selectedClass,
        subject: subject,
        topic: _topicController.text.isEmpty ? '—' : _topicController.text,
        testName: '${_testNameController.text} - $subject',
        testKind: 'series',
        seriesId: seriesId,
        date: DateTime.now(),
        maxMarks: maxMarks.toDouble(),
        marksByRoll: marksByRoll,
        notGivenRolls: notGivenRolls,
        savedBy: 'teacher@mentorclasses.com',
      );
    }

    if (mounted) {
      // Reset form
      _testNameController.clear();
      _subjectController.clear();
      _topicController.clear();
      _seriesIdController.clear();
      _maxMarksController.text = '100';
      setState(() {
        _studentMarks.clear();
        _seriesMarksBySubject.clear();
        _currentSubjectIndex = 0;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Test Series saved successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy to Clipboard',
            textColor: Colors.white,
            onPressed: () async {
              final overallClipboard = await _generateSeriesClipboardSummary(maxMarks);
              await Clipboard.setData(ClipboardData(text: overallClipboard));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ),
      );

      // Refresh data
      // ignore: unused_result
      ref.refresh(
        testMarksForClassProvider((_selectedClass, 'series', seriesId)),
      );
    }
  }

  Future<String> _generateClipboardSummary(String subject, Map<String, double> marksByRoll, List<String> notGivenRolls, Map<String, int> ranksByRoll, int maxMarks) async {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('TEST MARKS SUMMARY');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Test: ${_testNameController.text}');
    buffer.writeln('Subject: $subject');
    buffer.writeln('Class: $_selectedClass');
    buffer.writeln('Max Marks: $maxMarks');
    buffer.writeln('Date: ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('RANK | ROLL NO | NAME | MARKS | STATUS');
    buffer.writeln('──────────────────────────────────────────');

    // Fetch student names from Firestore
    final Map<String, String> rollToName = {};
    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('classLevel', isEqualTo: _selectedClass)
          .get();
      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final roll = data['roll']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';
        if (roll.isNotEmpty && name.isNotEmpty) {
          rollToName[roll] = name;
        }
      }
    } catch (e) {
      debugPrint('Error fetching student names: $e');
    }

    final sortedEntries = marksByRoll.entries.toList()
      ..sort((a, b) => (ranksByRoll[a.key] ?? 999).compareTo(ranksByRoll[b.key] ?? 999));

    for (final entry in sortedEntries) {
      final roll = entry.key;
      final marks = entry.value.toInt();
      final rank = ranksByRoll[roll] ?? '-';
      final name = rollToName[roll] ?? 'Unknown';
      buffer.writeln('$rank | $roll | $name | $marks/$maxMarks | ${notGivenRolls.contains(roll) ? 'ABSENT' : 'PRESENT'}');
    }

    for (final roll in notGivenRolls) {
      if (!marksByRoll.containsKey(roll)) {
        final name = rollToName[roll] ?? 'Unknown';
        buffer.writeln('— | $roll | $name | NG | ABSENT');
      }
    }

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Total Students: ${marksByRoll.length + notGivenRolls.length}');
    buffer.writeln('Present: ${marksByRoll.length}');
    buffer.writeln('Absent: ${notGivenRolls.length}');
    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }

  Future<String> _generateSeriesClipboardSummary(int maxMarks) async {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('TEST SERIES OVERALL SUMMARY');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Series: ${_testNameController.text}');
    buffer.writeln('Series ID: ${_seriesIdController.text}');
    buffer.writeln('Class: $_selectedClass');
    buffer.writeln('Max Marks per Subject: $maxMarks');
    buffer.writeln('Date: ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('═══════════════════════════════════════');

    // Fetch student names from Firestore
    final Map<String, String> rollToName = {};
    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('classLevel', isEqualTo: _selectedClass)
          .get();
      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final roll = data['roll']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';
        if (roll.isNotEmpty && name.isNotEmpty) {
          rollToName[roll] = name;
        }
      }
    } catch (e) {
      debugPrint('Error fetching student names: $e');
    }

    for (final subject in _subjects) {
      final subjectMarks = _seriesMarksBySubject[subject] ?? {};
      buffer.writeln('\n--- $subject ---');
      buffer.writeln('Students marked: ${subjectMarks.length}');

      int presentCount = 0;
      int absentCount = 0;

      for (final entry in subjectMarks.entries) {
        final isNg = (entry.value['ng'] as bool?) ?? false;
        if (isNg) {
          absentCount++;
        } else {
          presentCount++;
        }
      }

      buffer.writeln('Present: $presentCount');
      buffer.writeln('Absent: $absentCount');
    }

    buffer.writeln('\n═══════════════════════════════════════');
    buffer.writeln('Total Subjects: ${_subjects.length}');
    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }
}
