import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/faculty_repository.dart';
import '../../models/faculty_model.dart';

/// Admin-only Faculty Management Screen for CRUD operations
class FacultyManagementScreen extends StatefulWidget {
  final bool isAdminMode;

  const FacultyManagementScreen({
    Key? key,
    this.isAdminMode = false,
  }) : super(key: key);

  @override
  State<FacultyManagementScreen> createState() =>
      _FacultyManagementScreenState();
}

class _FacultyManagementScreenState extends State<FacultyManagementScreen> {
  late bool _isAdminMode;
  final FacultyRepository _repository = FacultyRepository();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isAdminMode = widget.isAdminMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFacultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _FacultyFormDialog(
        repository: _repository,
        onSave: () {
          Navigator.pop(context);
          setState(() {}); // Refresh list
        },
      ),
    );
  }

  void _showEditFacultyDialog(BuildContext context, Faculty faculty) {
    showDialog(
      context: context,
      builder: (context) => _FacultyFormDialog(
        repository: _repository,
        faculty: faculty,
        onSave: () {
          Navigator.pop(context);
          setState(() {}); // Refresh list
        },
      ),
    );
  }

  void _deleteFaculty(String facultyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Faculty Member?'),
        content: const Text(
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _repository.deleteFaculty(facultyId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Faculty member deleted')),
                );
                setState(() {});
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Faculty Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
        actions: [
          Tooltip(
            message: _isAdminMode ? 'Edit Mode On' : 'Edit Mode Off',
            child: IconButton(
              icon: Icon(_isAdminMode ? Icons.lock_open : Icons.lock),
              onPressed: () => setState(() => _isAdminMode = !_isAdminMode),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search faculty by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Faculty list
          Expanded(
            child: StreamBuilder<List<Faculty>>(
              stream: _repository.getAllFacultyStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No faculty members yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_isAdminMode) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _showAddFacultyDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Faculty Member'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Filter by search
                var faculty = snapshot.data!;
                if (_searchController.text.isNotEmpty) {
                  faculty = faculty
                      .where((f) => f.name
                          .toLowerCase()
                          .contains(_searchController.text.toLowerCase()))
                      .toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: faculty.length + (_isAdminMode ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isAdminMode && index == faculty.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: FilledButton.icon(
                          onPressed: () => _showAddFacultyDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Faculty Member'),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }

                    final member = faculty[index];
                    return _FacultyCard(
                      faculty: member,
                      isAdminMode: _isAdminMode,
                      onEdit: () =>
                          _showEditFacultyDialog(context, member),
                      onDelete: () => _deleteFaculty(member.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Faculty card widget
class _FacultyCard extends StatelessWidget {
  final Faculty faculty;
  final bool isAdminMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _FacultyCard({
    required this.faculty,
    required this.isAdminMode,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Avatar/Image
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.deepBlue.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: faculty.imageUrl != null
                ? Image.network(faculty.imageUrl!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: AppTheme.deepBlue.withValues(alpha: 0.3),
                    ),
                  ),
          ),
          // Faculty info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faculty.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  faculty.subject,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.deepBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (faculty.qualifications != null &&
                    faculty.qualifications!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Qualifications: ${faculty.qualifications}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (faculty.experience != null &&
                    faculty.experience!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Experience: ${faculty.experience}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (faculty.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${faculty.email}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (faculty.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${faculty.phone}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (faculty.bio != null && faculty.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    faculty.bio!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          if (isAdminMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
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

/// Form dialog for adding/editing faculty
class _FacultyFormDialog extends StatefulWidget {
  final FacultyRepository repository;
  final Faculty? faculty;
  final VoidCallback onSave;

  const _FacultyFormDialog({
    required this.repository,
    this.faculty,
    required this.onSave,
  });

  @override
  State<_FacultyFormDialog> createState() => _FacultyFormDialogState();
}

class _FacultyFormDialogState extends State<_FacultyFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _qualCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _imageUrlCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final faculty = widget.faculty;
    _nameCtrl = TextEditingController(text: faculty?.name ?? '');
    _emailCtrl = TextEditingController(text: faculty?.email ?? '');
    _phoneCtrl = TextEditingController(text: faculty?.phone ?? '');
    _subjectCtrl = TextEditingController(text: faculty?.subject ?? '');
    _qualCtrl = TextEditingController(text: faculty?.qualifications ?? '');
    _expCtrl = TextEditingController(text: faculty?.experience ?? '');
    _bioCtrl = TextEditingController(text: faculty?.bio ?? '');
    _imageUrlCtrl = TextEditingController(text: faculty?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _qualCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _subjectCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Subject are required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final faculty = Faculty(
        id: widget.faculty?.id ?? '',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        qualifications:
            _qualCtrl.text.isEmpty ? null : _qualCtrl.text.trim(),
        experience: _expCtrl.text.isEmpty ? null : _expCtrl.text.trim(),
        imageUrl: _imageUrlCtrl.text.isEmpty ? null : _imageUrlCtrl.text.trim(),
        bio: _bioCtrl.text.isEmpty ? null : _bioCtrl.text.trim(),
      );

      if (widget.faculty == null) {
        // Add new
        await widget.repository.addFaculty(faculty);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty member added')),
        );
      } else {
        // Update existing
        await widget.repository.updateFaculty(widget.faculty!.id, faculty);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty member updated')),
        );
      }

      if (mounted) {
        widget.onSave();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.faculty == null ? 'Add Faculty Member' : 'Edit Faculty Member',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qualCtrl,
              decoration: const InputDecoration(labelText: 'Qualifications'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expCtrl,
              decoration: const InputDecoration(labelText: 'Experience'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageUrlCtrl,
              decoration: const InputDecoration(labelText: 'Image URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
