import 'package:firebase_messaging/firebase_messaging.dart';

/// Parsed representation of an incoming FCM message.
///
/// EliteMeet's FCM payloads are expected to carry a `data` field named
/// `url` pointing at an internal elitemeet.net path/URL to navigate to on
/// tap (see docs/WEBSITE_INTEGRATION.md for the exact contract the backend
/// must send).
class NotificationPayload {
  final String? title;
  final String? body;

  /// Internal URL to navigate the WebView to when this notification is
  /// tapped, if provided.
  final String? targetUrl;

  final Map<String, dynamic> rawData;

  const NotificationPayload({
    this.title,
    this.body,
    this.targetUrl,
    required this.rawData,
  });

  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    return NotificationPayload(
      title: message.notification?.title,
      body: message.notification?.body,
      // The backend sends `link`; `url` kept for older payloads.
      targetUrl: (message.data['url'] ?? message.data['link']) as String?,
      rawData: message.data,
    );
  }

  @override
  String toString() =>
      'NotificationPayload(title: $title, targetUrl: $targetUrl)';
}
