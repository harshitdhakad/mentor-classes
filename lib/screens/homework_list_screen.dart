import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../services/homework_service.dart';
import 'file_preview_screen.dart';

class HomeworkListScreen extends ConsumerWidget {
  final String classId;
  final bool isTeacher;

  const HomeworkListScreen({
    Key? key,
    required this.classId,
    this.isTeacher = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworkService = HomeworkService();

    return StreamBuilder<List<HomeworkFile>>(
      stream: homeworkService.getHomeworkFiles(classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No homework assigned yet'),
              ],
            ),
          );
        }

        final files = snapshot.data!;

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return HomeworkFileCard(
              file: file,
              homeworkService: homeworkService,
              isTeacher: isTeacher,
              onDelete: isTeacher ? () {} : null,
            );
          },
        );
      },
    );
  }
}

class HomeworkFileCard extends ConsumerWidget {
  final HomeworkFile file;
  final HomeworkService homeworkService;
  final bool isTeacher;
  final VoidCallback? onDelete;

  const HomeworkFileCard({
    Key? key,
    required this.file,
    required this.homeworkService,
    this.isTeacher = false,
    this.onDelete,
  }) : super(key: key);

  dynamic _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return FontAwesomeIcons.filePdf;
      case 'image':
      case 'png':
      case 'jpeg':
      case 'jpg':
        return FontAwesomeIcons.image;
      case 'doc':
      case 'docx':
        return FontAwesomeIcons.fileWord;
      default:
        return FontAwesomeIcons.file;
    }
  }

  Color _getFileIconColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'image':
      case 'png':
      case 'jpeg':
      case 'jpg':
        return Colors.green;
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _downloadFile(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );
      final filePath =
          await homeworkService.downloadFile(file.downloadUrl, file.fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewFile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FilePreviewScreen(file: file),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getFileIconColor(file.fileType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileIcon(file.fileType),
            color: _getFileIconColor(file.fileType),
            size: 28,
          ),
        ),
        title: Text(
          file.fileName,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'By ${file.teacherName}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(file.uploadedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.preview, color: Colors.blue),
                onPressed: () => _viewFile(context),
                tooltip: 'Preview',
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Colors.green),
                onPressed: () => _downloadFile(context),
                tooltip: 'Download',
              ),
              if (isTeacher && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
