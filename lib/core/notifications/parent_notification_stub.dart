import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Send push notification via FCM.
Future<void> sendParentNotification({
  required String title,
  required String body,
  Map<String, String>? meta,
}) async {
  // In a real app, this would be done via Cloud Functions
  // For demo, we'll just print
  debugPrint(
    '[sendParentNotification] $title — $body ${meta ?? {}}',
  );

  // TODO: Implement FCM sending via Cloud Functions or server
  // Example: Use Firebase Admin SDK in Cloud Functions to send to topic or tokens
}
