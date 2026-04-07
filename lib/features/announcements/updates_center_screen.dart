import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

class UpdatesCenterScreen extends ConsumerWidget {
  const UpdatesCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Tab(text: 'General'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UpdatesList(category: 'attendance', classLevel: user.studentClass!),
            _UpdatesList(category: 'homework', classLevel: user.studentClass!),
            _UpdatesList(category: 'test', classLevel: user.studentClass!),
            _UpdatesList(category: 'general', classLevel: user.studentClass!),
          ],
        ),
      ),
    );
  }
}

class _UpdatesList extends ConsumerWidget {
  final String category;
  final int classLevel;

  const _UpdatesList({required this.category, required this.classLevel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(erpRepositoryProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: repo.getUpdatesByCategory(category, classLevel),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $category updates yet',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['createdAt'] as Timestamp?;
            final date = timestamp?.toDate().toString().split(' ')[0] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(data['title'] ?? 'Update', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['body'] ?? '', style: GoogleFonts.poppins()),
                    const SizedBox(height: 4),
                    Text(date, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                leading: Icon(_getCategoryIcon(category), color: AppTheme.deepBlue),
              ),
            );
          },
        );
      },
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
      case 'general':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
}