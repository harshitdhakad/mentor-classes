import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../data/erp_repository.dart';
import '../../data/ncert_topics_placeholder.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Student home: welcome, NCERT placeholders, latest notices.
class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null || user.role != UserRole.student) return const SizedBox.shrink();

    final hasClass = StudentClassLevels.isValid(user.studentClass);
    final classLevel = hasClass ? user.studentClass! : StudentClassLevels.min;
    final welcome = hasClass ? 'Welcome to Class ${user.studentClass}' : 'Welcome, ${user.displayName}';
    final sections = NcertTopicsPlaceholder.topicsForClass(classLevel);
    final repo = ref.watch(erpRepositoryProvider);

    return FutureBuilder<bool>(
      future: repo.isHoliday(classLevel, DateTime.now().toString().split(' ')[0]),
      builder: (context, holidaySnap) {
        final isHoliday = holidaySnap.data ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isHoliday) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warningOrange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.celebration, color: AppTheme.warningOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Holiday Today',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.deepBlue, AppTheme.deepBlueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  welcome,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.rollNumber != null ? 'Roll ${user.rollNumber}' : '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
              // Today's Schedule
              if (hasClass && !isHoliday) ...[
                const _TodaysSchedule(),
                const SizedBox(height: 20),
              ],
          Text(
            'Latest notices',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.watchAnnouncementsStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Working Offline - Changes will sync later.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                );
              }
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Text(
                  'No announcements yet.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                );
              }
              final docs = snap.data!.docs.where((d) {
                final c = d.data()['classLevel'];
                if (c == null) return true;
                if (!hasClass) return false;
                return c == user.studentClass;
              }).take(4);
              final list = docs.toList();
              if (list.isEmpty) {
                return Text(
                  'No class-specific notices.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                );
              }
              return Column(
                children: list.map((d) {
                  final data = d.data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Icon(
                        data['type'] == 'holiday' ? Icons.beach_access : Icons.campaign_outlined,
                        color: AppTheme.deepBlue,
                      ),
                      title: Text(
                        data['title']?.toString() ?? '',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        data['body']?.toString() ?? '',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'NCERT topics (placeholders)',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...sections.map((s) => _TopicCard(section: s)),
        ],
      ),
    );
      },
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.section});

  final NcertTopicSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.subject,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 8),
            ...section.topics.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· ', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.deepBlue, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(t, style: GoogleFonts.poppins(fontSize: 13, height: 1.35))),
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

class _TodaysSchedule extends ConsumerStatefulWidget {
  const _TodaysSchedule();

  @override
  ConsumerState<_TodaysSchedule> createState() => _TodaysScheduleState();
}

class _TodaysScheduleState extends ConsumerState<_TodaysSchedule> {
  late DateTime _currentDay;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _currentDay = DateTime.now();
  }

  void _checkDayChange(WidgetRef ref) {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.day != _currentDay.day || now.month != _currentDay.month || now.year != _currentDay.year) {
      setState(() {
        _currentDay = now;
        _updateStream(ref);
      });
    }
    Future.delayed(const Duration(minutes: 1), () => _checkDayChange(ref));
  }

  void _updateStream(WidgetRef ref) {
    final user = ref.read(authProvider);
    if (user?.studentClass != null) {
      _stream = ref.read(erpRepositoryProvider).watchWeeklySchedule(user!.studentClass!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user?.studentClass == null) return const SizedBox.shrink();

    // Initialize stream if not set
    if (_stream == null) {
      _updateStream(ref);
    }

    // Start timer if not started
    if (!_timerStarted) {
      _timerStarted = true;
      Future.delayed(const Duration(minutes: 1), () => _checkDayChange(ref));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Classes',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Working Offline - Changes will sync later.',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snap.data?.data();
            final days = data?['days'];
            if (days is! Map<String, dynamic>) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No schedule available'),
                ),
              );
            }
            final now = DateTime.now();
            final key = ErpRepository.weekdayKeyFromDate(now);
            final slots = days[key];
            if (slots is! List || slots.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No classes today'),
                ),
              );
            }
            return Column(
              children: slots.asMap().entries.map((e) {
                final i = e.key;
                final raw = e.value;
                if (raw is! Map) return const SizedBox.shrink();
                final m = Map<String, dynamic>.from(raw.map((k, v) => MapEntry('$k', v)));
                final subject = m['subject']?.toString() ?? '—';
                final start = m['start']?.toString() ?? '';
                final end = m['end']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.deepBlue.withValues(alpha: 0.1),
                      child: Text('${i + 1}', style: GoogleFonts.poppins(color: AppTheme.deepBlue, fontWeight: FontWeight.w600)),
                    ),
                    title: Text(subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: start.isNotEmpty && end.isNotEmpty ? Text('$start - $end', style: GoogleFonts.poppins(fontSize: 12)) : null,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
