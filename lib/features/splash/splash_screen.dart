import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/navigation/page_transitions.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

/// Professional splash screen with logo animation and auth check.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _navStarted = false; // Prevent duplicate navigation
  String _loadingText = 'Initializing...';
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Check auth immediately after animation
    Future.delayed(const Duration(milliseconds: 1000), _checkAuth);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    try {
      if (!mounted || _navStarted) return; // Prevent duplicate navigation
      _navStarted = true;
      debugPrint('SplashScreen: Starting auth check');

      setState(() => _loadingText = 'Checking authentication...');

      var user = ref.read(authProvider);
      debugPrint('SplashScreen: Initial user from provider: ${user?.displayName}');
      if (user == null) {
        debugPrint('SplashScreen: User is null, attempting to restore from storage');
        setState(() => _loadingText = 'Restoring session...');
        user = await AuthService.restoreSavedUser();
        debugPrint('SplashScreen: Restored user: ${user?.displayName}');
        if (user != null && mounted) {
          await ref.read(authProvider.notifier).restoreSession(user);
          debugPrint('SplashScreen: Session restored');
          setState(() => _loadingText = 'Initialization complete.');
        }
      }

      if (!mounted) return;

      // Re-check after potential async auth restoration
      user = ref.read(authProvider);
      debugPrint('SplashScreen: Final user check: ${user?.displayName}');

      if (user != null) {
        debugPrint('SplashScreen: Navigating to dashboard');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } else {
        debugPrint('SplashScreen: Navigating to login');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            CustomPageTransitions.slideFromLeft(const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('SplashScreen: Error during auth check: $e');
      if (mounted) {
        if (_retryCount < _maxRetries) {
          _retryCount++;
          setState(() => _loadingText = 'Error during initialization. Retrying... ($_retryCount/$_maxRetries)');
          // Retry after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _navStarted = false;
              _checkAuth();
            }
          });
        } else {
          // Max retries reached, navigate to login screen
          debugPrint('SplashScreen: Max retries reached, navigating to login');
          setState(() => _loadingText = 'Redirecting to login...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                CustomPageTransitions.slideFromLeft(const LoginScreen()),
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.deepBlue, AppTheme.deepBlueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo placeholder - will use assets/images/logo.png when available
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'MENTOR CLASSES',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ERP System',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Loading indicator
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _loadingText,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Text(
                'Developed by Harshit Dhakad',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}