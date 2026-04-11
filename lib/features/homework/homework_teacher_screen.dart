import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

/// Teacher/Admin: assign today's homework for a class.
class HomeworkTeacherScreen extends ConsumerStatefulWidget {
  const HomeworkTeacherScreen({super.key});

  @override
  ConsumerState<HomeworkTeacherScreen> createState() => _HomeworkTeacherScreenState();
}

class _HomeworkTeacherScreenState extends ConsumerState<HomeworkTeacherScreen> {
  int _classLevel = 8;
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  
  // File attachment state
  final List<PlatformFile> _selectedFiles = [];
  final Map<String, double> _uploadProgress = {}; // filename -> progress
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added ${result.files.length} file(s)')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error picking file: $e')),
      );
    }
  }

  Future<List<Map<String, String>>> _uploadFilesToStorage() async {
    if (_selectedFiles.isEmpty) return [];

    final uploadedUrls = <Map<String, String>>[];
    setState(() => _uploading = true);

    try {
      // STEP 1: Triple-check mandatory fields (Name, RollNo, Class, Password)
      final user = ref.read(authProvider);
      if (user == null) {
        throw Exception('User not authenticated');
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

      // STEP 2: Check-and-Create path initialization with dummy file
      const folder = 'homework_attachments';
      final folderPath = '$folder/class_$_classLevel';
      debugPrint('📤 Starting Smart Path Creation for homework upload');
      debugPrint('📁 Target folder path: $folderPath');
      debugPrint('📝 Class level: $_classLevel');
      debugPrint('👤 User: ${user.displayName} (Roll: ${user.rollNumber}, Class: ${user.studentClass})');

      // Validate path construction
      if (folderPath.isEmpty) {
        throw Exception('Folder path cannot be empty - check class level selection');
      }
      if (_classLevel == null) {
        throw Exception('Class level is null - mandatory field missing');
      }

      // Check if folder exists and create with dummy file if needed
      final folderRef = FirebaseStorage.instance.ref(folderPath);
      try {
        await folderRef.list();
        debugPrint('✅ Folder path exists, proceeding with upload');
      } catch (e) {
        debugPrint('⚠️ Folder path does not exist, creating with dummy file...');
        
        // Create dummy file to initialize folder structure
        final dummyPath = '$folderPath/dummy.txt';
        final dummyRef = FirebaseStorage.instance.ref(dummyPath);
        
        try {
          final dummyData = 'dummy - path initialization';
          await dummyRef.putString(dummyData);
          debugPrint('✅ Dummy file uploaded successfully to initialize path');
        } catch (dummyError) {
          debugPrint('⚠️ Dummy file upload failed, but continuing: $dummyError');
        }
      }

      // STEP 2: Upload actual files
      for (final file in _selectedFiles) {
        if (file.path == null) continue;

        final fileName = file.name;
        final fileExtension = fileName.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$folderPath/${timestamp}_$fileName';

        debugPrint('📤 Uploading file: $fileName');
        debugPrint('📁 Storage path: $storagePath');

        try {
          final fileToUpload = File(file.path!);
          
          // Validate file existence
          if (!fileToUpload.existsSync()) {
            throw Exception('File does not exist at path: ${file.path}');
          }

          final task = FirebaseStorage.instance.ref(storagePath).putFile(fileToUpload);

          task.snapshotEvents.listen((event) {
            final progress = event.bytesTransferred / event.totalBytes;
            setState(() => _uploadProgress[fileName] = progress);
            debugPrint('⬆️ Upload progress for $fileName: ${(progress * 100).toStringAsFixed(1)}%');
          });

          final snapshot = await task;
          final url = await snapshot.ref.getDownloadURL();
          debugPrint('✅ File uploaded successfully: $fileName');

          uploadedUrls.add({
            'fileName': fileName,
            'url': url,
            'fileType': fileExtension,
          });

          setState(() => _uploadProgress.remove(fileName));
        } catch (e) {
          debugPrint('❌ Error uploading $fileName: $e');
          debugPrint('❌ Error type: ${e.runtimeType}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading $fileName: $e')),
          );
        }
      }

      // STEP 3: Remove dummy file if it exists
      try {
        final dummyRef = FirebaseStorage.instance.ref('$folderPath/dummy.txt');
        await dummyRef.delete();
        debugPrint('✅ Dummy file removed successfully');
      } catch (e) {
        debugPrint('⚠️ Dummy file removal failed (may not exist): $e');
      }

    } finally {
      setState(() => _uploading = false);
    }

    return uploadedUrls;
  }

  Future<void> _save() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isStaff || user.email == null) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Upload files first
      final attachments = await _uploadFilesToStorage();

      // Save homework with file URLs
      await ref.read(erpRepositoryProvider).saveHomeworkWithAttachments(
            classLevel: _classLevel,
            title: _title.text.trim(),
            description: _body.text.trim(),
            assignedBy: user.email!,
            attachments: attachments,
          );

      if (mounted) {
        _title.clear();
        _body.clear();
        setState(() => _selectedFiles.clear());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Homework posted for Class $_classLevel${_selectedFiles.isNotEmpty ? ' with ${_selectedFiles.length} file(s)' : ''}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // Class selection validation
    if (_classLevel == null) {
      return const Center(
        child: Text(
          'object-not-found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Today's homework",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students see this under Homework for the date you post.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _classLevel,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [
              for (var c = StudentClassLevels.min; c <= StudentClassLevels.max; c++)
                DropdownMenuItem(value: c, child: Text('Class $c')),
            ],
            onChanged: (v) => setState(() => _classLevel = v ?? 8),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            decoration: const InputDecoration(
              labelText: 'Details',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),

          // File Attachments Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attachments',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || _uploading ? null : _pickAndAddFile,
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text('Add File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDFs, images (jpg, png, gif)',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                  ),

                  // Selected Files List
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...List.generate(_selectedFiles.length, (index) {
                      final file = _selectedFiles[index];
                      final isUploading = _uploadProgress.containsKey(file.name);
                      final progress = _uploadProgress[file.name] ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              file.extension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                              size: 24,
                              color: AppTheme.deepBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  if (isUploading)
                                    SizedBox(
                                      height: 4,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(value: progress, minHeight: 4),
                                      ),
                                    ),
                                  if (isUploading)
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                            if (!isUploading)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() => _selectedFiles.removeAt(index));
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No files selected',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_saving || _uploading) ? null : _save,
            child: _saving || _uploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _uploading ? 'Uploading files...' : 'Publish homework',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
