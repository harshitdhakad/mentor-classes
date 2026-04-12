import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/homework_service.dart';

class FilePreviewScreen extends StatefulWidget {
  final HomeworkFile file;

  const FilePreviewScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late Future<String> _pdfPath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.file.fileType.toLowerCase() == 'pdf') {
      _pdfPath = _downloadPdf();
    }
  }

  Future<String> _downloadPdf() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = '${dir.path}/${widget.file.fileName}';
    await Dio().download(widget.file.downloadUrl, file);
    return file;
  }

  Future<void> _downloadFile() async {
    setState(() => _isDownloading = true);
    try {
      final service = HomeworkService();
      final filePath =
          await service.downloadFile(widget.file.downloadUrl, widget.file.fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.fileName),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _downloadFile,
                      tooltip: 'Download',
                    ),
            ),
          ),
        ],
      ),
      body: _buildPreview(),
    );
  }

  Widget _buildPreview() {
    final fileType = widget.file.fileType.toLowerCase();

    if (fileType == 'pdf') {
      return FutureBuilder<String>(
        future: _pdfPath,
        builder: (context, snapshot) {
          try {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint('PDF loading error: ${snapshot.error}');
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Error loading PDF'),
                  ],
                ),
              );
            }
            if (snapshot.hasData) {
              return PDFView(filePath: snapshot.data!);
            }
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            );
          } catch (e) {
            debugPrint('PDF preview error: $e');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading PDF'),
                ],
              ),
            );
          }
        },
      );
    } else if (['image', 'png', 'jpeg', 'jpg'].contains(fileType)) {
      return Center(
        child: CachedNetworkImage(
          imageUrl: widget.file.downloadUrl,
          placeholder: (context, url) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading image...'),
            ],
          ),
          errorWidget: (context, url, error) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading image: $error'),
            ],
          ),
        ),
      );
    } else {
      // For documents and other file types
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                widget.file.fileName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'File type: ${widget.file.fileType.toUpperCase()}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadFile,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isDownloading ? 'Downloading...' : 'Download File'),
            ),
          ],
        ),
      );
    }
  }
}
