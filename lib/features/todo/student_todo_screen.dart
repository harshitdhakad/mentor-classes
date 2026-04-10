import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    required this.dueDate,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueDate': Timestamp.fromDate(dueDate),
        'done': done,
      };

  static TodoItem fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'] as String,
        title: j['title'] as String,
        dueDate: (j['dueDate'] as Timestamp).toDate(),
        done: j['done'] == true,
      );
}

class UploadedFile {
  UploadedFile({
    required this.id,
    required this.name,
    required this.url,
    required this.uploadedAt,
  });

  final String id;
  final String name;
  final String url;
  final DateTime uploadedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };

  static UploadedFile fromJson(Map<String, dynamic> j) => UploadedFile(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        uploadedAt: (j['uploadedAt'] as Timestamp).toDate(),
      );
}

/// Firebase-backed To-Do screen with timeout and file upload
class StudentTodoScreen extends ConsumerStatefulWidget {
  const StudentTodoScreen({super.key});

  @override
  ConsumerState<StudentTodoScreen> createState() => _StudentTodoScreenState();
}

class _StudentTodoScreenState extends ConsumerState<StudentTodoScreen> {
  final _input = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;
  List<TodoItem> _todos = [];
  List<UploadedFile> _uploads = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchDataWithTimeout();
  }

  Future<void> _fetchDataWithTimeout() async {
    final user = ref.read(authProvider);
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await Future.any([
        _fetchTodos(user.id),
        _fetchUploads(user.id),
        Future.delayed(const Duration(seconds: 10)),
      ]);
    } catch (e) {
      // Timeout or error - stop loading
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTodos(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('todos')
        .orderBy('dueDate')
        .get();

    setState(() {
      _todos = snap.docs.map((doc) => TodoItem.fromJson(doc.data())).toList();
    });
  }

  Future<void> _fetchUploads(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('uploads')
        .orderBy('uploadedAt', descending: true)
        .get();

    setState(() {
      _uploads = snap.docs.map((doc) => UploadedFile.fromJson(doc.data())).toList();
    });
  }

  Future<void> _addTodo() async {
    final user = ref.read(authProvider);
    if (user == null || _input.text.trim().isEmpty || _selectedDate == null) {
      return;
    }

    final todo = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _input.text.trim(),
      dueDate: _selectedDate!,
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('todos')
        .doc(todo.id)
        .set(todo.toJson());

    _input.clear();
    _dateController.clear();
    setState(() => _selectedDate = null);
    _fetchTodos(user.id);
  }

  Future<void> _toggleTodo(String todoId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final index = _todos.indexWhere((t) => t.id == todoId);
    if (index == -1) return;

    final updated = TodoItem(
      id: _todos[index].id,
      title: _todos[index].title,
      dueDate: _todos[index].dueDate,
      done: !_todos[index].done,
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('todos')
        .doc(todoId)
        .update({'done': updated.done});

    setState(() => _todos[index] = updated);
  }

  Future<void> _deleteTodo(String todoId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('todos')
        .doc(todoId)
        .delete();

    setState(() => _todos.removeWhere((t) => t.id == todoId));
  }

  Future<void> _pickAndUploadFile() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      setState(() => _isUploading = true);
      _uploadStatus = 'Uploading...';

      final fileName = file.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'users/${user.id}/uploads/${timestamp}_$fileName';

      final storageRef = FirebaseStorage.instance.ref(storagePath);
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      final uploadedFile = UploadedFile(
        id: timestamp.toString(),
        name: fileName,
        url: downloadUrl,
        uploadedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('uploads')
          .doc(uploadedFile.id)
          .set(uploadedFile.toJson());

      setState(() {
        _uploads.insert(0, uploadedFile);
        _isUploading = false;
        _uploadStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return Center(child: Text('Sign in to use tasks.', style: GoogleFonts.poppins()));
    }

    return Column(
      children: [
        // To-Do Entry Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New To-Do',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                decoration: InputDecoration(
                  labelText: 'Task description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Due date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addTodo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Add To-Do',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        // File Upload Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Files',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 12),
              if (_isUploading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_uploadStatus, style: GoogleFonts.poppins(fontSize: 12)),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload File (PDF, Image)'),
                ),
            ],
          ),
        ),

        // Content Area
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _todos.isEmpty && _uploads.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing to do at this moment',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: AppTheme.deepBlue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppTheme.deepBlue,
                            tabs: const [
                              Tab(text: 'To-Dos'),
                              Tab(text: 'Uploads'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildTodosList(),
                                _buildUploadsList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        ),

        // Developer Credits
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Text(
            'Developed by Mentor Classes ERP Team',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildTodosList() {
    if (_todos.isEmpty) {
      return Center(
        child: Text(
          'No to-dos yet',
          style: GoogleFonts.poppins(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Checkbox(
              value: todo.done,
              onChanged: (_) => _toggleTodo(todo.id),
            ),
            title: Text(
              todo.title,
              style: GoogleFonts.poppins(
                decoration: todo.done ? TextDecoration.lineThrough : null,
                color: todo.done ? Colors.grey : null,
              ),
            ),
            subtitle: Text(
              'Due: ${todo.dueDate.day}/${todo.dueDate.month}/${todo.dueDate.year}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteTodo(todo.id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadsList() {
    if (_uploads.isEmpty) {
      return Center(
        child: Text(
          'No uploads yet',
          style: GoogleFonts.poppins(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uploads.length,
      itemBuilder: (context, index) {
        final upload = _uploads[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file, color: AppTheme.deepBlue),
            title: Text(
              upload.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Uploaded: ${upload.uploadedAt.day}/${upload.uploadedAt.month}/${upload.uploadedAt.year}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                // Open file logic here
              },
            ),
          ),
        );
      },
    );
  }
}
