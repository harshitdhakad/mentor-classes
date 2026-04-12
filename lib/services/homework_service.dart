import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class HomeworkFile {
  final String id;
  final String fileName;
  final String fileType; // 'pdf', 'image', 'doc'
  final String downloadUrl;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String teacherName;

  HomeworkFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    this.teacherName = 'Unknown',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'fileName': fileName,
    'fileType': fileType,
    'downloadUrl': downloadUrl,
    'uploadedAt': uploadedAt,
    'uploadedBy': uploadedBy,
    'teacherName': teacherName,
  };

  factory HomeworkFile.fromMap(Map<String, dynamic> map) => HomeworkFile(
    id: map['id'] ?? '',
    fileName: map['fileName'] ?? '',
    fileType: map['fileType'] ?? '',
    downloadUrl: map['downloadUrl'] ?? '',
    uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    uploadedBy: map['uploadedBy'] ?? '',
    teacherName: map['teacherName'] ?? 'Unknown',
  );
}

class HomeworkService {
  static final HomeworkService _instance = HomeworkService._internal();

  factory HomeworkService() {
    return _instance;
  }

  HomeworkService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();

  /// Upload homework file to Firebase Storage and Firestore
  Future<void> uploadHomework({
    required String classId,
    required File file,
    required String fileName,
    required String fileType,
    required String uploadedBy,
    String teacherName = 'Unknown',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref =
          _storage.ref('homework/$classId/${timestamp}_$fileName');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      final homeworkDoc = HomeworkFile(
        id: timestamp.toString(),
        fileName: fileName,
        fileType: fileType,
        downloadUrl: downloadUrl,
        uploadedAt: DateTime.now(),
        uploadedBy: uploadedBy,
        teacherName: teacherName,
      );

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('homework')
          .doc(timestamp.toString())
          .set(homeworkDoc.toMap());
    } catch (e) {
      throw Exception('Failed to upload homework: $e');
    }
  }

  /// Stream of homework files for a class
  Stream<List<HomeworkFile>> getHomeworkFiles(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('homework')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HomeworkFile.fromMap(doc.data()))
            .toList());
  }

  /// Download file to device
  Future<String> downloadFile(String downloadUrl, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      return filePath;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  /// Delete homework file
  Future<void> deleteHomework(String classId, String homeworkId) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('homework')
          .doc(homeworkId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete homework: $e');
    }
  }
}
