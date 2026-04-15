import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/parent_notification_stub.dart';
import '../features/staff/student_upload_repository.dart';
import '../models/academic_resource_model.dart';
import '../models/attendance_summary_model.dart';
import '../models/fees_analytics_model.dart';
import '../models/homework_model.dart';
import '../models/performance_analytics_model.dart';
import '../models/student_batch_model.dart';
import '../models/syllabus_tracker_model.dart';
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
  late final CollectionReference<Map<String, dynamic>> _users = _db.collection('users');

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  CollectionReference<Map<String, dynamic>> get _attendance => _db.collection('attendance');
  CollectionReference<Map<String, dynamic>> get _testMarks => _db.collection('test_marks');
  CollectionReference<Map<String, dynamic>> get _homework => _db.collection('homework');
  
  /// Get class-wise test marks subcollection reference: test_marks/{classLevel}/tests
  CollectionReference<Map<String, dynamic>> _classTestMarksRef(int classLevel) {
    return _testMarks.doc(classLevel.toString()).collection('tests');
  }
  
  /// Get class-wise homework subcollection reference: homework/{classLevel}/subjects/{subject}/current
  CollectionReference<Map<String, dynamic>> _classHomeworkRef(int classLevel, String subject) {
    return _homework.doc(classLevel.toString()).collection('subjects').doc(subject).collection('current');
  }
  CollectionReference<Map<String, dynamic>> get _announcements => _db.collection('announcements');
  CollectionReference<Map<String, dynamic>> get _testSeries => _db.collection('test_series');

  CollectionReference<Map<String, dynamic>> get _schedules => _db.collection('schedules');

  CollectionReference<Map<String, dynamic>> get _academicResources =>
      _db.collection('academic_resources');

  DocumentReference<Map<String, dynamic>> weeklyScheduleDoc(int classLevel) =>
      _schedules.doc('$classLevel');

  CollectionReference<Map<String, dynamic>> get _classSchedules => _db.collection('class_schedules');
  CollectionReference<Map<String, dynamic>> get _testSchedules => _db.collection('test_schedules');
  CollectionReference<Map<String, dynamic>> get _holidays => _db.collection('holidays');
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

  /// Check if a date is a holiday for a class
  Future<bool> isHoliday(int classLevel, String date) async {
    final querySnapshot = await _holidays
        .where('classLevel', isEqualTo: classLevel)
        .where('date', isEqualTo: date)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  /// Update student fees (Admin/Teacher only). Calculates remaining_fees automatically.
  Future<void> updateStudentFees({
    required String studentDocId,
    required double totalFees,
    required double paidAmount,
  }) async {
    final remainingFees = (totalFees - paidAmount).clamp(0.0, totalFees);
    await _users.doc(studentDocId).set(
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
    final doc = await _users.doc(studentDocId).get();
    return doc.data();
  }

  Future<List<StudentListItem>> fetchStudentsByClass(int classLevel) async {
    final snap = await _users.where('role', isEqualTo: 'student').where('studentClass', isEqualTo: classLevel).get();
    final list = snap.docs.map(_mapStudentDoc).whereType<StudentListItem>().toList();
    list.sort((a, b) => a.roll.compareTo(b.roll));
    return list;
  }

  StudentListItem? _mapStudentDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final roll = (data['rollNumber'] ?? doc.id).toString();
    final name = (data['displayName'] ?? 'Student').toString();
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

    debugPrint('📝 Saving test marks: classLevel=$classLevel, subject=$subject, testName=$testName');
    debugPrint('📝 Marks to save: ${marksOut.length} students, NG: ${ngSet.length}');

    // Save to class-wise subcollection: test_marks/{classLevel}/tests/{testId}
    await _classTestMarksRef(classLevel).add({
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

    debugPrint('✅ Test marks saved successfully to Firestore (test_marks/$classLevel)');

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
        batch.update(_users.doc(s.docId), {
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

  /// Get all test marks for a class (returns full QuerySnapshot)
  Future<QuerySnapshot<Map<String, dynamic>>> getTestMarksForClass(int classLevel) async {
    return _testMarks.where('classLevel', isEqualTo: classLevel).get();
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
    final expiryTime = DateTime.now().add(const Duration(hours: 24));
    await _homework.add({
      'classLevel': classLevel,
      'title': title.trim(),
      'description': description.trim(),
      'dateKey': dateKey(d),
      'assignedBy': assignedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiryTime': expiryTime,
    });
  }

  /// Save homework with file attachments
  Future<void> saveHomeworkWithAttachments({
    required int classLevel,
    required String title,
    required String description,
    required String assignedBy,
    required List<Map<String, String>> attachments,
    DateTime? assignedDate,
  }) async {
    final d = assignedDate ?? DateTime.now();
    final expiryTime = DateTime.now().add(const Duration(hours: 24));
    await _homework.add({
      'classLevel': classLevel,
      'title': title.trim(),
      'description': description.trim(),
      'dateKey': dateKey(d),
      'assignedBy': assignedBy,
      'attachments': attachments, // List of {fileName, url, fileType}
      'createdAt': FieldValue.serverTimestamp(),
      'expiryTime': expiryTime,
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

  // ====================== ACADEMIC RESOURCES ======================

  /// Upload a new academic resource
  Future<String> uploadAcademicResource({
    required AcademicResource resource,
  }) async {
    final docRef = await _academicResources.add(resource.toFirestore());
    return docRef.id;
  }

  /// Fetch resources filtered by class, subject, and resource type
  Future<List<AcademicResource>> fetchResourcesByFilter({
    required int classLevel,
    String? subject,
    String? resourceType,
  }) async {
    var query = _academicResources
        .where('classLevel', isEqualTo: classLevel)
        .where('isActive', isEqualTo: true);

    if (subject != null && subject.isNotEmpty) {
      query = query.where('subject', isEqualTo: subject);
    }
    if (resourceType != null && resourceType.isNotEmpty) {
      query = query.where('resourceType', isEqualTo: resourceType);
    }

    final snap = await query.orderBy('uploadedAt', descending: true).get();
    return snap.docs
        .map((doc) => AcademicResource.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  /// Stream resources for real-time updates
  Stream<List<AcademicResource>> watchResourcesByFilter({
    required int classLevel,
    String? subject,
    String? resourceType,
  }) {
    var query = _academicResources
        .where('classLevel', isEqualTo: classLevel)
        .where('isActive', isEqualTo: true);

    if (subject != null && subject.isNotEmpty) {
      query = query.where('subject', isEqualTo: subject);
    }
    if (resourceType != null && resourceType.isNotEmpty) {
      query = query.where('resourceType', isEqualTo: resourceType);
    }

    return query.orderBy('uploadedAt', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => AcademicResource.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  /// Get all unique subjects for a class
  Future<List<String>> getSubjectsForClass(int classLevel) async {
    final snap = await _academicResources
        .where('classLevel', isEqualTo: classLevel)
        .where('isActive', isEqualTo: true)
        .get();

    final subjects = <String>{};
    for (final doc in snap.docs) {
      final subject = doc.data()['subject'] as String?;
      if (subject != null) subjects.add(subject);
    }
    return subjects.toList()..sort();
  }

  /// Delete (deactivate) a resource
  Future<void> deleteResource(String resourceId) async {
    await _academicResources.doc(resourceId).update({'isActive': false});
  }

  // ====================== ENHANCED STUDENT MANAGEMENT ======================

  /// Add a student manually
  Future<String> addStudentManual({
    required int classLevel,
    required String rollNumber,
    required String name,
    String? password,
    required String? mobileContact,
    required String? emergencyContact,
    double totalFees = 0.0,
    String feesCriteria = 'Monthly',
  }) async {
    final docId = StudentUploadRepository.documentIdForRoll(rollNumber);

    // Save to users collection with password for login
    await _users.doc(docId).set({
      'id': docId,
      'displayName': name,
      'rollNumber': rollNumber,
      'studentClass': classLevel,
      'role': 'student',
      'password': password,
      'mobileNumber': mobileContact,
      'emergencyContact': emergencyContact,
      'total_fees': totalFees,
      'feesCriteria': feesCriteria,
      'remaining_fees': totalFees,
      'enrolledDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return docId;
  }

  /// Update student (for editing details)
  Future<void> updateStudent({
    required String studentDocId,
    required String name,
    required String rollNumber,
    String? mobileContact,
    String? emergencyContact,
  }) async {
    await _users.doc(studentDocId).update({
      'name': name,
      'rollNumber': rollNumber,
      'mobile_contact': mobileContact,
      'emergency_contact': emergencyContact,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove/deactivate a student - now deletes the document from Firestore
  Future<void> removeStudent(String studentDocId) async {
    await _users.doc(studentDocId).delete();
  }

  /// Reactivate a student
  Future<void> reactivateStudent(String studentDocId) async {
    await _users.doc(studentDocId).update({
      'active': true,
      'removedAt': FieldValue.delete(),
    });
  }

  /// Fetch enhanced student list for batch management
  Future<List<EnhancedStudentItem>> fetchStudentsByClassEnhanced(int classLevel) async {
    final snap = await _users
        .where('role', isEqualTo: 'student')
        .where('studentClass', isEqualTo: classLevel)
        .get();

    final list = <EnhancedStudentItem>[];
    int rowIndex = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final roll = (data['rollNumber'] ?? data['rollNo'] ?? data['roll']).toString();
      final name = (data['displayName'] ?? data['name'] ?? 'Student').toString();

      if (roll.isNotEmpty) {
        final totalFees = _parseDouble(data['total_fees'] ?? data['totalFees'] ?? 0);
        final remainingFees =
            _parseDouble(data['remaining_fees'] ?? data['remainingFees'] ?? totalFees);

        list.add(EnhancedStudentItem(
          rowIndex: rowIndex++,
          rollNumber: roll,
          name: name,
          docId: doc.id,
          classLevel: classLevel,
          totalFees: totalFees,
          remainingFees: remainingFees,
          enrolledDate: (data['enrolledDate'] as Timestamp?)?.toDate(),
          isActive: true,
          password: data['password'] as String?,
        ));
      }
    }

    list.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    return list;
  }

  /// Watch enhanced student list for batch management (real-time updates)
  Stream<List<EnhancedStudentItem>> watchStudentsByClassEnhanced(int classLevel) {
    return _users
        .where('role', isEqualTo: 'student')
        .where('studentClass', isEqualTo: classLevel)
        .snapshots()
        .map((snap) {
      final list = <EnhancedStudentItem>[];
      int rowIndex = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final roll = (data['rollNumber'] ?? data['rollNo'] ?? data['roll']).toString();
        final name = (data['displayName'] ?? data['name'] ?? 'Student').toString();

        if (roll.isNotEmpty) {
          final totalFees = _parseDouble(data['total_fees'] ?? data['totalFees'] ?? 0);
          final remainingFees =
              _parseDouble(data['remaining_fees'] ?? data['remainingFees'] ?? totalFees);

          list.add(EnhancedStudentItem(
            rowIndex: rowIndex++,
            rollNumber: roll,
            name: name,
            docId: doc.id,
            classLevel: classLevel,
            totalFees: totalFees,
            remainingFees: remainingFees,
            enrolledDate: (data['enrolledDate'] as Timestamp?)?.toDate(),
            isActive: true,
            password: data['password'] as String?,
          ));
        }
      }

      list.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      return list;
    });
  }

  // ====================== PERFORMANCE ANALYTICS ======================

  /// Fetch performance analytics for a specific student
  Future<StudentPerformanceAnalytics?> fetchStudentPerformanceAnalytics({
    required int classLevel,
    required String rollNumber,
    required String studentName,
  }) async {
    final marksSnap = await _classTestMarksRef(classLevel)
        .orderBy('createdAt', descending: true)
        .get();

    final testHistories = <StudentTestHistory>[];

    for (final docSnap in marksSnap.docs) {
      final data = docSnap.data();
      final marksByRoll = Map<String, dynamic>.from(data['marksByRoll'] as Map? ?? {});
      final percentageByRoll =
          Map<String, dynamic>.from(data['percentageByRoll'] as Map? ?? {});
      final ranksByRoll = Map<String, dynamic>.from(data['ranksByRoll'] as Map? ?? {});

      if (marksByRoll.containsKey(rollNumber)) {
        final marks = _parseDouble(marksByRoll[rollNumber]);
        final percentage = _parseDouble(percentageByRoll[rollNumber] ?? 0);
        final rank = (ranksByRoll[rollNumber] as num?)?.toInt() ?? 0;

        testHistories.add(StudentTestHistory(
          testId: docSnap.id,
          testName: (data['testName'] as String?) ?? 'Test',
          subject: (data['subject'] as String?) ?? 'General',
          topic: (data['topic'] as String?) ?? '—',
          testType: (data['testType'] as String?) ?? 'weekly',
          marksObtained: marks,
          maxMarks: _parseDouble(data['maxMarks'] ?? 100),
          percentage: percentage,
          classRank: rank,
          totalParticipants: (marksByRoll.length),
          testDate: ((data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
        ));
      }
    }

    if (testHistories.isEmpty) return null;

    return StudentPerformanceAnalytics(
      rollNumber: rollNumber,
      studentName: studentName,
      classLevel: classLevel,
      testHistories: testHistories,
    );
  }

  /// Fetch all test marks for a class with optional type filter
  Future<List<EnhancedTestMarks>> fetchTestMarksForClass({
    required int classLevel,
    String? testType,
    String? subject,
  }) async {
    var query = _testMarks.where('classLevel', isEqualTo: classLevel);

    if (testType != null && testType.isNotEmpty) {
      query = query.where('testType', isEqualTo: testType);
    }
    if (subject != null && subject.isNotEmpty) {
      query = query.where('subject', isEqualTo: subject);
    }

    final snap = await query.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((doc) => EnhancedTestMarks.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  // ====================== FEES ANALYTICS ======================

  /// Get complete fees analytics for admin dashboard
  Future<FeesAnalytics> getFeesAnalytics() async {
    try {
      final studentsSnap = await _users.where('role', isEqualTo: 'student').get();

      double totalCollected = 0;
      double totalPending = 0;
      int paidStudentsCount = 0;

      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final totalFees = _parseDouble(data['total_fees'] ?? data['totalFees'] ?? 0);
        final remainingFees = _parseDouble(data['remaining_fees'] ?? data['remainingFees'] ?? totalFees);
        final paidFees = totalFees - remainingFees;

        totalCollected += paidFees;
        totalPending += remainingFees;

        if (remainingFees == 0 && paidFees > 0) {
          paidStudentsCount++;
        }
      }

      return FeesAnalytics(
        totalCollected: totalCollected,
        totalPending: totalPending,
        totalStudents: studentsSnap.size,
        paidStudentsCount: paidStudentsCount,
        classwiseBreakdown: [],
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error fetching fees analytics: $e');
      rethrow;
    }
  }

  /// Mark a student's fees as paid
  Future<void> markStudentFeesPaid(String studentDocId) async {
    try {
      await _users.doc(studentDocId).update({
        'feesPaid': true,
        'feesPaidAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error marking student fees as paid: $e');
      rethrow;
    }
  }

  /// Create/get class syllabus
  Future<ClassSyllabus> getClassSyllabus(int classLevel) async {
    try {
      final doc = await _db.collection('syllabus').doc('class_$classLevel').get();

      if (doc.exists) {
        return ClassSyllabus.fromFirestore(doc.data() ?? {}, doc.id);
      }
      
      // Create empty syllabus if doesn't exist
      final emptySyllabus = ClassSyllabus(
        docId: 'class_$classLevel',
        classLevel: classLevel,
        subjects: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.collection('syllabus').doc('class_$classLevel').set(emptySyllabus.toFirestore());
      return emptySyllabus;
    } catch (e) {
      debugPrint('Error fetching syllabus: $e');
      rethrow;
    }
  }

  /// Add a chapter to a subject in class syllabus
  Future<void> addChapterToSyllabus({
    required int classLevel,
    required String subjectName,
    required String title,
    int? chapterNumber,
  }) async {
    try {
      final syllabusRef = _db.collection('syllabus').doc('class_$classLevel');
      final current = await syllabusRef.get();
      final data = current.data() ?? {};

      final subjects = Map<String, dynamic>.from(data['subjects'] as Map? ?? {});

      if (!subjects.containsKey(subjectName)) {
        subjects[subjectName] = {
          'subjectId': subjectName.toLowerCase().replaceAll(' ', '_'),
          'subjectName': subjectName,
          'classLevel': classLevel,
          'chapters': [],
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'createdBy': '',
        };
      }

      final subject = Map<String, dynamic>.from(subjects[subjectName] as Map);
      final chapters = List<Map<String, dynamic>>.from(subject['chapters'] as List? ?? []);

      chapters.add({
        'title': title,
        'chapterNumber': chapterNumber,
        'isCompleted': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      subject['chapters'] = chapters;
      subject['updatedAt'] = DateTime.now();
      subjects[subjectName] = subject;

      await syllabusRef.update({
        'subjects': subjects,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error adding chapter: $e');
      rethrow;
    }
  }

  /// Add a subject to class syllabus
  Future<void> addSubjectToSyllabus({
    required int classLevel,
    required String subjectName,
  }) async {
    try {
      final syllabusRef = _db.collection('syllabus').doc('class_$classLevel');
      final current = await syllabusRef.get();
      final data = current.data() ?? {};

      final subjects = Map<String, dynamic>.from(data['subjects'] as Map? ?? {});

      if (subjects.containsKey(subjectName)) {
        throw Exception('Subject already exists');
      }

      subjects[subjectName] = {
        'subjectId': subjectName.toLowerCase().replaceAll(' ', '_'),
        'subjectName': subjectName,
        'classLevel': classLevel,
        'chapters': [],
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'createdBy': '',
      };

      await syllabusRef.update({
        'subjects': subjects,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error adding subject: $e');
      rethrow;
    }
  }

  /// Toggle chapter completion status
  Future<void> toggleChapterCompletion({
    required int classLevel,
    required String subjectName,
    required String chapterId,
    required bool isCompleted,
  }) async {
    try {
      final syllabusRef = _db.collection('syllabus').doc('class_$classLevel');
      final current = await syllabusRef.get();
      final data = current.data() ?? {};
      
      final subjects = Map<String, dynamic>.from(data['subjects'] as Map? ?? {});
      final subject = Map<String, dynamic>.from(subjects[subjectName] as Map? ?? {});
      final chapters = List<Map<String, dynamic>>.from(subject['chapters'] as List? ?? []);
      
      if (int.tryParse(chapterId) != null) {
        final idx = int.parse(chapterId);
        if (idx < chapters.length) {
          chapters[idx]['isCompleted'] = isCompleted;
          if (isCompleted) {
            chapters[idx]['completedDate'] = DateTime.now();
          }
        }
      }
      
      subject['chapters'] = chapters;
      subject['updatedAt'] = DateTime.now();
      subjects[subjectName] = subject;
      
      await syllabusRef.update({
        'subjects': subjects,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error updating chapter: $e');
      rethrow;
    }
  }

  /// Remove chapter from syllabus
  Future<void> removeChapterFromSyllabus({
    required int classLevel,
    required String subjectName,
    required String chapterId,
  }) async {
    try {
      final syllabusRef = _db.collection('syllabus').doc('class_$classLevel');
      final current = await syllabusRef.get();
      final data = current.data() ?? {};
      
      final subjects = Map<String, dynamic>.from(data['subjects'] as Map? ?? {});
      final subject = Map<String, dynamic>.from(subjects[subjectName] as Map? ?? {});
      final chapters = List<Map<String, dynamic>>.from(subject['chapters'] as List? ?? []);
      
      if (int.tryParse(chapterId) != null) {
        final idx = int.parse(chapterId);
        if (idx < chapters.length) {
          chapters.removeAt(idx);
        }
      }
      
      subject['chapters'] = chapters;
      subject['updatedAt'] = DateTime.now();
      subjects[subjectName] = subject;
      
      await syllabusRef.update({
        'subjects': subjects,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error removing chapter: $e');
      rethrow;
    }
  }

  /// ADMIN ONLY: Reset all application data
  /// [deleteStudents] if true, deletes all student data; if false, preserves student data
  Future<void> resetAllData({bool deleteStudents = true}) async {
    debugPrint('🚨 Starting complete data reset... (deleteStudents: $deleteStudents)');

    try {
      // Set flag to trigger persistence clearing on next app start
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_reset_timestamp', DateTime.now().millisecondsSinceEpoch);
      debugPrint('🔄 Admin reset flag set for persistence clearing');

      // Delete all collections except students if deleteStudents is false
      final collections = [
        if (deleteStudents) 'users', // Main user collection
        if (deleteStudents) 'students', // Student-specific collection
        'attendance',
        'test_marks', // Fixed collection name
        'testMarks', // Legacy collection name
        'announcements',
        'homework',
        'schedules',
        'schedule', // Legacy collection name
        'academic_resources',
        'academicResources', // Legacy collection name
        'test_series',
        'testSeries', // Legacy collection name
        'class_schedules',
        'test_schedules',
        'holidays',
        'syllabus',
        'chapters',
      ];

      for (final collectionName in collections) {
        try {
          debugPrint('Deleting collection: $collectionName');
          final batch = _db.batch();
          final docs = await _db.collection(collectionName).get();

          for (final doc in docs.docs) {
            batch.delete(doc.reference);
          }

          if (docs.docs.isNotEmpty) {
            await batch.commit();
            debugPrint('✅ Deleted ${docs.docs.length} documents from $collectionName');
          } else {
            debugPrint('ℹ️ Collection $collectionName was empty');
          }
        } catch (e) {
          debugPrint('⚠️ Error deleting collection $collectionName: $e');
          // Continue with other collections even if one fails
        }
      }

      debugPrint('✅ All data reset successfully');
    } catch (e) {
      debugPrint('❌ Error during reset: $e');
      rethrow;
    }
  }

  /// Get class-wide performance summary
  Future<List<StudentPerformanceSummary>> fetchClassPerformanceSummary(int classLevel) async {
    // Fetch all students in class
    final students = await fetchStudentsByClass(classLevel);

    // Fetch latest 10 tests for this class
    final testSnap = await _testMarks
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    final summaries = <String, StudentPerformanceSummary>{};

    // Initialize summaries for all students
    for (final student in students) {
      summaries[student.roll] = StudentPerformanceSummary(
        rollNumber: student.roll,
        name: student.name,
        classLevel: classLevel,
      );
    }

    // Calculate scores from tests
    for (final testDoc in testSnap.docs) {
      final data = testDoc.data();
      final percentageByRoll = Map<String, dynamic>.from(data['percentageByRoll'] as Map? ?? {});
      final ranksByRoll = Map<String, dynamic>.from(data['ranksByRoll'] as Map? ?? {});

      for (final entry in percentageByRoll.entries) {
        final roll = entry.key;
        final percentage = _parseDouble(entry.value);
        final rank = (ranksByRoll[roll] as num?)?.toInt();

        if (summaries.containsKey(roll)) {
          final current = summaries[roll]!;
          final summary = StudentPerformanceSummary(
            rollNumber: roll,
            name: current.name,
            classLevel: classLevel,
            lastTestScore: percentage,
            lastTestPercentage: percentage,
            averagePercentage: ((current.averagePercentage ?? 0) + percentage) / 2,
            classRank: rank,
            testsGiven: current.testsGiven + 1,
          );
          summaries[roll] = summary;
        }
      }
    }

    return summaries.values.toList()
      ..sort((a, b) {
        final aAvg = a.averagePercentage ?? 0;
        final bAvg = b.averagePercentage ?? 0;
        return bAvg.compareTo(aAvg); // Descending
      });
  }

  /// Stream class performance summary for real-time updates
  Stream<List<StudentPerformanceSummary>> watchClassPerformanceSummary(int classLevel) {
    return _testMarks
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) => fetchClassPerformanceSummary(classLevel));
  }

  // ====================== ATTENDANCE SUMMARY SECTION ======================

  /// Fetch attendance summary for a student over date range (defaults to this academic year)
  Future<AttendanceSummary> getStudentAttendanceSummary({
    required int classLevel,
    required String rollNumber,
    required String studentName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Default to academic year (April to March)
    final now = DateTime.now();
    final academicStart = DateTime(
      now.month >= 4 ? now.year : now.year - 1,
      4,
      1,
    );
    final academicEnd = DateTime(
      now.month >= 4 ? now.year + 1 : now.year,
      3,
      31,
    );

    final start = startDate ?? academicStart;
    final end = endDate ?? academicEnd;

    final snapshot = await _db
        .collection('attendance')
        .where('classLevel', isEqualTo: classLevel)
        .get();

    int totalWorkingDays = 0;
    int presentDays = 0;
    int holidayCount = 0;
    final monthlyBreakdown = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      // Check if within date range
      if (date.isBefore(start) || date.isAfter(end)) continue;

      final isHoliday = data['isHoliday'] as bool? ?? false;

      if (isHoliday) {
        holidayCount++;
        continue;
      }

      totalWorkingDays++;

      // Check if student is present
      final records = data['records'] as Map<String, dynamic>?;
      if (records != null && records[rollNumber] == true) {
        presentDays++;

        // Track monthly breakdown
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthlyBreakdown[monthKey] = (monthlyBreakdown[monthKey] ?? 0) + 1;
      }
    }

    final attendancePercentage = totalWorkingDays > 0
        ? (presentDays / totalWorkingDays) * 100
        : 0.0;

    final absentDays = totalWorkingDays - presentDays;

    return AttendanceSummary(
      rollNumber: rollNumber,
      studentName: studentName,
      classLevel: classLevel,
      totalWorkingDays: totalWorkingDays,
      presentDays: presentDays,
      absentDays: absentDays,
      holidayCount: holidayCount,
      attendancePercentage: attendancePercentage,
      startDate: start,
      endDate: end,
      monthlyBreakdown: monthlyBreakdown,
    );
  }

  /// Fetch attendance records for a specific month
  Future<List<AttendanceRecord>> getMonthAttendanceRecords(
    int classLevel,
    DateTime month,
  ) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = month.month == 12
        ? DateTime(month.year + 1, 1, 0)
        : DateTime(month.year, month.month + 1, 0);

    final snapshot = await _db
        .collection('attendance')
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('date', descending: false)
        .get();

    final records = <AttendanceRecord>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      if (date.isBefore(startOfMonth) || date.isAfter(endOfMonth)) continue;

      records.add(AttendanceRecord.fromFirestore(data));
    }

    return records;
  }

  /// Get all attendance records for class
  Future<List<AttendanceRecord>> getClassAttendanceRecords(int classLevel) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classLevel', isEqualTo: classLevel)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc.data()))
        .toList();
  }

  // ====================== HOMEWORK MODULE (NEW STRUCTURE) ======================

  /// Save/Update homework for a class and subject (overwrites existing 'current')
  /// Save homework for a specific class and subject
  Future<void> saveHomeworkForClassAndSubject({
    required int classLevel,
    required String subject,
    required String textContent,
    required List<String> imageUrls,
    required List<Map<String, dynamic>> attachments,
    required String assignedBy,
  }) async {
    try {
      debugPrint('📝 Saving homework: classLevel=$classLevel, subject=$subject');
      
      // Ensure class document exists
      final classDocRef = _homework.doc(classLevel.toString());
      final classDoc = await classDocRef.get();
      if (!classDoc.exists) {
        await classDocRef.set({
          'classLevel': classLevel,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created class document for class $classLevel');
      }
      
      // Ensure subject document exists
      final subjectDocRef = classDocRef.collection('subjects').doc(subject);
      final subjectDoc = await subjectDocRef.get();
      if (!subjectDoc.exists) {
        await subjectDocRef.set({
          'subject': subject,
          'classLevel': classLevel,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created subject document for $subject');
      }
      
      final homeworkRef = _classHomeworkRef(classLevel, subject);
      final currentDocRef = homeworkRef.doc('current');

      final homeworkData = {
        'classLevel': classLevel,
        'subject': subject,
        'textContent': textContent,
        'imageUrls': imageUrls,
        'attachments': attachments,
        'assignedBy': assignedBy,
        'assignedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'expiryTime': DateTime.now().add(const Duration(hours: 24)),
      };

      debugPrint('📝 Homework data: textContent length=${textContent.length}, images=${imageUrls.length}, attachments=${attachments.length}');

      // This overwrites any existing 'current' document for this class+subject
      await currentDocRef.set(homeworkData);

      debugPrint('✅ Homework saved successfully to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving homework: $e');
      rethrow;
    }
  }

  /// Fetch current homework for a specific class and subject
  Future<HomeWorkAssignment?> getHomeworkForClassAndSubject({
    required int classLevel,
    required String subject,
  }) async {
    try {
      final homeworkRef = _classHomeworkRef(classLevel, subject);
      final currentSnapshot = await homeworkRef.get();
      
      if (currentSnapshot.docs.isEmpty) return null;
      
      // Get the most recent homework document from the current subcollection
      final latestDoc = currentSnapshot.docs.first;
      return HomeWorkAssignment.fromMap(subject, latestDoc.data());
    } catch (e) {
      debugPrint('❌ Error fetching homework: $e');
      return null;
    }
  }

  /// Stream homework for a class (all subjects)
  Stream<Map<String, HomeWorkAssignment>> watchHomeworkForClass(
    int classLevel,
  ) {
    debugPrint('📖 Starting homework stream for class $classLevel');
    return _homework.doc(classLevel.toString()).snapshots().asyncMap((classDoc) async {
      if (!classDoc.exists) {
        debugPrint('❌ Homework document does not exist for class $classLevel');
        return {};
      }

      debugPrint('✅ Homework document exists for class $classLevel');

      try {
        final homeworkMap = <String, HomeWorkAssignment>{};
        final subjects = ['Maths', 'Science', 'SST', 'English'];

        for (final subject in subjects) {
          final homeworkRef = _classHomeworkRef(classLevel, subject);
          final currentSnapshot = await homeworkRef.get();
          
          if (currentSnapshot.docs.isNotEmpty) {
            // Get the most recent homework document from the current subcollection
            final latestDoc = currentSnapshot.docs.first;
            debugPrint('✅ Found homework for subject: $subject');
            final hw = HomeWorkAssignment.fromMap(subject, latestDoc.data());
            homeworkMap[subject] = hw;
          } else {
            debugPrint('⚠️ No homework found for subject: $subject');
          }
        }

        debugPrint('📖 Returning ${homeworkMap.length} homework entries for class $classLevel');
        return homeworkMap;
      } catch (e) {
        debugPrint('❌ Error streaming homework: $e');
        return {};
      }
    });
  }

  /// Get all homework subjects for a class
  Future<List<String>> getHomeworkSubjectsForClass(int classLevel) async {
    try {
      // Return known subjects instead of trying to list collections (deprecated in Firebase)
      return ['Maths', 'Science', 'SST', 'English'];
    } catch (e) {
      debugPrint('❌ Error fetching homework subjects: $e');
      return [];
    }
  }

  /// Delete homework for a specific class and subject
  Future<void> deleteHomeworkForClassAndSubject({
    required int classLevel,
    required String subject,
  }) async {
    try {
      final homeworkRef = _classHomeworkRef(classLevel, subject);
      final currentSnapshot = await homeworkRef.get();
      
      // Delete all documents in the current subcollection
      for (final doc in currentSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('❌ Error deleting homework: $e');
      rethrow;
    }
  }
}
