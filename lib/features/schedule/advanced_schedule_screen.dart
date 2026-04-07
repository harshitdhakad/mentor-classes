import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';

class AdvancedScheduleScreen extends ConsumerStatefulWidget {
  const AdvancedScheduleScreen({super.key});

  @override
  ConsumerState<AdvancedScheduleScreen> createState() => _AdvancedScheduleScreenState();
}

class _AdvancedScheduleScreenState extends ConsumerState<AdvancedScheduleScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Class Schedule'),
            Tab(text: 'Test Schedule'),
            Tab(text: 'Holidays'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ClassScheduleTab(),
          TestScheduleTab(),
          HolidayTab(),
        ],
      ),
    );
  }
}

class ClassScheduleTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<ClassScheduleTab> createState() => _ClassScheduleTabState();
}

class _ClassScheduleTabState extends ConsumerState<ClassScheduleTab> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _teacherController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  int _selectedClass = 9;

  Future<void> _addClass() async {
    if (_subjectController.text.isEmpty || _timeController.text.isEmpty) return;

    final repo = ref.read(erpRepositoryProvider);
    await repo.addClassSchedule(
      classLevel: _selectedClass,
      subject: _subjectController.text,
      time: _timeController.text,
      teacher: _teacherController.text,
      room: _roomController.text,
    );

    _subjectController.clear();
    _timeController.clear();
    _teacherController.clear();
    _roomController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class added successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add New Class', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedClass,
            decoration: const InputDecoration(labelText: 'Class'),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Class ${i + 1}'))),
            onChanged: (value) => setState(() => _selectedClass = value!),
          ),
          TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
          TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time')),
          TextField(controller: _teacherController, decoration: const InputDecoration(labelText: 'Teacher')),
          TextField(controller: _roomController, decoration: const InputDecoration(labelText: 'Room')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _addClass, child: const Text('Add Class')),
          const SizedBox(height: 32),
          Expanded(child: _ClassList(selectedClass: _selectedClass)),
        ],
      ),
    );
  }
}

class _ClassList extends ConsumerWidget {
  final int selectedClass;

  const _ClassList({required this.selectedClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(erpRepositoryProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: repo.getClassSchedules(selectedClass),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['subject'] ?? ''),
                subtitle: Text('${data['time']} - ${data['teacher']} (${data['room']})'),
              ),
            );
          },
        );
      },
    );
  }
}

class TestScheduleTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<TestScheduleTab> createState() => _TestScheduleTabState();
}

class _TestScheduleTabState extends ConsumerState<TestScheduleTab> {
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _syllabusController = TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController();
  int _selectedClass = 9;

  Future<void> _scheduleTest() async {
    if (_testNameController.text.isEmpty || _dateController.text.isEmpty) return;

    final repo = ref.read(erpRepositoryProvider);
    await repo.scheduleTest(
      classLevel: _selectedClass,
      testName: _testNameController.text,
      date: _dateController.text,
      time: _timeController.text,
      syllabus: _syllabusController.text,
      maxMarks: double.tryParse(_maxMarksController.text) ?? 100,
    );

    // Send notification
    // TODO: Implement notification sending

    _testNameController.clear();
    _dateController.clear();
    _timeController.clear();
    _syllabusController.clear();
    _maxMarksController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test scheduled successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schedule New Test', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedClass,
            decoration: const InputDecoration(labelText: 'Class'),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Class ${i + 1}'))),
            onChanged: (value) => setState(() => _selectedClass = value!),
          ),
          TextField(controller: _testNameController, decoration: const InputDecoration(labelText: 'Test Name')),
          TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
          TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time')),
          TextField(controller: _syllabusController, decoration: const InputDecoration(labelText: 'Syllabus')),
          TextField(controller: _maxMarksController, decoration: const InputDecoration(labelText: 'Max Marks')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _scheduleTest, child: const Text('Schedule Test')),
          const SizedBox(height: 32),
          Expanded(child: _TestList(selectedClass: _selectedClass)),
        ],
      ),
    );
  }
}

class HolidayTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<HolidayTab> createState() => _HolidayTabState();
}

class _HolidayTabState extends ConsumerState<HolidayTab> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  int _selectedClass = 9;

  Future<void> _addHoliday() async {
    if (_dateController.text.isEmpty || _messageController.text.isEmpty) return;

    final repo = ref.read(erpRepositoryProvider);
    await repo.addHoliday(
      classLevel: _selectedClass,
      date: _dateController.text,
      message: _messageController.text,
    );

    _dateController.clear();
    _messageController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Holiday added successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Declare Holiday', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedClass,
            decoration: const InputDecoration(labelText: 'Class'),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Class ${i + 1}'))),
            onChanged: (value) => setState(() => _selectedClass = value!),
          ),
          TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
          TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Holiday Message')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _addHoliday, child: const Text('Declare Holiday')),
          const SizedBox(height: 32),
          Expanded(child: _HolidayList(selectedClass: _selectedClass)),
        ],
      ),
    );
  }
}

class _HolidayList extends ConsumerWidget {
  final int selectedClass;

  const _HolidayList({required this.selectedClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(erpRepositoryProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: repo.getHolidays(selectedClass),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['message'] ?? ''),
                subtitle: Text(data['date'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }
}