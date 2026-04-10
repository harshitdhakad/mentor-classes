import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../data/erp_repository.dart';
import '../auth/auth_service.dart';
import 'mark_entry_config.dart';

/// Smart marks entry: name + roll list, marks field, NG checkbox per student.
class MarksEntryScreen extends ConsumerStatefulWidget {
  const MarksEntryScreen({super.key, required this.config});

  final MarkEntryConfig config;

  @override
  ConsumerState<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends ConsumerState<MarksEntryScreen> {
  List<StudentListItem> _students = [];
  final Map<String, TextEditingController> _marks = {};
  final Map<String, bool> _ng = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _marks.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ref.read(erpRepositoryProvider).fetchStudentsByClass(widget.config.classLevel);
    for (final c in _marks.values) {
      c.dispose();
    }
    _marks.clear();
    _ng.clear();
    for (final s in list) {
      _marks[s.roll] = TextEditingController();
      _ng[s.roll] = false;
    }
    setState(() {
      _students = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isStaff || user.email == null) return;

    final marks = <String, double>{};
    final ngList = <String>[];

    for (final s in _students) {
      if (_ng[s.roll] == true) {
        ngList.add(s.roll);
        continue;
      }
      final t = _marks[s.roll]?.text.trim() ?? '';
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v != null) marks[s.roll] = v;
    }

    if (marks.isEmpty && ngList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter marks or mark students as NG.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(erpRepositoryProvider).saveTestMarksExtended(
            classLevel: widget.config.classLevel,
            subject: widget.config.subject,
            topic: widget.config.topic,
            testName: widget.config.testName,
            testKind: widget.config.testKind,
            seriesId: widget.config.seriesId,
            date: widget.config.date,
            maxMarks: widget.config.maxMarks,
            marksByRoll: marks,
            notGivenRolls: ngList,
            savedBy: user.email!,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. Ranks updated & parents notified (placeholder).')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.testName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: MentorGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${widget.config.classLevel} · ${widget.config.subject} · ${widget.config.topic}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                  ),
                  Text(
                    'Max ${widget.config.maxMarks} · ${df.format(widget.config.date)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Text('Loading students...'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _students.length,
                    itemBuilder: (context, i) {
                      final s = _students[i];
                      final ng = _ng[s.roll] ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text('Roll ${s.roll}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: _marks[s.roll],
                                  enabled: !ng,
                                  decoration: const InputDecoration(
                                    labelText: 'Marks',
                                    isDense: true,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('NG', style: GoogleFonts.poppins(fontSize: 10)),
                                  Checkbox(
                                    value: ng,
                                    onChanged: (v) {
                                      setState(() {
                                        _ng[s.roll] = v ?? false;
                                        if (_ng[s.roll] == true) _marks[s.roll]?.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save & rank', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
