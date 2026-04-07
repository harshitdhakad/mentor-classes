import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_footer.dart';
import '../../models/user_model.dart';
import '../academic/academic_hub_screen.dart';
import '../announcements/announcements_staff_screen.dart';
import '../attendance/student_attendance_screen.dart';
import '../attendance/teacher_attendance_screen.dart';
import '../auth/auth_service.dart';
import '../home/staff_home_page.dart';
import '../home/student_home_page.dart';
import '../homework/homework_student_screen.dart';
import '../homework/homework_teacher_screen.dart';
import '../schedule/schedule_admin_screen.dart';
import '../schedule/student_schedule_screen.dart';
import '../schedule/advanced_schedule_screen.dart';
import '../announcements/updates_center_screen.dart';
import '../tests/enhanced_leaderboard_screen.dart';
import '../todo/student_todo_screen.dart';
import '../about/about_screen.dart';

/// Role-aware drawer + body for MENTOR CLASSES ERP.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _index = 0;

  static const _staffTitles = [
    'Home',
    'Attendance',
    'Academic hub',
    'Tests',
    'Leaderboard',
    'Schedule Management',
    'Homework',
    'Notices',
    'About',
  ];

  static const _studentTitles = [
    'Home',
    'Study hub',
    'My schedule',
    'My scores',
    'To-Do',
    'Attendance',
    'Homework',
    'Updates',
    'About',
  ];

  List<Widget> _staffPages() => const [
        StaffHomePage(),
        TeacherAttendanceScreen(),
        AcademicHubScreen(isStaffView: true),
        AdvancedScheduleScreen(),
        EnhancedLeaderboardScreen(),
        ScheduleAdminScreen(),
        HomeworkTeacherScreen(),
        AnnouncementsStaffScreen(),
        AboutScreen(),
      ];

  List<Widget> _studentPages() => const [
        StudentHomePage(),
        AcademicHubScreen(isStaffView: false),
        StudentScheduleScreen(),
        EnhancedLeaderboardScreen(),
        StudentTodoScreen(),
        StudentAttendanceScreen(),
        HomeworkStudentScreen(),
        UpdatesCenterScreen(),
        AboutScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }

    final staff = user.isStaff;
    final titles = staff ? _staffTitles : _studentTitles;
    final pages = staff ? _staffPages() : _studentPages();
    final icons = staff
        ? const [
            Icons.home_outlined,
            Icons.fact_check_outlined,
            Icons.menu_book_outlined,
            Icons.quiz_outlined,
            Icons.emoji_events_outlined,
            Icons.calendar_today_outlined,
            Icons.assignment_outlined,
            Icons.campaign_outlined,
            Icons.info_outlined,
          ]
        : const [
            Icons.home_outlined,
            Icons.menu_book_outlined,
            Icons.event_note_outlined,
            Icons.show_chart,
            Icons.checklist,
            Icons.calendar_month,
            Icons.book_outlined,
            Icons.update_outlined,
            Icons.info_outlined,
          ];

    final subtitle = staff ? '${user.role.label} · Staff' : 'Student · Class ${user.studentClass ?? "—"}';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          titles[_index],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepBlue, AppTheme.deepBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.displayName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user.email ?? 'Roll ${user.rollNumber ?? "—"}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < titles.length; i++)
                ListTile(
                  leading: Icon(icons[i], color: _index == i ? AppTheme.deepBlue : null),
                  title: Text(titles[i], style: GoogleFonts.poppins(fontWeight: _index == i ? FontWeight.w600 : null)),
                  selected: _index == i,
                  selectedTileColor: AppTheme.deepBlue.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _index = i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: pages[_index]),
          const MentorFooter(),
        ],
      ),
    );
  }
}
