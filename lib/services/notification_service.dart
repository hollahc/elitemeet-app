import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase_options.dart';
import '../models/notification_payload.dart';
import 'callkit_service.dart';

/// Top-level background message handler — required by firebase_messaging to
/// live outside any class, since it runs in a separate isolate when the app
/// is terminated. Keep this minimal; do not touch UI state here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in this background isolate too.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Calls: data-only pushes → native full-screen ringing screen (Android).
  final type = message.data['type'];
  if (type == 'incoming_call') {
    await CallkitService.showIncoming(message.data);
  } else if (type == 'call_ended') {
    await CallkitService.end(message.data['call_id'] as String?);
  }
  // Everything else: the system tray shows the notification; taps are picked
  // up via getInitialMessage() / onMessageOpenedApp.
}

/// Owns Firebase initialization and the full FCM lifecycle: permission
/// request, token retrieval/refresh, and foreground/background/terminated
/// notification-tap handling.
///
/// This service does not touch the WebView directly — it exposes
/// [pendingDeepLink] and [onTokenRefresh] for the screen/bridge layer to
/// react to, keeping push logic independent of WebView plumbing.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ValueNotifier<String?> pendingDeepLink = ValueNotifier<String?>(null);
  final ValueNotifier<String?> currentToken = ValueNotifier<String?>(null);

  bool _initialized = false;

  /// Initializes Firebase and wires up all FCM listeners. Safe to call once
  /// at app startup. Wrapped so a missing google-services.json /
  /// GoogleService-Info.plist (before flutterfire configure has been run)
  /// doesn't crash the rest of the app — it just leaves push disabled.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      debugPrint('[NotificationService] Firebase init failed (expected until '
          'flutterfire configure has been run): $e\n$st');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // App was launched by tapping a notification while fully terminated.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      currentToken.value = token;
    });

    _initialized = true;
  }

  /// Requests notification permission at an appropriate contextual moment
  /// (e.g. right after login) — NOT on cold start. Handles Android 13+'s
  /// runtime `POST_NOTIFICATIONS` permission and iOS's system prompt.
  /// See docs/PUSH_NOTIFICATIONS.md for the recommended calling point.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      // Incoming calls ring full-screen like a phone call (Android 14+ asks
      // separately for this).
      if (status.isGranted) await CallkitService.ensureFullScreenPermission();
      return status.isGranted;
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Fetches (and caches) the current FCM token. Returns null if push isn't
  /// available (Firebase not configured yet, permission denied, etc.).
  Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      currentToken.value = token;
      return token;
    } catch (e) {
      debugPrint('[NotificationService] getToken failed: $e');
      return null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // While the app is open the website's own ringing screen handles incoming
    // calls; just make sure a native ring (from a background push) stops.
    if (message.data['type'] == 'call_ended') {
      CallkitService.end(message.data['call_id'] as String?);
      return;
    }
    if (message.data['type'] == 'incoming_call') return;
    // Foreground messages don't auto-display a system notification on
    // Android; a lightweight local notification would be shown here via
    // flutter_local_notifications in a follow-up pass if EliteMeet wants
    // foreground banners. For now we just log — deliberately not silently
    // dropped, so this is easy to find when wiring local notifications.
    debugPrint('[NotificationService] Foreground message: '
        '${NotificationPayload.fromRemoteMessage(message)}');
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);
    if (payload.targetUrl != null && payload.targetUrl!.isNotEmpty) {
      pendingDeepLink.value = payload.targetUrl;
    }
  }
}
