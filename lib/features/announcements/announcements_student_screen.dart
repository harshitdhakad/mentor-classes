import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Full list of notices for the signed-in student, filtered by day and week.
class AnnouncementsStudentScreen extends ConsumerStatefulWidget {
  const AnnouncementsStudentScreen({super.key});

  @override
  ConsumerState<AnnouncementsStudentScreen> createState() => _AnnouncementsStudentScreenState();
}

class _AnnouncementsStudentScreenState extends ConsumerState<AnnouncementsStudentScreen> {
  String _filter = 'all'; // 'all', 'day', 'week'

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final repo = ref.watch(erpRepositoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Notices',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepBlue,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'day', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                ],
                onChanged: (v) => setState(() => _filter = v ?? 'all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.watchAnnouncementsStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: Text('Loading announcements...'));
              }
              List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.data!.docs;
              if (user != null && user.role == UserRole.student && StudentClassLevels.isValid(user.studentClass)) {
                final c = user.studentClass!;
                docs = docs.where((d) {
                  final cl = d.data()['classLevel'];
                  if (cl == null) return true;
                  return cl == c;
                }).toList();
              }

              // Filter by time
              final now = DateTime.now();
              if (_filter == 'day') {
                docs = docs.where((d) {
                  final createdAt = d.data()['createdAt'] as Timestamp?;
                  if (createdAt == null) return false;
                  final date = createdAt.toDate();
                  return DateUtils.isSameDay(date, now);
                }).toList();
              } else if (_filter == 'week') {
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                final weekEnd = weekStart.add(const Duration(days: 6));
                docs = docs.where((d) {
                  final createdAt = d.data()['createdAt'] as Timestamp?;
                  if (createdAt == null) return false;
                  final date = createdAt.toDate();
                  return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                         date.isBefore(weekEnd.add(const Duration(days: 1)));
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(child: Text('No notices yet.', style: GoogleFonts.poppins()));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Icon(
                        d['type'] == 'holiday' ? Icons.beach_access : Icons.notifications_active_outlined,
                        color: AppTheme.deepBlue,
                      ),
                      title: Text(d['title']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(d['body']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 13, height: 1.35)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
