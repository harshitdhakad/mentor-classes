import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../models/student_batch_model.dart';

/// Screen for managing students in batches by class
class BatchManagerScreen extends ConsumerStatefulWidget {
  const BatchManagerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BatchManagerScreen> createState() => _BatchManagerScreenState();
}

class _BatchManagerScreenState extends ConsumerState<BatchManagerScreen> {
  late TextEditingController _searchController;
  int _selectedClass = 5;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the enhanced student list
    final studentsAsync = ref.watch(studentsByClassEnhancedProvider(_selectedClass));

    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Batch Manager'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBlueContainer,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Class Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.deepBlueContainer.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Class',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      6,
                      (index) {
                        final classNum = index + 5;
                        final isSelected = _selectedClass == classNum;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('Class $classNum'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedClass = classNum);
                              _searchController.clear();
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.deepBluePrimary,
                            labelStyle: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or roll...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Students List
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                // Filter students based on search
                final filtered = _searchController.text.isEmpty
                    ? students
                    : students
                        .where((s) =>
                            s.name.toLowerCase().contains(
                                _searchController.text.toLowerCase()) ||
                            s.rollNumber
                                .contains(_searchController.text))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No students in this class'
                              : 'No students found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final student = filtered[index];
                    return _buildStudentCard(context, student);
                  },
                );
              },
              loading: () => const Center(child: Text('Loading students...')),
              error: (err, stack) => Center(
                child: Text('Error loading students. Please try again.'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
        backgroundColor: AppTheme.deepBluePrimary,
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, EnhancedStudentItem student) {
    final colors = [Colors.blue, Colors.green, Colors.orange];
    final statusColor = student.remainingFees <= 0 ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: MentorGlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors[student.colorIndex].withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors[student.colorIndex],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Roll: ${student.rollNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Password display
                    if (student.password != null && student.password!.isNotEmpty)
                      Text(
                        'Password: ${student.password}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Fees Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        student.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Action Menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditStudentDialog(student);
                  } else if (value == 'remove') {
                    _showRemoveConfirm(student);
                  } else if (value == 'fees') {
                    _showFeesDialog(student);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 12),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fees',
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, size: 18),
                        SizedBox(width: 12),
                        Text('View Fees'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Remove', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Fees Progress Bar
          if (student.totalFees > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (student.paidFees / student.totalFees).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(
                        student.remainingFees <= 0 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${student.remainingFees.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final mobileController = TextEditingController();
    final feesController = TextEditingController();
    final passwordController = TextEditingController();
    String feesCriteria = 'Monthly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rollController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Roll Number *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password (for login) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Fees *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: feesCriteria,
                  decoration: const InputDecoration(
                    labelText: 'Fees Criteria *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'Lumpsum', child: Text('Lumpsum')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => feesCriteria = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || rollController.text.isEmpty || passwordController.text.isEmpty || feesController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                  return;
                }

                try {
                  final repo = ref.read(erpRepositoryProvider);
                  final fees = double.tryParse(feesController.text) ?? 0.0;

                  await repo.addStudentManual(
                    classLevel: _selectedClass,
                    rollNumber: rollController.text,
                    name: nameController.text,
                    password: passwordController.text,
                    mobileContact: mobileController.text.isEmpty ? null : mobileController.text,
                    emergencyContact: null,
                    totalFees: fees,
                    feesCriteria: feesCriteria,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ref.refresh(studentsByClassEnhancedProvider(_selectedClass));
                    // ignore: unused_result
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Student added successfully!')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(EnhancedStudentItem student) {
    final nameController = TextEditingController(text: student.name);
    final rollController = TextEditingController(text: student.rollNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rollController,
              decoration: const InputDecoration(
                labelText: 'Roll Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = ref.read(erpRepositoryProvider);
                await repo.updateStudent(
                  studentDocId: student.docId,
                  name: nameController.text,
                  rollNumber: rollController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  // ignore: unused_result
                  ref.refresh(studentsByClassEnhancedProvider(_selectedClass));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Student updated!')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirm(EnhancedStudentItem student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text('Remove ${student.name} (Roll: ${student.rollNumber})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = ref.read(erpRepositoryProvider);
                await repo.removeStudent(student.docId);

                if (mounted) {
                  Navigator.pop(context);
                  // ignore: unused_result
                  ref.refresh(studentsByClassEnhancedProvider(_selectedClass));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student removed')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFeesDialog(EnhancedStudentItem student) {
    final totalController = TextEditingController(
      text: student.totalFees.toStringAsFixed(0),
    );
    final paidController = TextEditingController(
      text: student.paidFees.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Fees'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Fees',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paidController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Paid Amount',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = ref.read(erpRepositoryProvider);
                final total = double.parse(totalController.text);
                final paid = double.parse(paidController.text);

                await repo.updateStudentFees(
                  studentDocId: student.docId,
                  totalFees: total,
                  paidAmount: paid,
                );

                if (mounted) {
                  Navigator.pop(context);
                  // ignore: unused_result
                  ref.refresh(studentsByClassEnhancedProvider(_selectedClass));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Fees updated!')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
