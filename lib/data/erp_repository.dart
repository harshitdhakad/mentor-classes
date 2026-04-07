import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/notifications/parent_notification_stub.dart';
import '../models/user_model.dart';

class StudentListItem {
  StudentListItem({
    required this.roll,
    required this.name,
    required this.docId,
    this.totalFees = 0.0,
    this.remainingFees = 0.0,
  });

  final String roll;
  final String name;
  final String docId;
  final double totalFees; // Total fees amount
  final double remainingFees; // Dues/remaining fees

  double get paidFees => (totalFees - remainingFees).clamp(0.0, totalFees);
}

/// One row on the leaderboard (NG = not given / absent for test).
class LeaderboardRow {
  LeaderboardRow({
    required this.roll,
    required this.rank,
    this.score,
    required this.isNg,
  });

  final String roll;
  final int rank;
  final double? score;
  final bool isNg;
}

class ErpRepository {
  ErpRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  CollectionReference<Map<String, dynamic>> get _students => _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _attendance => _db.collection('attendance');
  CollectionReference<Map<String, dynamic>> get _testMarks => _db.collection('test_marks');
  CollectionReference<Map<String, dynamic>> get _homework => _db.collection('homework');
  CollectionReference<Map<String, dynamic>> get _announcements => _db.collection('announcements');
  CollectionReference<Map<String, dynamic>> get _testSeries => _db.collection('test_series');

  CollectionReference<Map<String, dynamic>> get _schedules => _db.collection('schedules');

  DocumentReference<Map<String, dynamic>> weeklyScheduleDoc(int classLevel) =>
      _schedules.doc('$classLevel');

  CollectionReference<Map<String, dynamic>> get _classSchedules => _db.collection('class_schedules');
  CollectionReference<Map<String, dynamic>> get _testSchedules => _db.collection('test_schedules');
  /// Get updates by category
  Stream<QuerySnapshot<Map<String, dynamic>>> getUpdatesByCategory(String category, int classLevel) {
    return _announcements
        .where('type', isEqualTo: category)
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Add class schedule
  Future<void> addClassSchedule({
    required int classLevel,
    required String subject,
    required String time,
    required String teacher,
    required String room,
  }) async {
    await _classSchedules.add({
      'classLevel': classLevel,
      'subject': subject,
      'time': time,
      'teacher': teacher,
      'room': room,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get class schedules stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getClassSchedules(int classLevel) {
    return _classSchedules.where('classLevel', isEqualTo: classLevel).snapshots();
  }

  /// Schedule test
  Future<void> scheduleTest({
    required int classLevel,
    required String testName,
    required String date,
    required String time,
    required String syllabus,
    required double maxMarks,
  }) async {
    await _testSchedules.add({
      'classLevel': classLevel,
      'testName': testName,
      'date': date,
      'time': time,
      'syllabus': syllabus,
      'maxMarks': maxMarks,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification
    sendParentNotification(
      title: 'New Test Scheduled',
      body: '$testName for Class $classLevel on $date at $time',
      meta: {'class': '$classLevel', 'type': 'test'},
    );
  }

  /// Get test schedules stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getTestSchedules(int classLevel) {
    return _testSchedules.where('classLevel', isEqualTo: classLevel).snapshots();
  }

  /// Add holiday
  Future<void> addHoliday({
    required int classLevel,
    required String date,
    required String message,
  }) async {
    await _holidays.add({
      'classLevel': classLevel,
      'date': date,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });

    sendParentNotification(
      title: 'Holiday Declared',
      body: message,
      meta: {'class': '$classLevel', 'date': date, 'type': 'holiday'},
    );
  }

  /// Get holidays stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getHolidays(int classLevel) {
    return _holidays.where('classLevel', isEqualTo: classLevel).snapshots();
  }

  /// Update student fees (Admin/Teacher only). Calculates remaining_fees automatically.
  Future<void> updateStudentFees({
    required String studentDocId,
    required double totalFees,
    required double paidAmount,
  }) async {
    final remainingFees = (totalFees - paidAmount).clamp(0.0, totalFees);
    await _students.doc(studentDocId).set(
      {
        'total_fees': totalFees,
        'remaining_fees': remainingFees,
        'fees_updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Fetch single student with all fees data (for teacher detail view).
  Future<Map<String, dynamic>?> getStudentWithFees(String studentDocId) async {
    final doc = await _students.doc(studentDocId).get();
    return doc.data();
  }

  Future<List<StudentListItem>> fetchStudentsByClass(int classLevel) async {
    final snap = await _students.where('studentClass', isEqualTo: classLevel).get();
    final list = snap.docs.map(_mapStudentDoc).whereType<StudentListItem>().toList();
    list.sort((a, b) => a.roll.compareTo(b.roll));
    return list;
  }

  StudentListItem? _mapStudentDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final roll = (data['rollNumber'] ?? data['Roll Number'] ?? doc.id).toString();
    final name = (data['name'] ?? data['Name'] ?? 'Student').toString();
    if (roll.isEmpty) return null;
    
    final totalFees = _parseDouble(data['total_fees'] ?? data['totalFees'] ?? 0);
    final remainingFees = _parseDouble(data['remaining_fees'] ?? data['remainingFees'] ?? totalFees);
    
    return StudentListItem(
      roll: roll,
      name: name,
      docId: doc.id,
      totalFees: totalFees,
      remainingFees: remainingFees,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<Map<String, dynamic>?> getAttendanceForDay(int classLevel, DateTime date) async {
    final id = '${classLevel}_${dateKey(date)}';
    final doc = await _attendance.doc(id).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchAttendanceForDay(int classLevel, DateTime date) {
    final id = '${classLevel}_${dateKey(date)}';
    return _attendance.doc(id).snapshots().map((s) => s.data());
  }

  /// Saves daily attendance. Calls [sendParentNotification] when not a holiday.
  Future<void> saveAttendance({
    required int classLevel,
    required DateTime date,
    required bool isHoliday,
    String? holidayMessage,
    required Map<String, bool> presentByRoll,
    required String savedByEmail,
  }) async {
    final dk = dateKey(date);
    final id = '${classLevel}_$dk';
    await _attendance.doc(id).set(
      {
        'classLevel': classLevel,
        'dateKey': dk,
        'isHoliday': isHoliday,
        'holidayMessage': holidayMessage,
        'records': presentByRoll,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': savedByEmail,
      },
      SetOptions(merge: true),
    );

    if (isHoliday) {
      await postAnnouncement(
        title: 'Holiday · Class $classLevel',
        body: holidayMessage?.trim().isNotEmpty == true
            ? holidayMessage!.trim()
            : 'No class today (marked from attendance).',
        classLevel: classLevel,
        type: 'holiday',
      );
      sendParentNotification(
        title: 'Holiday — Class $classLevel',
        body: holidayMessage ?? 'Institute holiday today.',
        meta: {'date': dk, 'class': '$classLevel'},
      );
    } else {
      final absent = presentByRoll.entries.where((e) => !e.value).map((e) => e.key).toList();
      sendParentNotification(
        title: 'Attendance saved — Class $classLevel',
        body: absent.isEmpty
            ? 'All students marked present for $dk.'
            : 'Absent rolls: ${absent.join(", ")}',
        meta: {'date': dk, 'class': '$classLevel'},
      );
    }
  }

  /// Legacy single-test save (no NG) — forwards to [saveTestMarksExtended].
  Future<void> saveTestMarks({
    required int classLevel,
    required String testName,
    required DateTime date,
    required double maxMarks,
    required Map<String, double> marksByRoll,
    required String savedBy,
  }) {
    return saveTestMarksExtended(
      classLevel: classLevel,
      subject: 'General',
      topic: '—',
      testName: testName,
      testKind: 'single',
      seriesId: null,
      date: date,
      maxMarks: maxMarks,
      marksByRoll: marksByRoll,
      notGivenRolls: const [],
      savedBy: savedBy,
    );
  }

  /// Full test/series save with NG list, auto ranks, and parent notification.
  Future<void> saveTestMarksExtended({
    required int classLevel,
    required String subject,
    required String topic,
    required String testName,
    required String testKind,
    String? seriesId,
    required DateTime date,
    required double maxMarks,
    required Map<String, double> marksByRoll,
    required List<String> notGivenRolls,
    required String savedBy,
  }) async {
    final ngSet = notGivenRolls.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final rankByRoll = <String, int>{};
    final scored = marksByRoll.entries
        .where((e) => !ngSet.contains(e.key) && e.value.isFinite)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var currentRank = 1;
    for (var i = 0; i < scored.length; i++) {
      if (i > 0 && scored[i].value != scored[i - 1].value) {
        currentRank = i + 1;
      }
      rankByRoll[scored[i].key] = currentRank;
    }
    for (final r in ngSet) {
      rankByRoll[r] = 0;
    }

    final marksOut = <String, double>{};
    marksByRoll.forEach((k, v) {
      if (!ngSet.contains(k)) marksOut[k] = v;
    });

    await _testMarks.add({
      'classLevel': classLevel,
      'subject': subject.trim(),
      'topic': topic.trim(),
      'testName': testName.trim(),
      'testKind': testKind,
      'seriesId': ?seriesId,
      'dateKey': dateKey(date),
      'maxMarks': maxMarks,
      'marks': marksOut,
      'notGivenRolls': ngSet.toList(),
      'rankByRoll': rankByRoll.map((k, v) => MapEntry(k, v)),
      'createdBy': savedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    sendParentNotification(
      title: 'Marks published — Class $classLevel',
      body: '${subject.trim()} · ${testName.trim()} (${dateKey(date)})',
      meta: {'class': '$classLevel', 'subject': subject, 'kind': testKind},
    );
  }

  Future<String> createTestSeries({
    required String name,
    required int classLevel,
    required String subject,
    required List<String> topics,
    required String savedBy,
  }) async {
    final ref = await _testSeries.add({
      'name': name.trim(),
      'classLevel': classLevel,
      'subject': subject.trim(),
      'topics': topics.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'createdBy': savedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchSeriesForClass(int classLevel) async {
    final snap = await _testSeries.where('classLevel', isEqualTo: classLevel).get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['createdAt'] as Timestamp?;
        final tb = b.data()['createdAt'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
    return docs;
  }

  /// Moves all students in [fromClass] to next class; resets fee placeholder. Attendance history stays on old class keys.
  Future<int> promoteClassToNext(int fromClass) async {
    if (fromClass >= StudentClassLevels.max) {
      throw StateError('Cannot promote from Class $fromClass.');
    }
    final studs = await fetchStudentsByClass(fromClass);
    if (studs.isEmpty) return 0;

    const batchSize = 400;
    var total = 0;
    for (var i = 0; i < studs.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = studs.skip(i).take(batchSize);
      for (final s in chunk) {
        batch.update(_students.doc(s.docId), {
          'studentClass': fromClass + 1,
          'fees': {
            'sessionCleared': false,
            'sessionResetAt': FieldValue.serverTimestamp(),
            'note': 'New session after promotion from Class $fromClass',
          },
          'lastPromotion': {
            'fromClass': fromClass,
            'toClass': fromClass + 1,
            'at': FieldValue.serverTimestamp(),
          },
        });
      }
      await batch.commit();
      total += chunk.length;
    }
    return total;
  }

  static String weekdayKeyFromDate(DateTime d) {
    const keys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return keys[d.weekday - 1];
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchWeeklySchedule(int classLevel) {
    return weeklyScheduleDoc(classLevel).snapshots();
  }

  Future<void> saveWeeklySchedule(int classLevel, Map<String, dynamic> daysPayload) async {
    await weeklyScheduleDoc(classLevel).set(
      {
        'days': daysPayload,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getWeeklyScheduleDays(int classLevel) async {
    final s = await weeklyScheduleDoc(classLevel).get();
    final data = s.data();
    if (data == null) return null;
    final days = data['days'];
    return days is Map<String, dynamic> ? days : null;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchTestsForClass(int classLevel) async {
    final snap = await _testMarks.where('classLevel', isEqualTo: classLevel).get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['createdAt'] as Timestamp?;
        final tb = b.data()['createdAt'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
    return docs;
  }

  /// Sorted leaderboard: rank 1 = top score (ties share rank); NG at bottom.
  List<LeaderboardRow> leaderboardForTest(DocumentSnapshot<Map<String, dynamic>> testDoc) {
    final data = testDoc.data();
    if (data == null) return [];
    final raw = data['marks'];
    if (raw is! Map) return [];
    final ng = ((data['notGivenRolls'] as List?) ?? []).map((e) => e.toString()).toSet();

    final rolls = <String>{};
    for (final k in raw.keys) {
      rolls.add(k.toString());
    }
    rolls.addAll(ng);

    final scored = <MapEntry<String, double>>[];
    final ngRolls = <String>[];

    for (final roll in rolls) {
      if (ng.contains(roll)) {
        ngRolls.add(roll);
        continue;
      }
      final v = raw[roll];
      final score = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
      scored.add(MapEntry(roll, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));

    final rankByRoll = <String, int>{};
    var pos = 1;
    for (var i = 0; i < scored.length; i++) {
      if (i > 0 && scored[i].value != scored[i - 1].value) pos = i + 1;
      rankByRoll[scored[i].key] = pos;
    }
    for (final r in ngRolls) {
      rankByRoll[r] = 0;
    }

    final list = <LeaderboardRow>[];
    for (final e in scored) {
      list.add(LeaderboardRow(roll: e.key, rank: rankByRoll[e.key]!, score: e.value, isNg: false));
    }
    for (final r in ngRolls) {
      list.add(LeaderboardRow(roll: r, rank: 0, score: null, isNg: true));
    }
    return list;
  }

  /// Marks for one student across tests (skips NG).
  Future<List<(String label, String subject, double score, double max)>> marksHistoryForStudent({
    required int classLevel,
    required String roll,
  }) async {
    final tests = await fetchTestsForClass(classLevel);
    final out = <(String, String, double, double)>[];
    for (final d in tests) {
      final m = d.data();
      final ng = ((m['notGivenRolls'] as List?) ?? []).map((e) => e.toString()).toSet();
      if (ng.contains(roll)) continue;
      final marks = m['marks'];
      if (marks is! Map || !marks.containsKey(roll)) continue;
      final v = marks[roll];
      final score = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
      final max = (m['maxMarks'] is num) ? (m['maxMarks'] as num).toDouble() : 100.0;
      final sub = m['subject']?.toString() ?? 'General';
      final name = m['testName']?.toString() ?? 'Test';
      final topic = m['topic']?.toString();
      final label = topic != null && topic.isNotEmpty ? '$name · $topic' : name;
      out.add((label, sub, score, max));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  /// Average % across series tests per roll; returns sorted rolls (best first).
  Future<List<MapEntry<String, double>>> seriesOverallRanking({
    required String seriesId,
    required int classLevel,
  }) async {
    final snap = await _testMarks.where('classLevel', isEqualTo: classLevel).get();
    final docs = snap.docs.where((d) => d.data()['seriesId'] == seriesId).toList();
    if (docs.isEmpty) return [];

    final studs = await fetchStudentsByClass(classLevel);
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final s in studs) {
      sums[s.roll] = 0;
      counts[s.roll] = 0;
    }

    for (final d in docs) {
      final m = d.data();
      final max = (m['maxMarks'] is num) ? (m['maxMarks'] as num).toDouble() : 100.0;
      if (max <= 0) continue;
      final ng = ((m['notGivenRolls'] as List?) ?? []).map((e) => e.toString()).toSet();
      final marks = m['marks'];
      if (marks is! Map) continue;
      marks.forEach((k, v) {
        final roll = k.toString();
        if (ng.contains(roll)) return;
        final sc = (v is num) ? v.toDouble() : double.tryParse('$v');
        if (sc == null) return;
        sums[roll] = (sums[roll] ?? 0) + (100 * sc / max);
        counts[roll] = (counts[roll] ?? 0) + 1;
      });
    }

    final agg = <MapEntry<String, double>>[];
    sums.forEach((roll, rollSum) {
      final c = counts[roll] ?? 0;
      if (c == 0) return;
      agg.add(MapEntry(roll, rollSum / c));
    });
    agg.sort((a, b) => b.value.compareTo(a.value));
    return agg;
  }

  Future<void> saveHomework({
    required int classLevel,
    required String title,
    required String description,
    required String assignedBy,
    DateTime? assignedDate,
  }) async {
    final d = assignedDate ?? DateTime.now();
    await _homework.add({
      'classLevel': classLevel,
      'title': title.trim(),
      'description': description.trim(),
      'dateKey': dateKey(d),
      'assignedBy': assignedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchHomeworkForClassAndDate({
    required int classLevel,
    required String dateKeyStr,
  }) {
    return _homework.where('classLevel', isEqualTo: classLevel).snapshots().map(
          (s) => s.docs.where((d) => d.data()['dateKey'] == dateKeyStr).toList(),
        );
  }

  Future<void> postAnnouncement({
    required String title,
    required String body,
    int? classLevel,
    String type = 'info',
  }) async {
    await _announcements.add({
      'title': title.trim(),
      'body': body.trim(),
      'classLevel': classLevel,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAnnouncementsStream() {
    return _announcements.orderBy('createdAt', descending: true).limit(40).snapshots();
  }

  /// All attendance rows for [classLevel] (client-filter by month in UI if needed).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAttendanceForClass(
    int classLevel,
  ) async {
    final snap = await _attendance.where('classLevel', isEqualTo: classLevel).get();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> attendanceInMonth(
    int classLevel,
    DateTime anyDayInMonth,
  ) async {
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final end = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    final sk = dateKey(start);
    final ek = dateKey(end);
    final all = await fetchAttendanceForClass(classLevel);
    return all.where((d) {
      final dk = d.data()['dateKey'] as String?;
      if (dk == null) return false;
      return dk.compareTo(sk) >= 0 && dk.compareTo(ek) <= 0;
    }).toList()
      ..sort((a, b) {
        final da = a.data()['dateKey'] as String? ?? '';
        final db = b.data()['dateKey'] as String? ?? '';
        return da.compareTo(db);
      });
  }
}
