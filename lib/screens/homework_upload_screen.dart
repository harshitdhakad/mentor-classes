import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/homework_service.dart';

class HomeworkUploadScreen extends StatefulWidget {
  final String classId;
  final String teacherName;
  final String teacherId;

  const HomeworkUploadScreen({
    Key? key,
    required this.classId,
    required this.teacherName,
    required this.teacherId,
  }) : super(key: key);

  @override
  State<HomeworkUploadScreen> createState() => _HomeworkUploadScreenState();
}

class _HomeworkUploadScreenState extends State<HomeworkUploadScreen> {
  File? _selectedFile;
  String? _selectedFileType;
  bool _isUploading = false;
  final HomeworkService _homeworkService = HomeworkService();

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        type: FileType.custom,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.extension?.toLowerCase() ?? '';

        String fileType = 'doc';
        if (extension == 'pdf') {
          fileType = 'pdf';
        } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
          fileType = 'image';
        }

        setState(() {
          _selectedFile = File(file.path!);
          _selectedFileType = fileType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadHomework() async {
    if (_selectedFile == null || _selectedFileType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _homeworkService.uploadHomework(
        classId: widget.classId,
        file: _selectedFile!,
        fileName: _selectedFile!.path.split('/').last,
        fileType: _selectedFileType!,
        uploadedBy: widget.teacherId,
        teacherName: widget.teacherName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Homework uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedFile = null;
          _selectedFileType = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Homework'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Type Info
            Card(
              elevation: 0,
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported File Types',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFileTypeItem('PDF Documents', 'pdf'),
                    const SizedBox(height: 8),
                    _buildFileTypeItem('Images', 'jpg, jpeg, png'),
                    const SizedBox(height: 8),
                    _buildFileTypeItem('Word Documents', 'doc, docx'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // File Selection Area
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  if (_selectedFile == null)
                    Column(
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 64,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No file selected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap below to pick a file',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFile!.path.split('/').last,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type: ${_selectedFileType?.toUpperCase() ?? 'Unknown'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pick File Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadHomework,
              icon: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Homework'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Clear Button
            OutlinedButton(
              onPressed: (_selectedFile == null || _isUploading)
                  ? null
                  : () => setState(() {
                _selectedFile = null;
                _selectedFileType = null;
              }),
              child: const Text('Clear Selection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeItem(String label, String extension) {
    return Row(
      children: [
        const Icon(Icons.check, color: Colors.green, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label ($extension)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
