import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

/// Excel report generator for PTM (Parent-Teacher Meeting) and performance tracking
class ExcelReportGenerator {
  /// Generate PTM report with test series marks by student and subject
  static Future<List<int>> generatePTMReport({
    required String classLevel,
    required String reportTitle,
    required List<Map<String, dynamic>> studentMarks,
    required List<String> subjects,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Add title
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: subjects.length + 2, rowIndex: 0));
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue(reportTitle),
    );

    // Add date
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      TextCellValue('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}'),
    );

    // Add class level
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      TextCellValue('Class: $classLevel'),
    );

    // Add headers
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4), TextCellValue('Roll No'));
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4), TextCellValue('Student Name'));

    for (var i = 0; i < subjects.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: 4),
        TextCellValue(subjects[i]),
      );
    }

    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: subjects.length + 2, rowIndex: 4),
      TextCellValue('Average'),
    );

    // Add student data
    int rowIndex = 5;
    for (final student in studentMarks) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        TextCellValue(student['roll'] ?? ''),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        TextCellValue(student['name'] ?? ''),
      );

      double sum = 0;
      int count = 0;

      for (var i = 0; i < subjects.length; i++) {
        final marks = student['marks'][subjects[i]] ?? 0.0;
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: rowIndex),
          DoubleCellValue(marks as double),
        );
        sum += marks;
        count++;
      }

      final average = count > 0 ? sum / count : 0.0;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: subjects.length + 2, rowIndex: rowIndex),
        DoubleCellValue(average),
      );

      rowIndex++;
    }

    // Auto-size columns
    for (var i = 0; i < subjects.length + 3; i++) {
      sheet.setColumnAutoFit(i);
    }

    return excel.save()!;
  }

  /// Generate attendance report
  static Future<List<int>> generateAttendanceReport({
    required String classLevel,
    required List<Map<String, dynamic>> attendanceData,
    required int totalDays,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Title
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), TextCellValue('Attendance Report'));
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), TextCellValue('Class: $classLevel'));
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      TextCellValue('Total Days: $totalDays'),
    );

    // Headers
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4), TextCellValue('Roll No'));
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4), TextCellValue('Name'));
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 4), TextCellValue('Present'));
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4), TextCellValue('Percentage'));

    int rowIndex = 5;
    for (final record in attendanceData) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        TextCellValue(record['roll'] ?? ''),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        TextCellValue(record['name'] ?? ''),
      );

      final present = record['present'] ?? 0;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
        IntCellValue(present),
      );

      final percentage = totalDays > 0 ? (present / totalDays * 100) : 0.0;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
        DoubleCellValue(percentage),
      );

      rowIndex++;
    }

    sheet.setColumnAutoFit(0);
    sheet.setColumnAutoFit(1);
    sheet.setColumnAutoFit(2);
    sheet.setColumnAutoFit(3);

    return excel.save()!;
  }
}