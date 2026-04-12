import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../models/academic_resource_model.dart';
import '../auth/auth_service.dart';

/// Screen for teachers to upload academic resources
class ResourceUploadScreen extends ConsumerStatefulWidget {
  const ResourceUploadScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResourceUploadScreen> createState() => _ResourceUploadScreenState();
}

class _ResourceUploadScreenState extends ConsumerState<ResourceUploadScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  String? _selectedResourceType;
  String? _selectedSubject;
  File? _selectedFile;
  bool _isUploading = false;

  final List<String> _resourceTypes = ['notes', 'test_papers', 'worksheets'];
  final List<String> _subjects = [
    'Maths',
    'Science',
    'English',
    'civics',
    'History',
    'Geography',
    'Economics',
    'Physics',
    'Chemistry',
    'Biology',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedClass = ref.watch(selectedClassProvider);
    final user = ref.watch(authProvider);

    // Authentication check
    if (user == null || !user.isStaff) {
      return const Center(
        child: Text(
          'Access Denied',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Upload Resource for Class $selectedClass',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share study materials with your students',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Resource Type Selector
          MentorGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resource Type *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _resourceTypes.map((type) {
                    final isSelected = _selectedResourceType == type;
                    final displayName = type == 'notes'
                        ? '📝 Notes'
                        : type == 'test_papers'
                            ? '📄 Test Papers'
                            : '✏️ Worksheets';
                    return FilterChip(
                      label: Text(displayName),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedResourceType = type),
                      backgroundColor: Colors.grey[100],
                      selectedColor: AppTheme.deepBluePrimary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.deepBluePrimary
                            : Colors.grey[700],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subject Selector
          MentorGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subject *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubject,
                  items: _subjects
                      .map((subject) =>
                          DropdownMenuItem(value: subject, child: Text(subject)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedSubject = value),
                  decoration: InputDecoration(
                    hintText: 'Select subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title Input
          MentorGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Chapter 5 Notes - Algebra',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description Input
          MentorGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Add any additional notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File Picker
          MentorGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File (PDF, Image, or Document) *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedFile == null)
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to select file',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PDF, JPG, PNG (Max 50MB)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green[50],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFile!.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${(_selectedFile!.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedFile = null),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadResource,
              icon: _isUploading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Resource'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepBluePrimary,
                disabledBackgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'doc', 'docx'],
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFile = File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _uploadResource() async {
    // Authentication check
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Not authenticated. Please sign in to upload resources.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation
    if (_selectedResourceType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select resource type and subject')),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    // File existence check
    if (!_selectedFile!.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Selected file does not exist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final selectedClass = ref.read(selectedClassProvider);
      final user = ref.read(authProvider);
      final repo = ref.read(erpRepositoryProvider);

      // STEP 1: Triple-check mandatory fields (Name, RollNo, Class, Password)
      if (user == null) {
        throw Exception('User not authenticated - missing mandatory user data');
      }
      if (user.displayName.isEmpty) {
        debugPrint('⚠️ User Name is missing or empty');
      }
      if (user.rollNumber == null || user.rollNumber!.isEmpty) {
        debugPrint('⚠️ User RollNo is missing or empty');
      }
      if (user.studentClass == null) {
        debugPrint('⚠️ User Class is invalid or missing');
      }

      // Determine file type
      final fileExt = _selectedFile!.path.split('.').last.toLowerCase();
      final fileType = _getFileType(fileExt);

      // Construct target folder path (without filename)
      final folderPath = 'academic_resources/class_$selectedClass/${_selectedSubject!}/$_selectedResourceType';
      final fileName = '${_titleController.text}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '$folderPath/$fileName';

      debugPrint('📤 Uploading resource to Firebase Storage...');
      debugPrint('📁 Folder path: $folderPath');
      debugPrint('📁 Storage path: $storagePath');
      debugPrint('📄 File path: ${_selectedFile!.path}');
      debugPrint('👤 User: ${user.displayName} (Roll: ${user.rollNumber}, Class: ${user.studentClass})');

      // Validate storage path
      if (storagePath.isEmpty) {
        throw Exception('Storage path cannot be empty');
      }

      // STEP 1: Check if folder path exists
      debugPrint('🔍 Checking if folder path exists...');
      final folderRef = FirebaseStorage.instance.ref(folderPath);
      try {
        await folderRef.list();
        debugPrint('✅ Folder path exists, proceeding with upload');
      } catch (e) {
        debugPrint('⚠️ Folder path does not exist, creating with dummy file...');
        
        // STEP 2: Create dummy file to initialize folder structure
        final dummyPath = '$folderPath/dummy.txt';
        final dummyRef = FirebaseStorage.instance.ref(dummyPath);
        
        try {
          final dummyData = 'dummy';
          await dummyRef.putString(dummyData);
          debugPrint('✅ Dummy file uploaded successfully');
        } catch (dummyError) {
          debugPrint('⚠️ Dummy file upload failed, but continuing: $dummyError');
        }
      }

      // STEP 3: Upload actual file
      final storageRef = FirebaseStorage.instance.ref(storagePath);
      debugPrint('🔗 Storage reference created: ${storageRef.fullPath}');

      final uploadTask = storageRef.putFile(_selectedFile!);
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        debugPrint('⬆️ Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      debugPrint('✅ File uploaded successfully');

      final fileUrl = await snapshot.ref.getDownloadURL();
      debugPrint('🔗 Download URL obtained: $fileUrl');

      // STEP 4: Remove dummy file if it exists
      try {
        final dummyRef = FirebaseStorage.instance.ref('$folderPath/dummy.txt');
        await dummyRef.delete();
        debugPrint('✅ Dummy file removed successfully');
      } catch (e) {
        debugPrint('⚠️ Dummy file removal failed (may not exist): $e');
      }

      // Create resource model
      final resource = AcademicResource(
        classLevel: selectedClass,
        subject: _selectedSubject!,
        resourceType: _selectedResourceType!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fileUrl: fileUrl,
        fileName: _selectedFile!.path.split('/').last,
        fileType: fileType,
        uploadedBy: user.email ?? 'Unknown',
      );

      // Save to Firestore
      debugPrint('💾 Saving resource to Firestore...');
      await repo.uploadAcademicResource(resource: resource);
      debugPrint('✅ Resource saved to Firestore');

      if (mounted) {
        // Reset form
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedFile = null;
          _selectedResourceType = null;
          _selectedSubject = null;
          _isUploading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Resource uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the resources view
        ref.refresh(selectedResourceTypeProvider);
      }
    } catch (e) {
      debugPrint('❌ Upload failed with error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  String _getFileType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'doc':
      case 'docx':
        return 'doc';
      default:
        return 'file';
    }
  }
}
