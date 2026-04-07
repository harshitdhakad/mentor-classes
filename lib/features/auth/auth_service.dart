import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../../models/user_model.dart';

// ——— Exceptions ———

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ——— Service ———

class AuthService {
  AuthService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection('students');

  /// Validates [email] + [password] against [AppConfig] for the selected staff [role].
  Future<AppUser> loginStaff({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    if (role != UserRole.admin && role != UserRole.teacher) {
      throw AuthException('Use student login for learners.');
    }

    final key = email.trim().toLowerCase();
    final Map<String, String> map =
        role == UserRole.admin ? AppConfig.adminAccounts : AppConfig.teacherAccounts;

    final expected = map[key];
    if (expected == null || expected.trim() != password.trim()) {
      throw AuthException('Invalid email or password.');
    }

    return AppUser(
      id: key,
      role: role,
      displayName: AppConfig.staffDisplayName(key),
      email: key,
      studentClass: null,
    );
  }

  /// Validates roll number + class + password against Firestore `students` documents.
  Future<AppUser> loginStudent({
    required String rollNumber,
    required int classLevel,
    required String password,
  }) async {
    final roll = rollNumber.trim();
    if (roll.isEmpty) {
      throw AuthException('Please enter your roll number.');
    }

    final doc = await _findStudentDocument(roll, classLevel);
    if (doc == null) {
      throw AuthException('Student with this roll and class not found.');
    }

    final data = doc.data() ?? {};
    final stored = _readPasswordFromStudent(data);
    if (stored.isEmpty) {
      throw AuthException('Student record has no password set. Contact admin.');
    }
    if (stored != password.trim()) {
      throw AuthException('Incorrect password.');
    }

    final name = _readNameFromStudent(data, roll);
    return AppUser(
      id: doc.id,
      role: UserRole.student,
      displayName: name,
      rollNumber: _readRollFromStudent(data, roll),
      studentClass: _readStudentClassFromStudent(data),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findStudentDocument(
    String roll,
    int classLevel,
  ) async {
    Future<QuerySnapshot<Map<String, dynamic>>> q(
      String field,
      Object value,
    ) async =>
        _students
            .where(field, isEqualTo: value)
            .where('studentClass', isEqualTo: classLevel)
            .limit(1)
            .get();

    final byRollNumber = await q('rollNumber', roll);
    if (byRollNumber.docs.isNotEmpty) return byRollNumber.docs.first;

    final byRollField = await q('Roll Number', roll);
    if (byRollField.docs.isNotEmpty) return byRollField.docs.first;

    final byLegacy = await q('roll_no', roll);
    if (byLegacy.docs.isNotEmpty) return byLegacy.docs.first;

    final byShort = await q('roll', roll);
    if (byShort.docs.isNotEmpty) return byShort.docs.first;

    final numeric = int.tryParse(roll);
    if (numeric != null) {
      final asInt = await q('rollNumber', numeric);
      if (asInt.docs.isNotEmpty) return asInt.docs.first;
      final asInt2 = await q('Roll Number', numeric);
      if (asInt2.docs.isNotEmpty) return asInt2.docs.first;
    }

    final direct = await _students.doc('${classLevel}_$roll').get();
    if (direct.exists) return direct;

    return null;
  }

  static String _readPasswordFromStudent(Map<String, dynamic> data) {
    final dynamic v =
        data['Password'] ?? data['password'] ?? data['studentPassword'];
    if (v == null) return '';
    return v.toString().trim();
  }

  static String _readNameFromStudent(Map<String, dynamic> data, String fallback) {
    final dynamic v = data['name'] ?? data['Name'] ?? data['fullName'];
    if (v == null || v.toString().trim().isEmpty) return 'Student';
    return v.toString().trim();
  }

  static String _readRollFromStudent(Map<String, dynamic> data, String fallback) {
    final dynamic v =
        data['rollNumber'] ?? data['Roll Number'] ?? data['roll'] ?? data['roll_no'];
    if (v == null) return fallback;
    return v.toString();
  }

  /// Reads class 5–10 from common Firestore / Excel column names.
  static int? _readStudentClassFromStudent(Map<String, dynamic> data) {
    final dynamic v = data['studentClass'] ??
        data['class'] ??
        data['Class'] ??
        data['student_class'] ??
        data['Student Class'] ??
        data['grade'] ??
        data['Grade'];
    if (v == null) return null;
    final int? n = v is int ? v : int.tryParse(v.toString().trim());
    if (n == null) return null;
    if (n >= StudentClassLevels.min && n <= StudentClassLevels.max) return n;
    return null;
  }

  static const String _prefsKey = 'mentor_classes_user';

  static Future<void> persistUser(AppUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(_prefsKey, jsonEncode(user.toJson()));
  }

  static Future<AppUser?> restoreSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromJson(data);
    } catch (_) {
      await prefs.remove(_prefsKey);
      return null;
    }
  }
}

// ——— Riverpod ———

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  Future<void> signInStaff({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    final service = ref.read(authServiceProvider);
    final user = await service.loginStaff(role: role, email: email, password: password);
    state = user;
    await AuthService.persistUser(user);
  }

  Future<void> signInStudent({
    required String rollNumber,
    required int classLevel,
    required String password,
  }) async {
    final service = ref.read(authServiceProvider);
    final user = await service.loginStudent(
      rollNumber: rollNumber,
      classLevel: classLevel,
      password: password,
    );
    state = user;
    await AuthService.persistUser(user);
  }

  Future<void> restoreSession(AppUser user) async {
    state = user;
    await AuthService.persistUser(user);
  }

  Future<void> signOut() async {
    state = null;
    await AuthService.persistUser(null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
