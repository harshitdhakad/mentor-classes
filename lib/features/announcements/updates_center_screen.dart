import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

class UpdatesCenterScreen extends ConsumerStatefulWidget {
  const UpdatesCenterScreen({super.key});

  @override
  ConsumerState<UpdatesCenterScreen> createState() => _UpdatesCenterScreenState();
}

class _UpdatesCenterScreenState extends ConsumerState<UpdatesCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || user.role != UserRole.student) {
      return const Center(child: Text('Access denied'));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Updates Center', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Homework'),
              Tab(text: 'Tests'),
              Tab(text: 'Announcements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UpdatesList(category: 'attendance', classLevel: user.studentClass!),
            _UpdatesList(category: 'homework', classLevel: user.studentClass!),
            _UpdatesList(category: 'test', classLevel: user.studentClass!),
            _UpdatesList(category: 'announcements', classLevel: user.studentClass!),
          ],
        ),
      ),
    );
  }
}

class _UpdatesList extends ConsumerStatefulWidget {
  final String category;
  final int classLevel;

  const _UpdatesList({required this.category, required this.classLevel});

  @override
  ConsumerState<_UpdatesList> createState() => _UpdatesListState();
}

class _UpdatesListState extends ConsumerState<_UpdatesList> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _updates = [];

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    setState(() => _isLoading = true);

    // Simulate loading for 5-10 seconds
    await Future.delayed(const Duration(seconds: 5));

    try {
      List<Map<String, dynamic>> updates = [];

      switch (widget.category) {
        case 'attendance':
          updates = await _fetchAttendanceUpdates();
          break;
        case 'homework':
          updates = await _fetchHomeworkUpdates();
          break;
        case 'test':
          updates = await _fetchTestUpdates();
          break;
        case 'announcements':
          updates = await _fetchAnnouncementUpdates();
          break;
      }

      setState(() {
        _updates = updates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceUpdates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('classLevel', isEqualTo: widget.classLevel)
        .orderBy('date', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': 'Attendance Record',
        'body': 'Attendance marked for ${data['date'] ?? 'Date'}',
        'date': data['date'] ?? '',
        'icon': Icons.check_circle,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchHomeworkUpdates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('homework')
        .where('classLevel', isEqualTo: widget.classLevel)
        .orderBy('dueDate', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['title'] ?? 'Homework Assignment',
        'body': data['description'] ?? 'No description',
        'date': data['dueDate'] ?? '',
        'icon': Icons.book,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTestUpdates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('test_marks')
        .doc(widget.classLevel.toString())
        .collection('tests')
        .orderBy('testDate', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['testName'] ?? 'Test',
        'body': 'Test conducted on ${data['testDate'] ?? 'Date'}',
        'date': data['testDate'] ?? '',
        'icon': Icons.assignment,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAnnouncementUpdates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .where('classLevel', isEqualTo: widget.classLevel)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final timestamp = data['createdAt'] as Timestamp?;
      return {
        'title': data['title'] ?? 'Announcement',
        'body': data['body'] ?? '',
        'date': timestamp?.toDate().toString().split(' ')[0] ?? '',
        'icon': Icons.campaign,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_updates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(widget.category),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.category} updates yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new updates',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUpdates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _updates.length,
        itemBuilder: (context, index) {
          final update = _updates[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: AppTheme.deepBlue.withValues(alpha: 0.1),
                child: Icon(update['icon'], color: AppTheme.deepBlue),
              ),
              title: Text(
                update['title'] ?? 'Update',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    update['body'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    update['date'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'attendance':
        return Icons.check_circle;
      case 'homework':
        return Icons.book;
      case 'test':
        return Icons.assignment;
      case 'announcements':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
}