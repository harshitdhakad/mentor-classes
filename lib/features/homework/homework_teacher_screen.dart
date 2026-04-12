import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Teacher/Admin: assign today's homework for a class.
class HomeworkTeacherScreen extends ConsumerStatefulWidget {
  const HomeworkTeacherScreen({super.key});

  @override
  ConsumerState<HomeworkTeacherScreen> createState() => _HomeworkTeacherScreenState();
}

class _HomeworkTeacherScreenState extends ConsumerState<HomeworkTeacherScreen> {
  int _classLevel = 8;
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isStaff || user.email == null) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Save homework without file attachments
      await ref.read(erpRepositoryProvider).saveHomework(
            classLevel: _classLevel,
            title: _title.text.trim(),
            description: _body.text.trim(),
            assignedBy: user.email!,
          );

      if (mounted) {
        _title.clear();
        _body.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Homework posted for Class $_classLevel'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    
    // Authentication check
    if (user == null || !user.isStaff) {
      return const Center(
        child: Text(
          'Access Denied',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Today's homework",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students see this under Homework for the date you post.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _classLevel,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [
              for (var c = StudentClassLevels.min; c <= StudentClassLevels.max; c++)
                DropdownMenuItem(value: c, child: Text('Class $c')),
            ],
            onChanged: (v) => setState(() => _classLevel = v ?? 8),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            decoration: const InputDecoration(
              labelText: 'Details',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Publish homework',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
