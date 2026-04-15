/// Valid CBSE class levels for multi-class ERP support (1–12).
abstract final class StudentClassLevels {
  static const int min = 1;
  static const int max = 12;

  static bool isValid(int? value) =>
      value != null && value >= min && value <= max;
}

/// Staff vs learner roles.
enum UserRole {
  admin,
  teacher,
  student,
}

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.teacher => 'Teacher',
        UserRole.student => 'Student',
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.displayName,
    this.email,
    this.rollNumber,
    this.studentClass,
  });

  /// Stable id: staff email (lowercase) or Firestore document id for students.
  final String id;
  final UserRole role;
  final String displayName;
  final String? email;
  final String? rollNumber;

  /// CBSE class (5–10) for students from Firestore; always null for staff.
  final int? studentClass;

  bool get isStaff => role == UserRole.admin || role == UserRole.teacher;

  /// e.g. "Class 9" when [studentClass] is valid; otherwise null.
  String? get studentClassLabel {
    if (!StudentClassLevels.isValid(studentClass)) return null;
    return 'Class $studentClass';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'displayName': displayName,
        'email': email,
        'rollNumber': rollNumber,
        'studentClass': studentClass,
      };

  static AppUser? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final roleValue = json['role']?.toString();
    if (roleValue == null) return null;
    final role = UserRole.values.firstWhere(
      (value) => value.name == roleValue,
      orElse: () => UserRole.student,
    );
    return AppUser(
      id: json['id']?.toString() ?? '',
      role: role,
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString(),
      rollNumber: json['rollNumber']?.toString(),
      studentClass: json['studentClass'] is int ? json['studentClass'] as int : int.tryParse(json['studentClass']?.toString() ?? ''),
    );
  }
}
