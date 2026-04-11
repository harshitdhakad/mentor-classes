import 'package:intl/intl.dart';

/// Attachment for homework (file URL with metadata)
class HomeworkAttachment {
  final String fileName;
  final String url;
  final String fileType; // pdf, jpg, png, etc.
  final int uploadedAt;

  HomeworkAttachment({
    required this.fileName,
    required this.url,
    required this.fileType,
    required this.uploadedAt,
  });

  factory HomeworkAttachment.fromMap(Map<String, dynamic> data) {
    return HomeworkAttachment(
      fileName: data['fileName'] as String? ?? '',
      url: data['url'] as String? ?? '',
      fileType: data['fileType'] as String? ?? '',
      uploadedAt: data['uploadedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'url': url,
        'fileType': fileType,
        'uploadedAt': uploadedAt,
      };
}

/// Complete homework assignment for a class and subject
class HomeWorkAssignment {
  final String id;
  final int classLevel;
  final String subject;
  final String textContent; // Homework text description
  final List<String> imageUrls; // Uploaded images
  final List<HomeworkAttachment> attachments; // PDFs and other files
  final String assignedBy;
  final DateTime assignedAt;
  final DateTime lastUpdatedAt;
  final DateTime expiryTime; // Mandatory field for 24-hour auto-delete

  HomeWorkAssignment({
    required this.id,
    required this.classLevel,
    required this.subject,
    required this.textContent,
    required this.imageUrls,
    required this.attachments,
    required this.assignedBy,
    required this.assignedAt,
    required this.lastUpdatedAt,
    required this.expiryTime,
  });

  /// Check if this assignment has any content
  bool get hasContent =>
      textContent.isNotEmpty ||
      imageUrls.isNotEmpty ||
      attachments.isNotEmpty;

  /// Get formatted date for display
  String get formattedDate => DateFormat('MMM d, yyyy • HH:mm').format(assignedAt);

  /// Get file count
  int get fileCount => imageUrls.length + attachments.length;

  factory HomeWorkAssignment.fromMap(String id, Map<String, dynamic> data) {
    return HomeWorkAssignment(
      id: id,
      classLevel: data['classLevel'] as int? ?? 0,
      subject: data['subject'] as String? ?? '',
      textContent: data['textContent'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      attachments: (data['attachments'] as List?)
              ?.map((a) => HomeworkAttachment.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
      assignedBy: data['assignedBy'] as String? ?? '',
      assignedAt: (data['assignedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastUpdatedAt:
          (data['lastUpdatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      expiryTime: (data['expiryTime'] as dynamic)?.toDate() ?? 
                  DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'classLevel': classLevel,
        'subject': subject,
        'textContent': textContent,
        'imageUrls': imageUrls,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'assignedBy': assignedBy,
        'assignedAt': assignedAt,
        'lastUpdatedAt': lastUpdatedAt,
        'expiryTime': expiryTime,
      };
}

/// Constants for homework
class HomeworkConstants {
  static const List<String> subjects = ['Maths', 'Science', 'SST', 'English'];
  
  static const List<int> classLevels = [5, 6, 7, 8, 9, 10];
  
  /// Get icon for subject
  static String getSubjectIcon(String subject) {
    switch (subject) {
      case 'Maths':
        return '📐';
      case 'Science':
        return '🔬';
      case 'SST':
        return '🌍';
      case 'English':
        return '📚';
      default:
        return '📖';
    }
  }

  /// Get color for subject (as hex string)
  static int getSubjectColor(String subject) {
    switch (subject) {
      case 'Maths':
        return 0xFF4CAF50; // Green
      case 'Science':
        return 0xFF2196F3; // Blue
      case 'SST':
        return 0xFFFF9800; // Orange
      case 'English':
        return 0xFF9C27B0; // Purple
      default:
        return 0xFF607D8B; // Gray
    }
  }
}
