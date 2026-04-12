import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Background service for periodic cleanup of expired homework documents
/// Automatically deletes homework and associated files after 24 hours
class CleanupService {
  static final CleanupService _instance = CleanupService._internal();
  factory CleanupService() => _instance;
  CleanupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isRunning = false;

  /// Start the periodic cleanup task
  /// This should be called from the main app initialization
  void startPeriodicCleanup() {
    if (_isRunning) {
      debugPrint('🧹 Cleanup service already running');
      return;
    }

    _isRunning = true;
    debugPrint('🧹 Starting periodic cleanup service...');
    
    // Run cleanup immediately, then periodically
    _performCleanup();
    
    // Run every 30 minutes
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 30));
      if (_isRunning) {
        await _performCleanup();
        return true;
      }
      return false;
    });
  }

  /// Stop the periodic cleanup task
  void stopPeriodicCleanup() {
    _isRunning = false;
    debugPrint('🧹 Stopping periodic cleanup service');
  }

  /// Perform the actual cleanup operation
  Future<void> _performCleanup() async {
    debugPrint('🧹 Performing cleanup check...');
    
    try {
      final now = DateTime.now();
      int deletedCount = 0;
      int failedCount = 0;

      // Query all homework documents from Class 5 to Class 10
      for (int classLevel = 5; classLevel <= 10; classLevel++) {
        await _cleanupClassHomework(classLevel, now, (deleted, failed) {
          deletedCount += deleted;
          failedCount += failed;
        });
      }

      debugPrint('🧹 Cleanup complete - Deleted: $deletedCount, Failed: $failedCount');
    } catch (e) {
      debugPrint('❌ Cleanup failed with error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
    }
  }

  /// Cleanup homework for a specific class
  Future<void> _cleanupClassHomework(
    int classLevel,
    DateTime now,
    Function(int deleted, int failed) onResult,
  ) async {
    try {
      // Query the homework collection for this class directly
      final homeworkQuery = _firestore
          .collection('homework')
          .where('classLevel', isEqualTo: classLevel);
      final snapshot = await homeworkQuery.get();

      if (snapshot.docs.isEmpty) {
        debugPrint('🧹 No homework found for Class $classLevel');
        return;
      }

      int deletedCount = 0;
      int failedCount = 0;

      for (final doc in snapshot.docs) {
        await _cleanupHomeworkDocument(doc, now, (deleted, failed) {
          deletedCount += deleted;
          failedCount += failed;
        });
      }

      onResult(deletedCount, failedCount);
    } catch (e) {
      debugPrint('❌ Error cleaning up Class $classLevel: $e');
    }
  }

  /// Cleanup a single homework document
  Future<void> _cleanupHomeworkDocument(
    QueryDocumentSnapshot doc,
    DateTime now,
    Function(int deleted, int failed) onResult,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final expiryTime = (data['expiryTime'] as Timestamp?)?.toDate();

      if (expiryTime == null) {
        debugPrint('⚠️ Homework document has no expiryTime, skipping');
        return;
      }

      if (now.isAfter(expiryTime)) {
        // Delete the document
        await doc.reference.delete();
        debugPrint('✅ Deleted expired homework: ${doc.id}');

        // Delete associated files from Firebase Storage if they exist
        final fileUrls = data['fileUrls'] as List<dynamic>?;
        if (fileUrls != null) {
          for (final url in fileUrls) {
            try {
              await FirebaseStorage.instance.refFromURL(url as String).delete();
              debugPrint('✅ Deleted file: $url');
            } catch (e) {
              debugPrint('⚠️ Failed to delete file: $url - $e');
            }
          }
        }

        onResult(1, 0);
      } else {
        debugPrint('📝 Homework not expired yet: ${doc.id}');
        onResult(0, 0);
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up homework document: $e');
      onResult(0, 1);
    }
  }

  /// Manual cleanup trigger (for testing or immediate cleanup)
  Future<CleanupResult> triggerManualCleanup() async {
    debugPrint('🧹 Triggering manual cleanup...');
    
    final now = DateTime.now();
    int totalDeleted = 0;
    int totalFailed = 0;
    final Map<int, int> deletedByClass = {};

    try {
      for (int classLevel = 5; classLevel <= 10; classLevel++) {
        int classDeleted = 0;
        int classFailed = 0;

        await _cleanupClassHomework(classLevel, now, (deleted, failed) {
          classDeleted = deleted;
          classFailed = failed;
        });

        if (classDeleted > 0) {
          deletedByClass[classLevel] = classDeleted;
        }

        totalDeleted += classDeleted;
        totalFailed += classFailed;
      }

      return CleanupResult(
        success: true,
        totalDeleted: totalDeleted,
        totalFailed: totalFailed,
        deletedByClass: deletedByClass,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('❌ Manual cleanup failed: $e');
      return CleanupResult(
        success: false,
        totalDeleted: totalDeleted,
        totalFailed: totalFailed,
        deletedByClass: deletedByClass,
        timestamp: now,
        error: e.toString(),
      );
    }
  }
}

/// Result of a cleanup operation
class CleanupResult {
  final bool success;
  final int totalDeleted;
  final int totalFailed;
  final Map<int, int> deletedByClass;
  final DateTime timestamp;
  final String? error;

  CleanupResult({
    required this.success,
    required this.totalDeleted,
    required this.totalFailed,
    required this.deletedByClass,
    required this.timestamp,
    this.error,
  });

  @override
  String toString() {
    return 'CleanupResult(success: $success, deleted: $totalDeleted, failed: $totalFailed, byClass: $deletedByClass)';
  }
}
