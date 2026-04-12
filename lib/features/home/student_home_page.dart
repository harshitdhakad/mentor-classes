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
import 'widgets/student_progress_widget.dart';

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
    final today = DateTime.now().toString().split(' ')[0];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('holidays')
          .where('date', isEqualTo: today)
          .where('classLevel', isEqualTo: classLevel)
          .snapshots(),
      builder: (context, holidaySnap) {
        final isHoliday = holidaySnap.hasData && holidaySnap.data!.docs.isNotEmpty;

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
          
          // Today's Attendance Status
          if (hasClass)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('classLevel', isEqualTo: user.studentClass)
                  .where('date', isEqualTo: DateTime.now().toString().split(' ')[0])
                  .snapshots(),
              builder: (context, snapshot) {
                try {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Text('Loading...'));
                  }
                  if (snapshot.hasError) {
                    debugPrint('Attendance stream error: ${snapshot.error}');
                    return const Center(child: Text('Error loading attendance'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Text(
                            'Attendance: Not Uploaded',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Check if current student is marked present or absent
                  final attendanceDoc = snapshot.data!.docs.first;
                  final data = attendanceDoc.data() as Map<String, dynamic>;
                  final records = data['records'] as Map<String, dynamic>?;
                  final isPresent = records != null && records[user.rollNumber] == true;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isPresent ? Colors.green.shade300 : Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Today: ${isPresent ? 'Present' : 'Absent'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isPresent ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  debugPrint('Attendance widget error: $e');
                  return const Center(child: Text('Error loading attendance'));
                }
              },
            ),
          if (hasClass) const SizedBox(height: 20),
          
          // Student's Own Fee Status
          if (hasClass)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .doc(user.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Text('Loading...'));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading fees'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final totalFees = (data['total_fees'] as num?)?.toDouble() ?? 0.0;
                final remainingFees = (data['remaining_fees'] as num?)?.toDouble() ?? totalFees;
                final paidFees = totalFees - remainingFees;
                final percentage = totalFees > 0 ? (paidFees / totalFees * 100).toInt() : 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fee Status',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: percentage == 100
                                  ? Colors.green
                                  : percentage > 50
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentage == 100
                              ? Colors.green
                              : percentage > 50
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paid: ₹${paidFees.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Pending: ₹${remainingFees.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: remainingFees > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          if (hasClass) const SizedBox(height: 20),
          
              // Today's Schedule & Week Schedule
              if (hasClass && !isHoliday) ...[
                const _ScheduleSection(),
                const SizedBox(height: 20),
              ],
          // Student Performance Graph
          if (hasClass)
            StudentProgressGraph(classLevel: user.studentClass!),
          if (hasClass) const SizedBox(height: 20),
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
                  child: Center(child: SizedBox.shrink()),
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

class _ScheduleSection extends ConsumerStatefulWidget {
  const _ScheduleSection();

  @override
  ConsumerState<_ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends ConsumerState<_ScheduleSection> {
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
  Widget build(BuildContext context) {
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
        // TODAY'S SCHEDULE CARD
        Text(
          'Today\'s Schedule',
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
                child: Center(child: SizedBox.shrink()),
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
                final bring = m['bring']?.toString() ?? '';
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (start.isNotEmpty && end.isNotEmpty)
                          Text('$start - $end', style: GoogleFonts.poppins(fontSize: 11)),
                        if (bring.isNotEmpty)
                          Text('Bring: $bring', style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),

        // FULL WEEK SCHEDULE CARD
        Text(
          'This Week\'s Schedule',
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
            if (!snap.hasData) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(height: 80, child: Center(child: SizedBox.shrink())),
                ),
              );
            }
            final data = snap.data?.data();
            final days = data?['days'] as Map<String, dynamic>?;
            if (days == null || days.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No week schedule available'),
                ),
              );
            }

            final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
            final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

            return Column(
              children: List.generate(7, (dayIndex) {
                final dayKey = dayKeys[dayIndex];
                final dayName = dayNames[dayIndex];
                final slots = days[dayKey] as List?;

                if (slots == null || slots.isEmpty) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          '$dayName - No classes',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      dayName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${slots.length} class${slots.length != 1 ? 'es' : ''}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    children: slots.asMap().entries.map((e) {
                      final slotIndex = e.key;
                      final raw = e.value;
                      if (raw is! Map) return const SizedBox.shrink();
                      final m = Map<String, dynamic>.from(raw.map((k, v) => MapEntry('$k', v)));
                      final subject = m['subject']?.toString() ?? '—';
                      final start = m['start']?.toString() ?? '';
                      final end = m['end']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.deepBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'P${slotIndex + 1}',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  if (start.isNotEmpty && end.isNotEmpty)
                                    Text('$start - $end', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 20),

        // SYLLABUS PROGRESS PREVIEW
        _SyllabusProgressPreview(),
      ],
    );
  }
}

/// Widget to show condensed Syllabus Progress Tracker
class _SyllabusProgressPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user?.studentClass == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('syllabus')
          .where('classLevel', isEqualTo: user!.studentClass)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading syllabus'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No syllabus data available')),
            ),
          );
        }

        // For now, show a simplified view since ClassSyllabus parsing is complex
        return Card(
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
                  'Syllabus Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Syllabus data available for Class ${user.studentClass}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
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
  Widget build(BuildContext context) {
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
                child: Center(child: SizedBox.shrink()),
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
