import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/homework_model.dart';
import '../auth/auth_service.dart';

/// Advanced Teacher Homework Upload Screen
/// - Class selector (5-10)
/// - Subject selector (Maths, Science, SST, English)
/// - Text content input
/// - Image upload (gallery/camera)
/// - File upload (PDF/Doc)
/// - Auto-overwrite for same class+subject
class AdvancedHomeworkUploadScreen extends ConsumerStatefulWidget {
  const AdvancedHomeworkUploadScreen({super.key});

  @override
  ConsumerState<AdvancedHomeworkUploadScreen> createState() => _AdvancedHomeworkUploadScreenState();
}

class _AdvancedHomeworkUploadScreenState extends ConsumerState<AdvancedHomeworkUploadScreen> {
  int _selectedClass = 5;
  String _selectedSubject = 'Maths';
  final _textController = TextEditingController();

  final List<File> _selectedImages = [];
  final List<File> _selectedFiles = [];
  final Map<String, double> _uploadProgress = {};

  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Pick images from gallery
  Future<void> _pickImagesFromGallery() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null && !_selectedImages.any((f) => f.path == file.path)) {
            _selectedImages.add(File(file.path!));
          }
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added ${result.files.length} image(s)')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error picking images: $e')),
      );
    }
  }

  /// Capture image from camera
  Future<void> _captureImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

      if (image != null && !_selectedImages.any((f) => f.path == image.path)) {
        _selectedImages.add(File(image.path));
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Image captured')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error capturing image: $e')),
      );
    }
  }

  /// Pick files (PDF, DOC, DOCX, etc.)
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null && !_selectedFiles.any((f) => f.path == file.path)) {
            _selectedFiles.add(File(file.path!));
          }
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added ${result.files.length} file(s)')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error picking files: $e')),
      );
    }
  }

  /// Upload images to Firebase Storage
  Future<List<String>> _uploadImages() async {
    final uploadedUrls = <String>[];

    // Authentication check
    final user = ref.read(authProvider);
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // STEP 1: Triple-check mandatory fields (Name, RollNo, Class, Password)
    if (user.displayName.isEmpty) {
      debugPrint('⚠️ User Name is missing or empty');
    }
    if (user.rollNumber == null || user.rollNumber!.isEmpty) {
      debugPrint('⚠️ User RollNo is missing or empty');
    }
    if (user.studentClass == null) {
      debugPrint('⚠️ User Class is invalid or missing');
    }
    debugPrint('👤 User: ${user.displayName} (Roll: ${user.rollNumber}, Class: ${user.studentClass})');

    // Construct folder path for images
    final folderPath = 'homework/class_$_selectedClass/$_selectedSubject/images';
    
    // STEP 2: Check if folder path exists
    debugPrint('🔍 Checking if image folder path exists...');
    final folderRef = FirebaseStorage.instance.ref(folderPath);
    try {
      await folderRef.list();
      debugPrint('✅ Image folder path exists, proceeding with upload');
    } catch (e) {
      debugPrint('⚠️ Image folder path does not exist, creating with dummy file...');
      
      // STEP 2: Create dummy file to initialize folder structure
      final dummyPath = '$folderPath/dummy.txt';
      final dummyRef = FirebaseStorage.instance.ref(dummyPath);
      
      try {
        final dummyData = 'dummy';
        await dummyRef.putString(dummyData);
        debugPrint('✅ Dummy file uploaded successfully for images');
      } catch (dummyError) {
        debugPrint('⚠️ Dummy file upload failed, but continuing: $dummyError');
      }
    }

    for (final imageFile in _selectedImages) {
      final fileName = imageFile.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$folderPath/${timestamp}_$fileName';

      try {
        debugPrint('📤 Uploading image: $fileName');
        debugPrint('📁 Storage path: $storagePath');

        // Validate storage path
        if (storagePath.isEmpty) {
          throw Exception('Storage path cannot be empty for image $fileName');
        }

        // File existence check
        if (!imageFile.existsSync()) {
          throw Exception('Image file does not exist: ${imageFile.path}');
        }

        setState(() => _uploadProgress[fileName] = 0);

        // STEP 3: Upload actual file
        final storageRef = FirebaseStorage.instance.ref(storagePath);
        debugPrint('🔗 Storage reference created: ${storageRef.fullPath}');

        final task = storageRef.putFile(imageFile);

        task.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          setState(() => _uploadProgress[fileName] = progress);
          debugPrint('⬆️ Image upload progress for $fileName: ${(progress * 100).toStringAsFixed(1)}%');
        });

        final snapshot = await task;
        debugPrint('✅ Image uploaded successfully: $fileName');

        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🔗 Download URL obtained for $fileName');
        uploadedUrls.add(url);

        setState(() => _uploadProgress.remove(fileName));
      } catch (e) {
        debugPrint('❌ Error uploading image $fileName: $e');
        debugPrint('❌ Error type: ${e.runtimeType}');
        debugPrint('❌ Stack trace: ${StackTrace.current}');
        setState(() => _uploadProgress.remove(fileName));
        rethrow;
      }
    }

    // STEP 4: Remove dummy file if it exists
    try {
      final dummyRef = FirebaseStorage.instance.ref('$folderPath/dummy.txt');
      await dummyRef.delete();
      debugPrint('✅ Dummy file removed successfully for images');
    } catch (e) {
      debugPrint('⚠️ Dummy file removal failed (may not exist): $e');
    }

    return uploadedUrls;
  }

  /// Upload files to Firebase Storage
  Future<List<Map<String, String>>> _uploadFiles() async {
    final uploadedAttachments = <Map<String, String>>[];

    // Authentication check
    final user = ref.read(authProvider);
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // STEP 1: Triple-check mandatory fields (Name, RollNo, Class, Password)
    if (user.displayName.isEmpty) {
      debugPrint('⚠️ User Name is missing or empty');
    }
    if (user.rollNumber == null || user.rollNumber!.isEmpty) {
      debugPrint('⚠️ User RollNo is missing or empty');
    }
    if (user.studentClass == null) {
      debugPrint('⚠️ User Class is invalid or missing');
    }
    debugPrint('👤 User: ${user.displayName} (Roll: ${user.rollNumber}, Class: ${user.studentClass})');

    // Construct folder path for files
    final folderPath = 'homework/class_$_selectedClass/$_selectedSubject/files';
    
    // STEP 2: Check if folder path exists
    debugPrint('🔍 Checking if file folder path exists...');
    final folderRef = FirebaseStorage.instance.ref(folderPath);
    try {
      await folderRef.list();
      debugPrint('✅ File folder path exists, proceeding with upload');
    } catch (e) {
      debugPrint('⚠️ File folder path does not exist, creating with dummy file...');
      
      // STEP 2: Create dummy file to initialize folder structure
      final dummyPath = '$folderPath/dummy.txt';
      final dummyRef = FirebaseStorage.instance.ref(dummyPath);
      
      try {
        final dummyData = 'dummy';
        await dummyRef.putString(dummyData);
        debugPrint('✅ Dummy file uploaded successfully for files');
      } catch (dummyError) {
        debugPrint('⚠️ Dummy file upload failed, but continuing: $dummyError');
      }
    }

    for (final file in _selectedFiles) {
      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$folderPath/${timestamp}_$fileName';

      try {
        debugPrint('📤 Uploading file: $fileName');
        debugPrint('📁 Storage path: $storagePath');

        // Validate storage path
        if (storagePath.isEmpty) {
          throw Exception('Storage path cannot be empty for file $fileName');
        }

        // File existence check
        if (!file.existsSync()) {
          throw Exception('File does not exist: ${file.path}');
        }

        setState(() => _uploadProgress[fileName] = 0);

        // STEP 3: Upload actual file
        final storageRef = FirebaseStorage.instance.ref(storagePath);
        debugPrint('🔗 Storage reference created: ${storageRef.fullPath}');

        final task = storageRef.putFile(file);

        task.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          setState(() => _uploadProgress[fileName] = progress);
          debugPrint('⬆️ File upload progress for $fileName: ${(progress * 100).toStringAsFixed(1)}%');
        });

        final snapshot = await task;
        debugPrint('✅ File uploaded successfully: $fileName');

        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🔗 Download URL obtained for $fileName');

        uploadedAttachments.add({
          'fileName': fileName,
          'url': url,
          'fileType': fileExtension,
        });

        setState(() => _uploadProgress.remove(fileName));
      } catch (e) {
        debugPrint('❌ Error uploading file $fileName: $e');
        debugPrint('❌ Error type: ${e.runtimeType}');
        debugPrint('❌ Stack trace: ${StackTrace.current}');
        setState(() => _uploadProgress.remove(fileName));
        rethrow;
      }
    }

    // STEP 4: Remove dummy file if it exists
    try {
      final dummyRef = FirebaseStorage.instance.ref('$folderPath/dummy.txt');
      await dummyRef.delete();
      debugPrint('✅ Dummy file removed successfully for files');
    } catch (e) {
      debugPrint('⚠️ Dummy file removal failed (may not exist): $e');
    }

    return uploadedAttachments;
  }

  /// Save homework (overwrites existing for same class+subject)
  Future<void> _saveHomework() async {
    final textContent = _textController.text.trim();
    final user = ref.read(authProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not authenticated')),
      );
      return;
    }

    if (textContent.isEmpty && _selectedImages.isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please add text, images, or files'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Upload images first
      final imageUrls = await _uploadImages();

      // Upload files
      final attachments = await _uploadFiles();

      // Save to Firestore (overwrites 'current')
      await ref.read(erpRepositoryProvider).saveHomeworkForClassAndSubject(
            classLevel: _selectedClass,
            subject: _selectedSubject,
            textContent: textContent,
            imageUrls: imageUrls,
            attachments: attachments,
            assignedBy: user.email ?? 'Unknown',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Homework published successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Clear UI
        _textController.clear();
        _selectedImages.clear();
        _selectedFiles.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
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
    if (_selectedClass == null) {
      return const Center(
        child: Text(
          'object-not-found',
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
            'Upload Homework',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Publish homework for a class and subject. New homework overwrites previous.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // CLASS SELECTOR
          Text(
            'Select Class',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedClass,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.school),
            ),
            items: HomeworkConstants.classLevels
                .map((c) => DropdownMenuItem(value: c, child: Text('Class $c')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedClass = value);
            },
          ),
          const SizedBox(height: 16),

          // SUBJECT SELECTOR
          Text(
            'Select Subject',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.subject),
            ),
            items: HomeworkConstants.subjects
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedSubject = value);
            },
          ),
          const SizedBox(height: 20),

          // TEXT CONTENT
          Text(
            'Homework Description',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter homework text, instructions, or notes...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // IMAGES SECTION
          Text(
            'Images (optional)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImagesFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _captureImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedImages.map((img) {
                final name = img.path.split('/').last;
                return Chip(
                  avatar: const Icon(Icons.image, size: 18),
                  label: Text(name, style: GoogleFonts.poppins(fontSize: 11)),
                  onDeleted: () {
                    setState(() => _selectedImages.remove(img));
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),

          // FILES SECTION
          Text(
            'Files (PDF/Doc - optional)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: const Text('Pick Files'),
          ),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedFiles.map((file) {
                final name = file.path.split('/').last;
                final ext = name.split('.').last.toUpperCase();
                return Chip(
                  avatar: Icon(
                    ext == 'PDF' ? Icons.picture_as_pdf : Icons.description,
                    size: 18,
                    color: ext == 'PDF' ? Colors.red : Colors.blue,
                  ),
                  label: Text(name, style: GoogleFonts.poppins(fontSize: 11)),
                  onDeleted: () {
                    setState(() => _selectedFiles.remove(file));
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // UPLOAD PROGRESS
          if (_uploadProgress.isNotEmpty) ...[
            ..._uploadProgress.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepBlue.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],

          // PUBLISH BUTTON
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_saving || _uploading) ? null : _saveHomework,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Publish Homework',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Publishing replaces the previous homework for this class and subject.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
