import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_footer.dart';
import '../../models/user_model.dart';
import '../../main.dart';
import '../academic/academic_resource_hub_screen.dart';
import '../academic/chapter_tracking_screen.dart';
import '../announcements/announcements_staff_screen.dart';
import '../attendance/detailed_attendance_summary_screen.dart';
import '../attendance/teacher_attendance_screen.dart';
import '../auth/auth_service.dart';
import '../fees/admin_fees_panel_screen.dart';
import '../home/staff_home_page.dart';
import '../home/student_home_page.dart';
import '../homework/homework_student_screen.dart';
import '../homework/homework_teacher_screen.dart';
import '../schedule/schedule_admin_screen.dart';
import '../schedule/student_schedule_screen.dart';
import '../announcements/updates_center_screen.dart';
import '../tests/detailed_student_performance_screen.dart';
import '../tests/enhanced_leaderboard_screen.dart';
import '../tests/enhanced_marks_upload_screen.dart';
import '../todo/student_todo_screen.dart';
import '../about/about_screen.dart';
import '../about/meet_our_faculty_screen.dart';
import '../student/batch_manager_screen.dart';
import '../student/student_profile_screen.dart';

/// Role-aware drawer + body for MENTOR CLASSES ERP.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _index = 0;
  bool _isLoadingTimeout = false;

  @override
  void initState() {
    super.initState();
    // Add timeout to handle cases where auth state doesn't load
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && ref.read(authProvider) == null) {
        setState(() => _isLoadingTimeout = true);
        debugPrint('MainShellScreen: Auth state timeout, forcing logout');
        ref.read(authProvider.notifier).signOut();
      }
    });
  }

  static const _staffTitles = [
    'Home',
    'Attendance',
    'Batch Manager',
    'Academic Hub',
    'Upload Marks',
    'Leaderboard',
    'Schedule Management',
    'Homework',
    'Chapter Progress',
    'Admin Fees',
    'Notices',
    'Meet Faculty',
    'About',
  ];

  static const _studentTitles = [
    'Home',
    'Profile',
    'Study hub',
    'My schedule',
    'My scores',
    'Performance',
    'To-Do',
    'Attendance',
    'Homework',
    'Chapter Progress',
    'Updates',
    'Meet Faculty',
    'About',
  ];

  List<Widget> _staffPages() => const [
        StaffHomePage(),
        TeacherAttendanceScreen(),
        BatchManagerScreen(),
        AcademicResourceHubScreen(),
        EnhancedMarksUploadScreen(),
        EnhancedLeaderboardScreen(),
        ScheduleAdminScreen(),
        HomeworkTeacherScreen(),
        ChapterTrackingScreen(),
        AdminFeesPanelScreen(),
        AnnouncementsStaffScreen(),
        MeetOurFacultyScreen(),
        AboutScreen(),
      ];

  List<Widget> _studentPages() => const [
        StudentHomePage(),
        StudentProfileScreen(),
        AcademicResourceHubScreen(),
        StudentScheduleScreen(),
        EnhancedLeaderboardScreen(),
        DetailedStudentPerformanceScreen(),
        StudentTodoScreen(),
        DetailedAttendanceSummaryScreen(),
        HomeworkStudentScreen(),
        ChapterTrackingScreen(),
        UpdatesCenterScreen(),
        MeetOurFacultyScreen(),
        AboutScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    try {
      final user = ref.watch(authProvider);
      debugPrint('MainShellScreen: user = ${user?.displayName}, isStaff = ${user?.isStaff}');
      if (user == null) {
        debugPrint('MainShellScreen: User is null, showing loading');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _isLoadingTimeout ? 'Session expired. Please login again.' : 'Loading...',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: Text(
                    'Go to Login',
                    style: GoogleFonts.poppins(color: AppTheme.deepBlue),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final staff = user.isStaff;
      final titles = staff ? _staffTitles : _studentTitles;
      final pages = staff ? _staffPages() : _studentPages();
      final icons = staff
          ? const [
              Icons.home_outlined,
              Icons.fact_check_outlined,
              Icons.people_outlined,
              Icons.menu_book_outlined,
              Icons.edit_outlined,
              Icons.emoji_events_outlined,
              Icons.calendar_today_outlined,
              Icons.assignment_outlined,
              Icons.campaign_outlined,
              Icons.attach_money,
              Icons.notifications_outlined,
              Icons.school,
              Icons.info_outlined,
            ]
          : const [
              Icons.home_outlined,
              Icons.person_outline,
              Icons.menu_book_outlined,
              Icons.event_note_outlined,
              Icons.show_chart,
              Icons.assessment_outlined,
              Icons.checklist,
              Icons.calendar_month,
              Icons.book_outlined,
              Icons.update_outlined,
              Icons.school,
              Icons.notifications_outlined,
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
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                  // Show success message on login screen after navigation
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (navigatorKey.currentContext != null) {
                      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                        const SnackBar(
                          content: Text('Successfully logged out'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  });
                }
              },
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
            Expanded(
              child: Builder(
                builder: (context) {
                  try {
                    return pages[_index];
                  } catch (e, stackTrace) {
                    debugPrint('Error in page ${titles[_index]}: $e');
                    debugPrint('Stack trace: $stackTrace');
                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading ${titles[_index]}',
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$e',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const MentorFooter(),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error in MainShellScreen: $e');
      debugPrint('Stack trace: $stackTrace');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading dashboard',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
