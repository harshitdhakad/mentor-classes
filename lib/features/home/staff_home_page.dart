import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';
import '../staff/bulk_upload_screen.dart';
import 'widgets/staff_class_performance_widget.dart';

/// Staff dashboard body (embedded in [MainShellScreen]).
class StaffHomePage extends ConsumerStatefulWidget {
  const StaffHomePage({super.key});

  @override
  ConsumerState<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends ConsumerState<StaffHomePage> {
  int _selectedClass = 5;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || !user.isStaff) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hello, ${user.displayName}',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.role.label} · Classes ${StudentClassLevels.min}–${StudentClassLevels.max}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Open the menu for attendance, tests hub, weekly schedule, homework, and notices.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          // Class Selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Class for Performance Data',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
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
                            setState(() => _selectedClass = classNum);
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: AppTheme.deepBlue.withOpacity(0.2),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppTheme.deepBlue : Colors.black87,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Today's Attendance Status
          Text(
            'Today\'s Attendance',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('classLevel', isEqualTo: _selectedClass)
                .where('date', isEqualTo: DateTime.now().toString().split(' ')[0])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Text('Loading...'),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Error loading attendance'),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'object-not-found',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ),
                );
              }

              final attendanceDoc = snapshot.data!.docs.first;
              final data = attendanceDoc.data() as Map<String, dynamic>;
              final presentCount = (data['present'] as List?)?.length ?? 0;
              final absentCount = (data['absent'] as List?)?.length ?? 0;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AttendanceStat(
                        label: 'Present',
                        count: presentCount,
                        color: Colors.green,
                      ),
                      _AttendanceStat(
                        label: 'Absent',
                        count: absentCount,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (user.role == UserRole.admin) ...[
            _HomeCard(
              icon: Icons.groups_2_outlined,
              title: 'Bulk upload students',
              subtitle: 'Excel → Firestore (incl. mobile & emergency contact).',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const BulkUploadScreen()),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Class Performance Analytics
          Text(
            'Class Performance',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          StaffClassPerformanceWidget(classLevel: _selectedClass),
          const SizedBox(height: 24),
          _HomeCard(
            icon: Icons.menu_open,
            title: 'Navigation drawer',
            subtitle: 'Attendance, academic hub, tests, leaderboard, schedule, homework, notices.',
            onTap: () => Scaffold.of(context).openDrawer(),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MentorGlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.deepBlue.withValues(alpha: 0.12),
          foregroundColor: AppTheme.deepBlue,
          child: Icon(icon),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, height: 1.35)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
