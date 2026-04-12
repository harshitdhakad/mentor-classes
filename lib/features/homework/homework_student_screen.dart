import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../models/homework_model.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';
import '../auth/auth_service.dart';

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
      ),
      body: Column(
        children: [
          // Subject Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: _selectedSubject,
              isExpanded: true,
              items: _subjects
                  .map((subject) => DropdownMenuItem(
                        value: subject,
                        child: Text(subject),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                });
              },
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
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No homework assigned for this subject'),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Card
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          homework.subject,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'by ${homework.assignedBy}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          homework.formattedDate,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Homework Text
                                if (homework.textContent.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Description',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(homework.textContent),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                // Images Section
                                if (homework.imageUrls.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Images',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      ...homework.imageUrls
                                          .asMap()
                                          .entries
                                          .map((entry) =>
                                              _buildImagePreview(entry.value))
                                          .toList(),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                // Attachments/Files Section
                                if (homework.attachments.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Files',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: homework.attachments.length,
                                        itemBuilder: (context, index) {
                                          final attachment =
                                              homework.attachments[index];
                                          return _buildAttachmentCard(
                                            attachment,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error rendering homework: $e');
                          return const Center(child: Text('Error loading homework'));
                        }
                      },
                      loading: () => const Center(child: Text('Loading...')),
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

  Widget _buildAttachmentCard(HomeworkAttachment attachment) {
    final isPdf = attachment.fileType == 'pdf';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                isPdf ? Icons.picture_as_pdf : Icons.description,
                color: isPdf ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(attachment.uploadedAt))}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    _downloadFile(attachment.url, attachment.fileName),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox.shrink(),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error_outline),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
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
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
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
