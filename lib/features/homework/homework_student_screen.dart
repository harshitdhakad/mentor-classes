import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/homework_model.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// Student: View homework by subject with support for text, images, and files
class HomeworkStudentScreen extends ConsumerStatefulWidget {
  const HomeworkStudentScreen({super.key});

  @override
  ConsumerState<HomeworkStudentScreen> createState() =>
      _HomeworkStudentScreenState();
}

class _HomeworkStudentScreenState extends ConsumerState<HomeworkStudentScreen> {
  String? _selectedSubject;
  final List<String> _subjects = HomeworkConstants.subjects;

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjects.first;
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot download file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null || !StudentClassLevels.isValid(user.studentClass)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Homework')),
        body: const Center(
          child: Text('Homework requires your class on file'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        centerTitle: true,
        backgroundColor: AppTheme.deepBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Subject Selector - Modern Chips
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subjects.map((subject) {
                  final isSelected = _selectedSubject == subject;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedSubject = subject;
                        });
                      },
                      selectedColor: AppTheme.deepBlue,
                      backgroundColor: Colors.grey.shade100,
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Homework Content
          Expanded(
            child: _selectedSubject == null
                ? const Center(child: Text('Select a subject'))
                : ref
                    .watch(
                      watchHomeworkForClassProvider(user.studentClass!),
                    )
                    .when(
                      data: (homeworkMap) {
                        try {
                          final homework = homeworkMap[_selectedSubject];

                          if (homework == null) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No homework assigned for this subject',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Card - Modern Design
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.deepBlue,
                                        AppTheme.deepBlue.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.deepBlue.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                _getSubjectIcon(homework.subject),
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    homework.subject,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Class ${homework.classLevel}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Colors.white.withOpacity(0.9),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(color: Colors.white30),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 18,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'by ${homework.assignedBy}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              homework.formattedDate,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Homework Text
                                if (homework.textContent.isNotEmpty) ...[
                                  Text(
                                    '📝 Description',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade200,
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        homework.textContent,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                // Images Section
                                if (homework.imageUrls.isNotEmpty) ...[
                                  Text(
                                    '🖼️ Images',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...homework.imageUrls
                                      .asMap()
                                      .entries
                                      .map((entry) => _buildImagePreview(entry.value))
                                      .toList(),
                                  const SizedBox(height: 24),
                                ],
                                // Attachments/Files Section
                                if (homework.attachments.isNotEmpty) ...[
                                  Text(
                                    '📎 Files',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: homework.attachments.length,
                                    itemBuilder: (context, index) {
                                      final attachment = homework.attachments[index];
                                      return _buildAttachmentCard(attachment);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error rendering homework: $e');
                          return const Center(child: Text('Error loading homework'));
                        }
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (error, stackTrace) {
                        debugPrint('Homework stream error: $error');
                        return const Center(child: Text('Error loading homework'));
                      },
                    ),
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject) {
      case 'Maths':
        return Icons.calculate;
      case 'Science':
        return Icons.science;
      case 'English':
        return Icons.menu_book;
      case 'SST':
        return Icons.public;
      default:
        return Icons.school;
    }
  }

  Widget _buildAttachmentCard(HomeworkAttachment attachment) {
    final isPdf = attachment.fileType == 'pdf';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.description,
                  color: isPdf ? Colors.red : Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(attachment.uploadedAt))}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _downloadFile(attachment.url, attachment.fileName),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.deepBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 250,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 250,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.error_outline, size: 48),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: _buildZoomableImageViewer(imageUrl),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomableImageViewer(String imageUrl) {
    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error_outline),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: Navigator.of(context).pop,
            child: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
