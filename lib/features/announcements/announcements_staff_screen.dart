import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../../models/user_model.dart';

/// Post institute-wide or class-specific notices (shown on student home + stream).
class AnnouncementsStaffScreen extends ConsumerStatefulWidget {
  const AnnouncementsStaffScreen({super.key});

  @override
  ConsumerState<AnnouncementsStaffScreen> createState() => _AnnouncementsStaffScreenState();
}

class _AnnouncementsStaffScreenState extends ConsumerState<AnnouncementsStaffScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _classFilter;
  bool _posting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post(String type) async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message required')),
      );
      return;
    }
    setState(() => _posting = true);
    try {
      await ref.read(erpRepositoryProvider).postAnnouncement(
            title: _title.text.trim(),
            body: _body.text.trim(),
            classLevel: _classFilter,
            type: type,
          );
      if (mounted) {
        _title.clear();
        _body.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(erpRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New notice',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.deepBlue),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    // ignore: deprecated_member_use
                    value: _classFilter,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
                      for (var c = StudentClassLevels.min; c <= StudentClassLevels.max; c++)
                        DropdownMenuItem<int?>(value: c, child: Text('Class $c only')),
                    ],
                    onChanged: (v) => setState(() => _classFilter = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _body,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Due to rain, today is a holiday…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _posting ? null : () => _post('info'),
                          child: Text('Post', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _posting ? null : () => _post('holiday'),
                          child: Text('Holiday notice', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.watchAnnouncementsStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: Text('Loading announcements...'));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text('No announcements yet.', style: GoogleFonts.poppins()));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Icon(
                        d['type'] == 'holiday' ? Icons.beach_access : Icons.campaign_outlined,
                        color: AppTheme.deepBlue,
                      ),
                      title: Text(d['title']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(d['body']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 12)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
