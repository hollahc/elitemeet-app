import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:elitemeet_app/models/notification_payload.dart';

void main() {
  group('NotificationPayload.fromRemoteMessage', () {
    test('extracts title, body, and target URL from a full payload', () {
      const message = RemoteMessage(
        notification: RemoteNotification(
          title: 'New message',
          body: 'You have a new message from Alex',
        ),
        data: {'url': '/messages/123'},
      );

      final payload = NotificationPayload.fromRemoteMessage(message);

      expect(payload.title, 'New message');
      expect(payload.body, 'You have a new message from Alex');
      expect(payload.targetUrl, '/messages/123');
    });

    test('targetUrl is null when data has no url field', () {
      const message = RemoteMessage(
        notification: RemoteNotification(title: 'Hi', body: 'Hello'),
        data: {},
      );

      final payload = NotificationPayload.fromRemoteMessage(message);

      expect(payload.targetUrl, isNull);
    });

    test('handles a data-only message with no notification block', () {
      const message = RemoteMessage(
        data: {'url': '/promo/summer-sale'},
      );

      final payload = NotificationPayload.fromRemoteMessage(message);

      expect(payload.title, isNull);
      expect(payload.body, isNull);
      expect(payload.targetUrl, '/promo/summer-sale');
    });

    test('rawData preserves every field, not just url', () {
      const message = RemoteMessage(
        data: {'url': '/messages/1', 'senderId': 'user_42'},
      );

      final payload = NotificationPayload.fromRemoteMessage(message);

      expect(payload.rawData['senderId'], 'user_42');
    });
  });
}
