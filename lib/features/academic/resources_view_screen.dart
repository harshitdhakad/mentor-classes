import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../models/academic_resource_model.dart';

/// Displays academic resources for viewing and downloading
class ResourcesViewScreen extends ConsumerStatefulWidget {
  const ResourcesViewScreen({
    required this.resourceType,
    Key? key,
  }) : super(key: key);

  final String resourceType;

  @override
  ConsumerState<ResourcesViewScreen> createState() => _ResourcesViewScreenState();
}

class _ResourcesViewScreenState extends ConsumerState<ResourcesViewScreen> {
  String? _selectedSubject;

  @override
  Widget build(BuildContext context) {
    final selectedClass = ref.watch(selectedClassProvider);

    // Fetch subjects for filter dropdown
    final subjectsAsync = ref.watch(subjectsForClassProvider(selectedClass));

    // Fetch resources with current filters
    final resourcesAsync = ref.watch(
      academicResourcesProvider((selectedClass, _selectedSubject, widget.resourceType)),
    );

    return Column(
      children: [
        // Subject Filter Dropdown
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: subjectsAsync.when(
            data: (subjects) => DropdownButton<String?>(
              isExpanded: true,
              value: _selectedSubject,
              hint: const Text('Select Subject...'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Subjects'),
                ),
                ...subjects.map((subject) => DropdownMenuItem(
                  value: subject,
                  child: Text(subject),
                ))],
              onChanged: (value) {
                setState(() => _selectedSubject = value);
              },
            ),
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: Text('Loading...')),
            ),
            error: (err, stack) {
              debugPrint('Subjects error: $err');
              return const Center(child: Text('Error loading subjects'));
            },
          ),
        ),
        const Divider(height: 0),
        // Resources List
        Expanded(
          child: resourcesAsync.when(
            data: (resources) {
              try {
                if (resources.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No resources available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Resources will appear here',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    try {
                      final resource = resources[index];
                      return _buildResourceCard(context, resource);
                    } catch (e) {
                      debugPrint('Error rendering resource card: $e');
                      return const SizedBox.shrink();
                    }
                  },
                );
              } catch (e) {
                debugPrint('Error rendering resources: $e');
                return const Center(child: Text('Error loading resources'));
              }
            },
            loading: () => const Center(child: Text('Loading...')),
            error: (err, stack) {
              debugPrint('Resources error: $err');
              return const Center(child: Text('Error loading resources'));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResourceCard(BuildContext context, AcademicResource resource) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: MentorGlassCard(
        padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Type Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getFileTypeColor(resource.fileType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getFileTypeIcon(resource.fileType),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Resource Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.deepBluePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resource.subject,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.deepBluePrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          resource.fileName.split('.').last.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (resource.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        resource.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _launchFile(resource.fileUrl),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.deepBluePrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadFile(resource),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepBluePrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By: ${resource.uploadedBy.split('@').first}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              if (resource.uploadedAt != null)
                Text(
                  _formatDate(resource.uploadedAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  String _getFileTypeIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '🖼️';
      case 'doc':
      case 'docx':
        return '📝';
      default:
        return '📎';
    }
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).ceil()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _launchFile(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _downloadFile(AcademicResource resource) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Downloading: ${resource.fileName}'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.deepBluePrimary,
      ),
    );

    // In a real app, implement actual download using:
    // 1. Firebase Storage direct download
    // 2. Platform channels for native download
    _launchFile(resource.fileUrl);
  }
}
