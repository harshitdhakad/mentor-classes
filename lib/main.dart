// Final Build - Lead Architect: Harshit Dhakad | Founder: Yogesh Udawat

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/hive/hive_setup.dart';
import 'core/notifications/notification_service.dart';
import 'services/cleanup_service.dart';

// Global navigator key for showing dialogs
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const String _adminResetKey = 'admin_reset_timestamp';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter की तरफ से होने वाले एरर को पकड़ें
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      // अगर हम Debug मोड में हैं, तो टर्मिनल में प्रिंट करें
      print('=============================================');
      print('🔴 CRITICAL ERROR DETECTED:');
      print(details.exception);
      print('=============================================');
    }
  };

  // Firebase Initialize - MUST complete before app starts
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('⚠️ App will continue but Firebase features may not work');
  }

  // Check if admin reset occurred and clear Firestore persistence (AFTER Firebase is initialized)
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastResetTimestamp = prefs.getInt(_adminResetKey);
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    // If reset occurred within last 5 minutes, clear persistence
    if (lastResetTimestamp != null && (currentTimestamp - lastResetTimestamp) < 300000) {
      debugPrint('🔄 Admin reset detected - clearing Firestore persistence...');
      try {
        await FirebaseFirestore.instance.clearPersistence();
        debugPrint('✅ Firestore persistence cleared successfully');
        // Clear the flag after clearing
        await prefs.remove(_adminResetKey);
      } catch (e) {
        debugPrint('⚠️ Error clearing Firestore persistence: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error checking admin reset: $e');
  }

  // Temporarily disable persistence to clear old cached 'millisecond' data
  try {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } catch (e) {
    debugPrint('⚠️ Error setting Firestore persistence: $e');
  }
  
  try {
    // Other Services
    await initHive().timeout(const Duration(seconds: 5));
    debugPrint('✅ Hive initialized');
  } catch (e) {
    debugPrint('❌ Hive init error: $e');
  }
  
  try {
    await NotificationService().initialize().timeout(const Duration(seconds: 5));
    debugPrint('✅ Notification service initialized');
  } catch (e) {
    debugPrint('❌ Notification service init error: $e');
  }

  // Start cleanup service for automatic homework deletion
  try {
    CleanupService().startPeriodicCleanup();
    debugPrint('✅ Cleanup service started');
  } catch (e) {
    debugPrint('❌ Cleanup service start error: $e');
  }

  // Start app after all services are initialized
  debugPrint('🚀 Starting app...');
  runApp(
    ProviderScope(
      child: MentorClassesApp(navigatorKey: navigatorKey),
    ),
  );

  // 2. Check updates in background (non-blocking)
  Future.delayed(const Duration(seconds: 2), () {
    _checkForUpdates().catchError((e) {
      debugPrint('❌ Update check error: $e');
    });
  });
}

Future<void> _checkForUpdates() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Remote Config से डेटा लाओ
    await remoteConfig.fetchAndActivate();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final latestVersion = remoteConfig.getString('latest_version');
    final downloadUrl = remoteConfig.getString('download_url');

    // अगर डेटा मिल गया है और वर्जन पुराना है, तब डायलॉग दिखाओ
    if (latestVersion.isNotEmpty && downloadUrl.isNotEmpty && _isVersionOutdated(currentVersion, latestVersion)) {
      _showUpdateDialog(latestVersion, downloadUrl);
    }
  } catch (e) {
    // अगर इंटरनेट नहीं है या कोई एरर है, तो ऐप रुकनी नहीं चाहिए
    debugPrint('Update check failed: $e');
  }
}

bool _isVersionOutdated(String current, String latest) {
  try {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    return latestParts.length > currentParts.length;
  } catch (e) {
    return false;
  }
}

void _showUpdateDialog(String latestVersion, String downloadUrl) {
  // PostFrameCallback यह पक्का करता है कि डायलॉग तब खुले जब ऐप पूरी तरह लोड हो चुकी हो
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('New Update Available'),
          content: Text('Version $latestVersion is now available. Please update to continue using the app.'),
          actions: [
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    }
  });
}
