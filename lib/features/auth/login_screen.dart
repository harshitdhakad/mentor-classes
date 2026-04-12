import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_footer.dart';
import '../../models/user_model.dart';
import 'auth_service.dart';

/// Material 3 login with role selector: Admin, Teacher, or Student.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  UserRole _role = UserRole.student;
  int _studentClass = StudentClassLevels.min;
  final _emailCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _staffFormKey = GlobalKey<FormState>();
  final _studentFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _rollCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isStaff = _role == UserRole.admin || _role == UserRole.teacher;
    if (isStaff) {
      if (!_staffFormKey.currentState!.validate()) return;
    } else {
      if (!_studentFormKey.currentState!.validate()) return;
    }

    setState(() => _busy = true);
    debugPrint('LoginScreen: Starting login process');
    try {
      if (isStaff) {
        debugPrint('LoginScreen: Attempting staff login');
        await ref.read(authProvider.notifier).signInStaff(
              role: _role,
              email: _emailCtrl.text,
              password: _passwordCtrl.text,
            );
      } else {
        debugPrint('LoginScreen: Attempting student login');
        await ref.read(authProvider.notifier).signInStudent(
              rollNumber: _rollCtrl.text,
              classLevel: _studentClass,
              password: _passwordCtrl.text,
            );
      }
      debugPrint('LoginScreen: Login successful, checking user state');
      final user = ref.read(authProvider);
      debugPrint('LoginScreen: User after login: ${user?.displayName}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user?.displayName ?? ''}')),
        );
        debugPrint('LoginScreen: Navigating to dashboard');
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } on AuthException catch (e) {
      debugPrint('LoginScreen: AuthException: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('LoginScreen: Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 28),
                        _LoginPanel(
                          role: _role,
                          onRoleChanged: (r) => setState(() => _role = r),
                          busy: _busy,
                          emailCtrl: _emailCtrl,
                          rollCtrl: _rollCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscurePassword: _obscurePassword,
                          onTogglePassword: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          staffFormKey: _staffFormKey,
                          studentFormKey: _studentFormKey,
                          onSubmit: _submit,
                          selectedClass: _studentClass,
                          onStudentClassChanged: (value) {
                            if (value != null) {
                              setState(() => _studentClass = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Founder: Yogesh Udawat',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const MentorFooter(),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.deepBlue, AppTheme.deepBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MENTOR CLASSES',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ERP',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Vidisha · Classes 5–10 · CBSE / NCERT',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.role,
    required this.onRoleChanged,
    required this.busy,
    required this.emailCtrl,
    required this.rollCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.staffFormKey,
    required this.studentFormKey,
    required this.onSubmit,
    required this.selectedClass,
    required this.onStudentClassChanged,
  });

  final UserRole role;
  final ValueChanged<UserRole> onRoleChanged;
  final bool busy;
  final TextEditingController emailCtrl;
  final TextEditingController rollCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final GlobalKey<FormState> staffFormKey;
  final GlobalKey<FormState> studentFormKey;
  final VoidCallback onSubmit;
  final int selectedClass;
  final ValueChanged<int?> onStudentClassChanged;

  bool get _isStaff => role == UserRole.admin || role == UserRole.teacher;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select Admin, Teacher, or Student. Staff use institute email + password.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                ButtonSegment<UserRole>(
                  value: UserRole.admin,
                  label: Text(UserRole.admin.label),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                ),
                ButtonSegment<UserRole>(
                  value: UserRole.teacher,
                  label: Text(UserRole.teacher.label),
                  icon: const Icon(Icons.co_present_outlined, size: 18),
                ),
                ButtonSegment<UserRole>(
                  value: UserRole.student,
                  label: Text(UserRole.student.label),
                  icon: const Icon(Icons.school_outlined, size: 18),
                ),
              ],
              selected: {role},
              onSelectionChanged: (s) => onRoleChanged(s.first),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isStaff
                  ? Form(
                      key: staffFormKey,
                      child: Column(
                        key: const ValueKey('staff'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            role == UserRole.admin
                                ? 'Administrator access (email + password from institute records).'
                                : 'Teacher access (email + password provided by admin).',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordCtrl,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: onTogglePassword,
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => onSubmit(),
                          ),
                          const SizedBox(height: 20),
                          _SubmitButton(busy: busy, onSubmit: onSubmit),
                        ],
                      ),
                    )
                  : Form(
                      key: studentFormKey,
                      child: Column(
                        key: const ValueKey('student'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Students (Classes 5–10): enter roll number and password from your Firestore profile (e.g. after admin Excel upload).',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: selectedClass,
                            decoration: const InputDecoration(
                              labelText: 'Class',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: [
                              for (var c = StudentClassLevels.min;
                                  c <= StudentClassLevels.max;
                                  c++)
                                DropdownMenuItem(
                                  value: c,
                                  child: Text('Class $c'),
                                ),
                            ],
                            onChanged: onStudentClassChanged,
                            validator: (value) {
                              if (value == null ||
                                  !StudentClassLevels.isValid(value)) {
                                return 'Select your class level';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: rollCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Roll number',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your roll number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordCtrl,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: onTogglePassword,
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => onSubmit(),
                          ),
                          const SizedBox(height: 20),
                          _SubmitButton(busy: busy, onSubmit: onSubmit),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.busy, required this.onSubmit});

  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onSubmit,
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Continue'),
    );
  }
}
