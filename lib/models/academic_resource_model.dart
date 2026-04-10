import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic resource (notes, test papers, worksheets)
class AcademicResource {
  AcademicResource({
    this.id,
    required this.classLevel,
    required this.subject,
    required this.resourceType,
    required this.title,
    this.description = '',
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    this.uploadedBy = '',
    this.uploadedAt,
    this.updatedAt,
    this.isActive = true,
  });

  final String? id;
  final int classLevel; // 5-10
  final String subject; // Maths, Science, Hindi, English, etc.
  final String resourceType; // 'notes', 'test_papers', 'worksheets'
  final String title;
  final String description;
  final String fileUrl; // Firebase Storage URL
  final String fileName;
  final String fileType; // 'pdf', 'image', 'doc'
  final String uploadedBy;
  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final bool isActive;

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'classLevel': classLevel,
      'subject': subject,
      'resourceType': resourceType,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  /// Create from Firestore map
  factory AcademicResource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AcademicResource(
      id: doc.id,
      classLevel: (data['classLevel'] as int?) ?? 5,
      subject: (data['subject'] as String?) ?? 'General',
      resourceType: (data['resourceType'] as String?) ?? 'notes',
      title: (data['title'] as String?) ?? 'Untitled',
      description: (data['description'] as String?) ?? '',
      fileUrl: (data['fileUrl'] as String?) ?? '',
      fileName: (data['fileName'] as String?) ?? 'file',
      fileType: (data['fileType'] as String?) ?? 'pdf',
      uploadedBy: (data['uploadedBy'] as String?) ?? 'Unknown',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }

  /// Create a copy with modified fields
  AcademicResource copyWith({
    String? id,
    int? classLevel,
    String? subject,
    String? resourceType,
    String? title,
    String? description,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? uploadedBy,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return AcademicResource(
      id: id ?? this.id,
      classLevel: classLevel ?? this.classLevel,
      subject: subject ?? this.subject,
      resourceType: resourceType ?? this.resourceType,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Check if file is a PDF
  bool get isPdf => fileType.toLowerCase() == 'pdf';

  /// Check if file is an image
  bool get isImage => ['jpg', 'jpeg', 'png', 'gif', 'webp']
      .contains(fileType.toLowerCase());

  /// Get display name for resource type
  String get resourceTypeDisplay {
    switch (resourceType) {
      case 'notes':
        return 'Notes';
      case 'test_papers':
        return 'Test Papers';
      case 'worksheets':
        return 'Worksheets';
      default:
        return resourceType;
    }
  }
}
