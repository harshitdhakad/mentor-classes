import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/erp_providers.dart';
import '../auth/auth_service.dart';
import 'resource_upload_screen.dart';
import 'resources_view_screen.dart';

/// Enhanced Academic Hub with resource management
class AcademicResourceHubScreen extends ConsumerStatefulWidget {
  const AcademicResourceHubScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AcademicResourceHubScreen> createState() =>
      _AcademicResourceHubScreenState();
}

class _AcademicResourceHubScreenState
    extends ConsumerState<AcademicResourceHubScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedClass = ref.watch(selectedClassProvider);
    final selectedResourceType = ref.watch(selectedResourceTypeProvider);
    final user = ref.watch(authProvider);
    final isStudent = user?.role.name == 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Academic Resources'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.deepBlueContainer,
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.deepBlueContainer, AppTheme.deepBluePrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Class: $selectedClass',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (selectedResourceType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedResourceType == 'notes'
                              ? '📝 Notes'
                              : selectedResourceType == 'test_papers'
                                  ? '📄 Test Papers'
                                  : '✏️ Worksheets',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab Navigation
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(
                    icon: '📝',
                    label: 'Notes',
                    index: 0,
                    isActive: _currentTabIndex == 0,
                  ),
                  _buildTabButton(
                    icon: '📄',
                    label: 'Test Papers',
                    index: 1,
                    isActive: _currentTabIndex == 1,
                  ),
                  _buildTabButton(
                    icon: '✏️',
                    label: 'Worksheets',
                    index: 2,
                    isActive: _currentTabIndex == 2,
                  ),
                  if (!isStudent)
                    _buildTabButton(
                      icon: '⬆️',
                      label: 'Upload',
                      index: 3,
                      isActive: _currentTabIndex == 3,
                    ),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentTabIndex = index);
              },
              children: [
                ResourcesViewScreen(resourceType: 'notes'),
                ResourcesViewScreen(resourceType: 'test_papers'),
                ResourcesViewScreen(resourceType: 'worksheets'),
                if (!isStudent) const ResourceUploadScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.deepBluePrimary : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.deepBluePrimary : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
