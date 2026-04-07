import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/about/about_screen.dart';
import 'features/academic/academic_hub_screen.dart';
import 'features/announcements/announcements_staff_screen.dart';
import 'features/announcements/announcements_student_screen.dart';
import 'features/attendance/student_attendance_screen.dart';
import 'features/attendance/teacher_attendance_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/staff_home_page.dart';
import 'features/home/student_home_page.dart';
import 'features/homework/homework_student_screen.dart';
import 'features/homework/homework_teacher_screen.dart';
import 'features/schedule/advanced_schedule_screen.dart';
import 'features/schedule/schedule_admin_screen.dart';
import 'features/schedule/student_schedule_screen.dart';
import 'features/announcements/updates_center_screen.dart';
import 'features/shell/main_shell_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/student/student_fees_screen.dart';
import 'features/tests/leaderboard_screen.dart';
import 'features/tests/enhanced_leaderboard_screen.dart';
import 'features/tests/student_performance_screen.dart';
import 'features/tests/test_hub_screen.dart';
import 'features/todo/student_todo_screen.dart';

class MentorClassesApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const MentorClassesApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MENTOR CLASSES ERP',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainShellScreen(),
        // Individual screens for direct access if needed
        '/about': (context) => const AboutScreen(),
        '/staff-home': (context) => const StaffHomePage(),
        '/student-home': (context) => const StudentHomePage(),
        '/attendance-teacher': (context) => const TeacherAttendanceScreen(),
        '/attendance-student': (context) => const StudentAttendanceScreen(),
        '/student-fees': (context) => const StudentFeesScreen(),
        '/academic': (context) => const AcademicHubScreen(isStaffView: false),
        '/tests': (context) => const TestHubScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/enhanced-leaderboard': (context) => const EnhancedLeaderboardScreen(),
        '/schedule-admin': (context) => const ScheduleAdminScreen(),
        '/schedule-student': (context) => const StudentScheduleScreen(),
        '/advanced-schedule': (context) => const AdvancedScheduleScreen(),
        '/updates-center': (context) => const UpdatesCenterScreen(),
        '/homework-teacher': (context) => const HomeworkTeacherScreen(),
        '/homework-student': (context) => const HomeworkStudentScreen(),
        '/announcements-staff': (context) => const AnnouncementsStaffScreen(),
        '/announcements-student': (context) => const AnnouncementsStudentScreen(),
        '/performance': (context) => const StudentPerformanceScreen(),
        '/todo': (context) => const StudentTodoScreen(),
      },
    );
  }
}
