import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_excel_parser.dart';

class StudentUploadRepository {
  StudentUploadRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static String documentIdForRoll(String rollNo) {
    var s = rollNo.trim();
    if (s.isEmpty) {
      return 'student_${DateTime.now().microsecondsSinceEpoch}';
    }
    s = s.replaceAll(RegExp(r'[/\\\s]+'), '_');
    if (s.length > 700) s = s.substring(0, 700);
    return s;
  }

  /// Writes [rows] to `users` with mandatory fields: name, rollNo, class, role, fees, feesCriteria.
  /// Also saves to `students` collection for backward compatibility.
  Future<int> uploadRows(List<ParsedStudentRow> rows) async {
    if (rows.isEmpty) return 0;

    const chunk = 450;
    var written = 0;
    for (var i = 0; i < rows.length; i += chunk) {
      final batch = _db.batch();
      final part = rows.skip(i).take(chunk);
      for (final row in part) {
        final docId = documentIdForRoll(row.rollNo);

        // Save to users collection with mandatory fields including password for login
        final userRef = _db.collection('users').doc(docId);
        batch.set(
          userRef,
          {
            'id': docId,
            'displayName': row.name,
            'rollNumber': row.rollNo,
            'studentClass': row.classLevel,
            'role': 'student',
            'password': row.password,
            'total_fees': row.fees,
            'feesCriteria': row.feesCriteria,
            'remaining_fees': row.fees,
            'feesStatus': 'Due',
            'feesPaid': 0.0,
            'mobileNumber': row.mobileNumber.isNotEmpty ? row.mobileNumber : 'N/A',
            'emergencyContact': row.emergencyContact.isNotEmpty ? row.emergencyContact : 'N/A',
          },
          SetOptions(merge: true),
        );

        // Also save to students collection for backward compatibility
        final studentRef = _db.collection('students').doc(docId);
        batch.set(
          studentRef,
          {
            'name': row.name,
            'rollNumber': row.rollNo,
            'Password': row.password,
            'studentClass': row.classLevel,
            'total_fees': row.fees,
            'feesCriteria': row.feesCriteria,
            'remaining_fees': row.fees,
            'mobileNumber': row.mobileNumber.isNotEmpty ? row.mobileNumber : 'N/A',
            'emergencyContact': row.emergencyContact.isNotEmpty ? row.emergencyContact : 'N/A',
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      written += part.length;
    }
    return written;
  }
}
