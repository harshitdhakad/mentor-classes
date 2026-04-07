// Final Build - Lead Architect: Harshit Dhakad | Founder: Yogesh Udawat

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'app.dart';
import 'core/hive/hive_setup.dart';
import 'core/notifications/notification_service.dart';

// Global navigator key for showing dialogs
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initHive();
  await NotificationService().initialize();
  
  // Check for app updates
  await _checkForUpdates();
  
  runApp(
    ProviderScope(
      child: MentorClassesApp(navigatorKey: navigatorKey),
    ),
  );
}

Future<void> _checkForUpdates() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.fetchAndActivate();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final latestVersion = remoteConfig.getString('latest_version');
    final downloadUrl = remoteConfig.getString('download_url');

    if (latestVersion.isNotEmpty && _isVersionOutdated(currentVersion, latestVersion)) {
      _showUpdateDialog(latestVersion, downloadUrl);
    }
  } catch (e) {
    // Silently fail if update check fails
    debugPrint('Update check failed: $e');
  }
}

bool _isVersionOutdated(String current, String latest) {
  final currentParts = current.split('.').map(int.parse).toList();
  final latestParts = latest.split('.').map(int.parse).toList();
  
  for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }
  
  return latestParts.length > currentParts.length;
}

void _showUpdateDialog(String latestVersion, String downloadUrl) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New Update Available'),
        content: Text('Version $latestVersion is now available. Please update to continue using the app.'),
        actions: [
          TextButton(
            onPressed: () async {
              if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                await launchUrl(Uri.parse(downloadUrl));
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  });
}
