import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';
import 'models/user_model.dart';
import 'features/about/about_screen.dart';
import 'features/about/meet_our_faculty_screen.dart';
import 'features/academic/academic_resource_hub_screen.dart';
import 'features/academic/syllabus_tracker_student_screen.dart';
import 'features/academic/syllabus_tracker_teacher_screen.dart';
import 'features/announcements/announcements_staff_screen.dart';
import 'features/announcements/announcements_student_screen.dart';
import 'features/attendance/detailed_attendance_summary_screen.dart';
import 'features/attendance/student_attendance_screen.dart';
import 'features/attendance/teacher_attendance_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_control_panel_screen.dart';
import 'features/fees/fees_analytics_panel_screen.dart';
import 'features/fees/admin_fees_management_screen.dart';
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
import 'features/student/batch_manager_screen.dart';
import 'features/student/student_fees_screen.dart';
import 'features/student/student_management_screen.dart';
import 'features/tests/detailed_student_performance_screen.dart';
import 'features/tests/enhanced_leaderboard_screen.dart';
import 'features/tests/enhanced_marks_upload_screen.dart';
import 'features/tests/leaderboard_screen.dart';
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
      onUnknownRoute: (settings) {
        debugPrint('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found: ${settings.name}',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainShellScreen(),
        // About & Faculty
        '/about': (context) => const AboutScreen(),
        '/faculty': (context) => const MeetOurFacultyScreen(),
        // Home Pages
        '/staff-home': (context) => const StaffHomePage(),
        '/student-home': (context) => const StudentHomePage(),
        // Attendance
        '/attendance-teacher': (context) => const TeacherAttendanceScreen(),
        '/attendance-student': (context) => const StudentAttendanceScreen(),
        '/attendance-summary': (context) => const DetailedAttendanceSummaryScreen(),
        // Fees Management
        '/student-fees': (context) => const StudentFeesScreen(),
        '/admin-fees': (context) => const AdminFeesManagementScreen(),
        '/fees-analytics': (context) => const FeesAnalyticsPanelScreen(),
        '/admin-controls': (context) => const AdminControlPanelScreen(),
        '/student-management': (context) => const StudentManagementScreen(),
        // New: Batch Manager
        '/batch-manager': (context) => const BatchManagerScreen(),
        // Academic Resources (NEW)
        '/academic-resources': (context) => const AcademicResourceHubScreen(),
        '/academic': (context) => const AcademicResourceHubScreen(),
        // Syllabus Tracker (NEW)
        '/syllabus-teacher': (context) => const SyllabusTrackerTeacherScreen(),
        '/syllabus-student': (context) => Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(authProvider);
            if (user == null || user.role != UserRole.student || !StudentClassLevels.isValid(user.studentClass)) {
              return const Scaffold(body: Center(child: Text('Student class not found')));
            }
            return SyllabusTrackerStudentScreen(classLevel: user.studentClass!);
          },
        ),
        // Tests & Performance
        '/tests': (context) => const TestHubScreen(),
        '/enhanced-marks-upload': (context) => const EnhancedMarksUploadScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/enhanced-leaderboard': (context) => const EnhancedLeaderboardScreen(),
        '/performance': (context) => const StudentPerformanceScreen(),
        '/performance-detailed': (context) => const DetailedStudentPerformanceScreen(),
        // Schedule
        '/schedule-admin': (context) => const ScheduleAdminScreen(),
        '/schedule-student': (context) => const StudentScheduleScreen(),
        '/advanced-schedule': (context) => const AdvancedScheduleScreen(),
        // Announcements
        '/updates-center': (context) => const UpdatesCenterScreen(),
        '/announcements-staff': (context) => const AnnouncementsStaffScreen(),
        '/announcements-student': (context) => const AnnouncementsStudentScreen(),
        // Homework
        '/homework-teacher': (context) => const HomeworkTeacherScreen(),
        '/homework-student': (context) => const HomeworkStudentScreen(),
        // Todo
        '/todo': (context) => const StudentTodoScreen(),
      },
    );
  }
}
