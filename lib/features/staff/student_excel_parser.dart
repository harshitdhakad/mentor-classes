import 'package:excel/excel.dart';

import '../../models/user_model.dart';

class ParsedStudentRow {
  const ParsedStudentRow({
    required this.rowNumber,
    required this.name,
    required this.rollNo,
    required this.password,
    required this.classLevel,
    required this.fees,
    this.feesCriteria = 'Monthly',
    this.mobileNumber = '',
    this.emergencyContact = '',
  });

  final int rowNumber;
  final String name;
  final String rollNo;
  final String password;
  final int classLevel;
  final double fees;
  final String feesCriteria;
  final String mobileNumber;
  final String emergencyContact;
}

class ExcelParseException implements Exception {
  ExcelParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudentExcelParseResult {
  StudentExcelParseResult({required this.rows, required this.errors});

  final List<ParsedStudentRow> rows;
  final List<String> errors;
}

/// Parses `.xlsx` bytes. Required: **Name**, **RollNo**, **Password**, **Class** (5–10), **Fees**.
/// Optional: **FeesCriteria** (Monthly/Lumpsum), **MobileNumber**, **EmergencyContact**.
abstract final class StudentExcelParser {
  static StudentExcelParseResult parse(List<int> bytes) {
    try {
      return _parseInternal(bytes);
    } on ExcelParseException {
      rethrow;
    } catch (e, st) {
      throw ExcelParseException('Unexpected error while parsing Excel: $e\n$st');
    }
  }

  static StudentExcelParseResult _parseInternal(List<int> bytes) {
    final errors = <String>[];
    final rows = <ParsedStudentRow>[];

    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw ExcelParseException('Could not read Excel file: $e');
    }

    if (excel.tables.isEmpty) {
      throw ExcelParseException('The workbook has no sheets.');
    }

    final sheet = excel.tables.values.first;
    final tableRows = sheet.rows;
    if (tableRows.isEmpty) {
      throw ExcelParseException('The sheet is empty.');
    }

    final headerCells = tableRows.first;
    final headers = <String>[];
    for (final cell in headerCells) {
      headers.add(_cellText(cell));
    }

    final nameI = _columnIndex(headers, const ['name']);
    final rollI = _columnIndex(headers, const ['rollno', 'roll', 'rollnumber', 'roll_no']);
    final passI = _columnIndex(headers, const ['password']);
    final classI = _columnIndex(headers, const ['class', 'studentclass', 'grade']);
    final feesI = _columnIndex(headers, const ['fees', 'totalfees', 'fee', 'amount']);
    final feesCriteriaI = _columnIndex(headers, const ['feescriteria', 'fees_type', 'feescriterion', 'paymenttype']);
    final mobileI = _columnIndex(headers, const [
      'mobilenumber',
      'mobile',
      'phone',
      'contact',
      'studentmobile',
    ]);
    final emergI = _columnIndex(headers, const [
      'emergencycontact',
      'emergency',
      'guardian',
      'parentcontact',
    ]);

    if (nameI == null || rollI == null || passI == null || classI == null || feesI == null) {
      throw ExcelParseException(
        'Headers must include: Name, RollNo, Password, Class (5–10), Fees. '
        'Optional: FeesCriteria, MobileNumber, EmergencyContact. '
        'Found: ${headers.where((e) => e.isNotEmpty).join(", ")}',
      );
    }

    for (var r = 1; r < tableRows.length; r++) {
      final line = tableRows[r];
      if (line.isEmpty) continue;

      String cellAt(int? i) {
        if (i == null || i >= line.length) return '';
        return _cellText(line[i]);
      }

      final name = cellAt(nameI);
      final roll = cellAt(rollI);
      final password = cellAt(passI);
      final classRaw = cellAt(classI);
      final feesRaw = cellAt(feesI);
      final feesCriteriaRaw = cellAt(feesCriteriaI);
      final mobile = cellAt(mobileI);
      final emerg = cellAt(emergI);

      if (name.isEmpty && roll.isEmpty && password.isEmpty && classRaw.isEmpty && feesRaw.isEmpty) {
        continue;
      }

      final rowNum = r + 1;
      if (name.isEmpty) errors.add('Row $rowNum: Name is empty.');
      if (roll.isEmpty) errors.add('Row $rowNum: RollNo is empty.');
      if (password.isEmpty) errors.add('Row $rowNum: Password is empty.');
      if (feesRaw.isEmpty) errors.add('Row $rowNum: Fees is empty.');

      final classLevel = _parseClassLevel(classRaw);
      if (classLevel == null) {
        errors.add('Row $rowNum: Class must be a whole number from ${StudentClassLevels.min} to ${StudentClassLevels.max}.');
        continue;
      }

      // Robust null-safe defaults for all fields
      final fees = double.tryParse(feesRaw) ?? 0.0;
      final feesCriteria = feesCriteriaRaw.isNotEmpty ? feesCriteriaRaw : 'Monthly';
      final mobileNumber = mobile.isNotEmpty ? mobile : 'N/A';
      final emergencyContact = emerg.isNotEmpty ? emerg : 'N/A';

      if (name.isNotEmpty && roll.isNotEmpty && password.isNotEmpty) {
        rows.add(
          ParsedStudentRow(
            rowNumber: rowNum,
            name: name,
            rollNo: roll,
            password: password,
            classLevel: classLevel,
            fees: fees,
            feesCriteria: feesCriteria,
            mobileNumber: mobileNumber,
            emergencyContact: emergencyContact,
          ),
        );
      }
    }

    return StudentExcelParseResult(rows: rows, errors: errors);
  }

  static int? _parseClassLevel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final n = num.tryParse(s);
    if (n != null) {
      final v = n.round();
      final isWhole = (n - v).abs() < 1e-9;
      if (isWhole && StudentClassLevels.isValid(v)) return v;
    }
    final digits = int.tryParse(s.replaceAll(RegExp(r'[^\d]'), ''));
    if (StudentClassLevels.isValid(digits)) return digits;
    return null;
  }

  static String _cellText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  static String _normHeader(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[\s_\-]+'), '');

  static int? _columnIndex(List<String> headers, List<String> aliases) {
    for (var i = 0; i < headers.length; i++) {
      final h = _normHeader(headers[i]);
      if (h.isEmpty) continue;
      for (final a in aliases) {
        if (h == _normHeader(a) || h == _normHeader(a.replaceAll(' ', ''))) {
          return i;
        }
      }
    }
    return null;
  }
}
