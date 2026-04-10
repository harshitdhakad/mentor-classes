import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mentor_glass_card.dart';
import '../../data/erp_providers.dart';
import '../../data/erp_repository.dart';
import '../../models/user_model.dart';

class StudentLeaderboardItem {
  StudentLeaderboardItem({
    required this.rollNumber,
    required this.name,
    required this.totalScore,
    this.rank,
  });

  final String rollNumber;
  final String name;
  final double totalScore;
  int? rank;
}

/// Enhanced Leaderboard with total score from all core subjects
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int? _selectedClass;
  List<StudentLeaderboardItem> _leaderboard = [];
  bool _loading = false;

  final List<String> _coreSubjects = ['SST', 'Science', 'Maths', 'English'];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadLeaderboard() async {
    if (_selectedClass == null) return;

    setState(() => _loading = true);

    try {
      final repo = ref.read(erpRepositoryProvider);
      
      // Fetch all students in the selected class
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('studentClass', isEqualTo: _selectedClass)
          .get();

      final leaderboard = <StudentLeaderboardItem>[];

      for (final studentDoc in studentsSnap.docs) {
        final studentData = studentDoc.data();
        final rollNumber = studentData['rollNumber'] as String? ?? '';
        final name = studentData['displayName'] as String? ?? 'Unknown';

        // Calculate total score from all core subjects
        double totalScore = 0;
        for (final subject in _coreSubjects) {
          final marksSnap = await FirebaseFirestore.instance
              .collection('test_marks')
              .where('classLevel', isEqualTo: _selectedClass)
              .where('subject', isEqualTo: subject)
              .where('marksByRoll.$rollNumber', isNull: false)
              .get();

          for (final markDoc in marksSnap.docs) {
            final marksData = markDoc.data();
            final marksByRoll = marksData['marksByRoll'] as Map<String, dynamic>?;
            if (marksByRoll != null && marksByRoll.containsKey(rollNumber)) {
              totalScore += (marksByRoll[rollNumber] as num?)?.toDouble() ?? 0;
            }
          }
        }

        leaderboard.add(StudentLeaderboardItem(
          rollNumber: rollNumber,
          name: name,
          totalScore: totalScore,
        ));
      }

      // Sort by total score descending
      leaderboard.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      // Assign ranks
      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i].rank = i + 1;
      }

      setState(() {
        _leaderboard = leaderboard;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.amber.shade400,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.emoji_events, color: Colors.amber.shade700),
      );
    }
    if (rank == 2) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.emoji_events, color: Colors.blueGrey.shade600),
      );
    }
    if (rank == 3) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.brown.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.emoji_events, color: Colors.brown.shade600),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.deepBlue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Class Selector
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Class',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (index) {
                  final classNum = index + 5;
                  final isSelected = _selectedClass == classNum;
                  return FilterChip(
                    label: Text('Class $classNum'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedClass = selected ? classNum : null);
                      if (selected) {
                        _loadLeaderboard();
                      } else {
                        setState(() => _leaderboard = []);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.deepBlue,
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Leaderboard List
        Expanded(
          child: _selectedClass == null
              ? const Center(
                  child: Text(
                    'Please select a class',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : _loading
                  ? const Center(child: Text('Loading...'))
                  : _leaderboard.isEmpty
                      ? const Center(
                          child: Text(
                            'No marks available for this class',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaderboard.length,
                          itemBuilder: (context, index) {
                            final item = _leaderboard[index];
                            final isTop3 = item.rank != null && item.rank! <= 3;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isTop3 ? 4 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isTop3
                                      ? AppTheme.deepBlue.withValues(alpha: 0.3)
                                      : Colors.grey.shade300!,
                                  width: isTop3 ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: _buildRankBadge(item.rank ?? 0),
                                title: Text(
                                  item.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Roll: ${item.rollNumber}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item.totalScore.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.deepBlue,
                                      ),
                                    ),
                                    Text(
                                      'Total',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Footer
        if (_leaderboard.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Total score calculated from SST, Science, Maths, and English',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}
