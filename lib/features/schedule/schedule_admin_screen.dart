import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';

const _dayOrder = [
  ('monday', 'Monday'),
  ('tuesday', 'Tuesday'),
  ('wednesday', 'Wednesday'),
  ('thursday', 'Thursday'),
  ('friday', 'Friday'),
  ('saturday', 'Saturday'),
  ('sunday', 'Sunday'),
];

/// Admin/Teacher: edit weekly timetable (2 slots per day + what to bring).
class ScheduleAdminScreen extends ConsumerStatefulWidget {
  const ScheduleAdminScreen({super.key});

  @override
  ConsumerState<ScheduleAdminScreen> createState() => _ScheduleAdminScreenState();
}

class _SlotFields {
  _SlotFields({String? start, String? end, String? subject, String? bring})
      : start = TextEditingController(text: start ?? ''),
        end = TextEditingController(text: end ?? ''),
        subject = TextEditingController(text: subject ?? ''),
        bring = TextEditingController(text: bring ?? '');

  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController subject;
  final TextEditingController bring;

  void dispose() {
    start.dispose();
    end.dispose();
    subject.dispose();
    bring.dispose();
  }

  Map<String, dynamic> toMap() => {
        'start': start.text.trim(),
        'end': end.text.trim(),
        'subject': subject.text.trim(),
        'bring': bring.text.trim(),
      };
}

class _ScheduleAdminScreenState extends ConsumerState<ScheduleAdminScreen> {
  final Map<String, List<_SlotFields>> _days = {};
  bool _loading = true;
  bool _saving = false;
  bool _scheduleExists = false;
  int _selectedClass = 9; // Default to class 9

  @override
  void initState() {
    super.initState();
    for (final d in _dayOrder) {
      _days[d.$1] = [_SlotFields(), _SlotFields()];
    }
    _load();
  }

  @override
  void dispose() {
    for (final list in _days.values) {
      for (final s in list) {
        s.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      // Add timeout to prevent infinite loading
      final raw = await ref.read(erpRepositoryProvider)
          .getWeeklyScheduleDays(_selectedClass)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⏱️ Schedule load timeout for class $_selectedClass');
              return null;
            },
          );
      
      if (raw != null && mounted) {
        // Check if schedule has any data
        bool hasData = false;
        for (final d in _dayOrder) {
          final key = d.$1;
          final dayData = raw[key];
          if (dayData is List && dayData.isNotEmpty) {
            hasData = true;
            // Handle dynamic number of slots
            for (var i = 0; i < (i < 2 ? 2 : dayData.length); i++) {
              if (i >= dayData.length) break;
              final m = dayData[i];
              if (m is! Map) continue;
              final map = Map<String, dynamic>.from(m.map((k, v) => MapEntry('$k', v)));
              if (_days[key] != null && i < _days[key]!.length) {
                _days[key]![i].start.text = map['start']?.toString() ?? '';
                _days[key]![i].end.text = map['end']?.toString() ?? '';
                _days[key]![i].subject.text = map['subject']?.toString() ?? '';
                _days[key]![i].bring.text = map['bring']?.toString() ?? '';
              }
            }
          }
        }
        setState(() => _scheduleExists = hasData);
      } else {
        setState(() => _scheduleExists = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading schedule: $e');
      setState(() => _scheduleExists = false);
      // Still show empty form on error, don't get stuck loading
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      for (final d in _dayOrder) {
        payload[d.$1] = _days[d.$1]!.map((s) => s.toMap()).toList();
      }
      await ref.read(erpRepositoryProvider).saveWeeklySchedule(_selectedClass, payload);
      setState(() => _scheduleExists = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scheduleExists ? 'Schedule updated successfully' : 'Weekly schedule saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Copy Monday's schedule to all other days of the week
  Future<void> _copyMondayToAllDays() async {
    final mondaySlots = _days['monday'];
    if (mondaySlots == null) return;

    // Confirm with user before copying
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Monday\'s schedule to all days?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text(
          'This will replace the schedule for Tuesday through Sunday with Monday\'s timings, subjects, and items.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Copy Monday's slots to all other days
    for (final d in _dayOrder) {
      if (d.$1 == 'monday') continue; // Skip Monday itself

      for (var slot = 0; slot < 2; slot++) {
        final mondaySlot = mondaySlots[slot];
        final targetSlot = _days[d.$1]![slot];

        targetSlot.start.text = mondaySlot.start.text;
        targetSlot.end.text = mondaySlot.end.text;
        targetSlot.subject.text = mondaySlot.subject.text;
        targetSlot.bring.text = mondaySlot.bring.text;
      }
    }

    if (mounted) {
      setState(() {}); // Rebuild to show updated fields
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monday\'s schedule applied to all days. Click "Save all days" to confirm.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Class selector
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Class',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(
                    StudentClassLevels.max - StudentClassLevels.min + 1,
                    (index) => DropdownMenuItem(
                      value: StudentClassLevels.min + index,
                      child: Text('Class ${StudentClassLevels.min + index}', style: GoogleFonts.poppins()),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedClass = value;
                        _scheduleExists = false;
                      });
                      _load();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        MentorGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Weekly schedule',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue, fontSize: 16),
                  ),
                  if (_scheduleExists)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '✓ Schedule uploaded',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Two classes per day: time range, subject, and what students should bring (books/copies).',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_scheduleExists ? 'Update schedule' : 'Save all days', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _copyMondayToAllDays,
          icon: const Icon(Icons.content_copy),
          label: Text(
            'Apply Monday to all days',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20),
        for (final d in _dayOrder) ...[
          Text(d.$2, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.deepBlue)),
          const SizedBox(height: 8),
          for (var slot = 0; slot < 2; slot++) ...[
            Text(
              'Period ${slot + 1}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _days[d.$1]![slot].start,
                            decoration: const InputDecoration(labelText: 'Start (e.g. 9:00 AM)'),
                            inputFormatters: [LengthLimitingTextInputFormatter(24)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _days[d.$1]![slot].end,
                            decoration: const InputDecoration(labelText: 'End'),
                            inputFormatters: [LengthLimitingTextInputFormatter(24)],
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _days[d.$1]![slot].subject,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    TextField(
                      controller: _days[d.$1]![slot].bring,
                      decoration: const InputDecoration(
                        labelText: 'Bring today',
                        hintText: 'Books, copies, lab coat…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
