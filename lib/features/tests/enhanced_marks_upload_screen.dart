import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';

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

  int _selectedClass = 5;
  String _selectedTestType = 'weekly';
  final List<String> _testTypes = ['weekly', 'monthly', 'series'];

  final Map<String, Map<String, dynamic>> _studentMarks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testNameController = TextEditingController();
    _maxMarksController = TextEditingController(text: '100');
    _subjectController = TextEditingController();
    _topicController = TextEditingController();
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _maxMarksController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        selectedColor: AppTheme.deepBluePrimary.withOpacity(0.2),
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
            const SizedBox(height: 24),

            // Students Marks Entry
            Text(
              'Student Marks',
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
                label: Text(_isLoading ? 'Saving...' : 'Save Marks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepBluePrimary,
                  disabledBackgroundColor: Colors.grey[400],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              decoration: InputDecoration(
                hintText: 'Marks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _studentMarks[student.rollNumber] = {
                    'marks': double.tryParse(value) ?? 0,
                    'ng': false,
                  };
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // NG Checkbox
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    final current = _studentMarks[student.rollNumber] ?? {'marks': 0, 'ng': false};
                    _studentMarks[student.rollNumber] = {
                      'marks': current['marks'] as double? ?? 0,
                      'ng': !(current['ng'] as bool? ?? false),
                    };
                    if (isNg) markController.clear();
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isNg ? Colors.orange : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: isNg ? Colors.orange.withOpacity(0.1) : null,
                  ),
                  child: Center(
                    child: Text(
                      isNg ? 'NG' : 'OK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isNg ? Colors.orange : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'NG',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
              ),
            ],
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

    if (_studentMarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter marks for at least one student')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(erpRepositoryProvider);
      final maxMarks = double.tryParse(_maxMarksController.text) ?? 100;

      // Prepare data
      final marksByRoll = <String, double>{};
      final percentageByRoll = <String, double>{};
      final notGivenRolls = <String>[];

      for (final entry in _studentMarks.entries) {
        final roll = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final isNg = (data['ng'] as bool?) ?? false;

        if (isNg) {
          notGivenRolls.add(roll);
        } else {
          final marks = (data['marks'] as double?) ?? 0;
          marksByRoll[roll] = marks;
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

      // Save to Firestore
      await repo.saveTestMarksExtended(
        classLevel: _selectedClass,
        subject: _subjectController.text.isEmpty ? 'General' : _subjectController.text,
        topic: _topicController.text.isEmpty ? '—' : _topicController.text,
        testName: _testNameController.text,
        testKind: 'single',
        seriesId: null,
        date: DateTime.now(),
        maxMarks: maxMarks,
        marksByRoll: marksByRoll,
        notGivenRolls: notGivenRolls,
        savedBy: 'teacher@mentorclasses.com', // TODO: Get from auth
      );

      // Add testType to the saved data (extend repo method if needed)
      // For now we'll just show success

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
          const SnackBar(
            content: Text('✅ Marks saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh data
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
}
