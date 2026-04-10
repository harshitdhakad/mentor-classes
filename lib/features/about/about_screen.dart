import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mentor_classes/core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../../data/erp_providers.dart';

/// About Mentor Classes screen.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.role.name == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('About Mentor Classes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Founder Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Founder & Visionary',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.deepBlue.withValues(alpha: 0.1),
                    child: Text(
                      'Y',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yogesh Udawat',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A passionate educator dedicated to nurturing young minds and building a brighter future through quality education. With years of experience in teaching and mentoring, Yogesh founded Mentor Classes to provide exceptional learning experiences for students.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Developer Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lead Developer & Architect',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.deepBlue.withValues(alpha: 0.1),
                    child: Text(
                      'H',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Harshit Dhakad',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ' Student & talented coder',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A talented young developer who combines academic excellence with cutting-edge technology skills. Harshit specializes in Flutter development and vibecoding, bringing innovative solutions to educational technology.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Version History
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version History',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VersionItem(
                    version: '1.0.0',
                    date: 'April 2026',
                    changes: [
                      'Initial release of Mentor Classes ERP',
                      'Weekly schedule management',
                      'Real-time attendance tracking',
                      'Homework assignments',
                      'Test marks and performance analytics',
                      'Announcements and notifications',
                      'Student and staff dashboards',
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Admin Reset Section
          if (isAdmin)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Controls',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reset all data - This action cannot be undone',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _confirmReset(context, ref),
                        icon: const Icon(Icons.delete_forever),
                        label: Text(
                          'Reset All Data',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isAdmin) const SizedBox(height: 20),
          // Contact Support
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Support',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Need help or have feedback? Reach out to us!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _launchEmail(),
                    icon: const Icon(Icons.email),
                    label: Text('Send Email', style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.deepBlue,
                      side: const BorderSide(color: AppTheme.deepBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Warning', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text(
          'This will delete ALL student data, fees records, attendance, test marks, and resources. This action CANNOT be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    final secondConfirm = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Final Confirmation', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Type "CONFIRMED" to proceed with data reset:',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'CONFIRMED',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context, 'CONFIRMED');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (secondConfirm != 'CONFIRMED') return;

    try {
      await ref.read(erpRepositoryProvider).resetAllData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All data has been reset. The app will restart.'),
            duration: Duration(seconds: 2),
          ),
        );
        
        await AuthService.logout();
        
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error during reset: $e')),
        );
      }
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@mentorclasses.com',
      queryParameters: {
        'subject': 'Mentor Classes ERP Support',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _VersionItem extends StatelessWidget {
  const _VersionItem({
    required this.version,
    required this.date,
    required this.changes,
  });

  final String version;
  final String date;
  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'v$version',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...changes.map(
          (change) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.deepBlue)),
                Expanded(
                  child: Text(
                    change,
                    style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}