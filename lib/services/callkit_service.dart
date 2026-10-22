import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'notification_service.dart';

/// Native incoming-call screen (Android) for EliteMeet voice/video calls.
///
/// The server sends a high-priority data push ("incoming_call") when someone
/// calls. On Android we show a full-screen ringing call UI — over the lock
/// screen and other apps, like WhatsApp/Telegram — with Accept / Decline:
///  - Accept → opens the app on `/call/{match}?call={id}&answer=1` (the web
///    call screen answers and connects).
///  - Decline → tells the server straight away via the signed action URL in
///    the push, even if the app was closed.
/// "call_ended" pushes (answered elsewhere, cancelled, missed) stop the ring.
///
/// iOS: the full CallKit experience needs Apple VoIP (PushKit) pushes, which
/// FCM can't send — iOS gets a time-sensitive alert instead and the in-app
/// ringing screen when opened.
class CallkitService {
  CallkitService._();
  static final CallkitService instance = CallkitService._();

  StreamSubscription<CallEvent?>? _sub;

  static bool get supported => Platform.isAndroid;

  Future<void> initialize() async {
    if (!supported) return;
    try {
      await FlutterCallkitIncoming.onBackgroundMessage(callkitBackgroundHandler);
    } catch (e) {
      debugPrint('[CallkitService] background handler registration failed: $e');
    }
    _sub = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event is CallEventActionCallAccept) {
        await _openAnsweredCall(event.callKitParams);
      } else if (event is CallEventActionCallDecline) {
        await declineRemote(event.callKitParams.extra);
      }
    });

    // App launched by tapping Accept while it was fully closed: the accept
    // event may have fired before we were listening.
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final c in calls) {
        if (c.isAccepted) await _openAnsweredCall(c);
      }
    } catch (_) {}
  }

  Future<void> _openAnsweredCall(CallKitParams params) async {
    final extra = params.extra ?? const {};
    final link = extra['answer_url'] as String?;
    if (link != null && link.isNotEmpty) {
      NotificationService.instance.pendingDeepLink.value = link;
    }
    // The web call screen takes over from here; clear the native call.
    Future<void>.delayed(const Duration(seconds: 2), () => FlutterCallkitIncoming.endCall(params.id));
  }

  /// Android 14+: full-screen incoming calls need a user-granted permission.
  /// Asked together with notification permission.
  static Future<void> ensureFullScreenPermission() async {
    if (!supported) return;
    try {
      if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      debugPrint('[CallkitService] full-screen permission: $e');
    }
  }

  /// Show the native ringing screen for an "incoming_call" push.
  static Future<void> showIncoming(Map<String, dynamic> data) async {
    if (!supported) return;
    final callId = data['call_id'] as String?;
    if (callId == null || callId.isEmpty) return;
    // Pushes delivered late (phone was offline) shouldn't start ringing.
    final sentAt = int.tryParse('${data['sent_at'] ?? ''}');
    if (sentAt != null && DateTime.now().millisecondsSinceEpoch - sentAt > 45000) return;

    final video = data['mode'] == 'video';
    final photo = (data['caller_photo'] as String?) ?? '';
    final params = CallKitParams(
      id: callId,
      nameCaller: (data['caller_name'] as String?) ?? 'EliteMeet',
      appName: 'EliteMeet',
      avatar: photo.isNotEmpty ? photo : null,
      handle: video ? 'EliteMeet video call' : 'EliteMeet voice call',
      type: video ? 1 : 0,
      duration: 45000,
      extra: Map<String, dynamic>.from(data),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B0718',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        isImportant: true,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Stop ringing (answered on another device, cancelled, missed).
  static Future<void> end(String? callId) async {
    if (!supported || callId == null || callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  /// Decline without a signed-in session: the push carries a per-call HMAC.
  static Future<void> declineRemote(Map<String, dynamic>? extra) async {
    final url = extra?['action_url'] as String?;
    final callId = extra?['call_id'] as String?;
    final sig = extra?['sig'] as String?;
    if (url == null || callId == null || sig == null) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'call_id': callId, 'action': 'decline', 'sig': sig}));
      final res = await req.close();
      await res.drain<void>();
    } catch (e) {
      debugPrint('[CallkitService] decline failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  void dispose() => _sub?.cancel();
}

/// Runs in a background isolate when the user declines while the app is closed.
@pragma('vm:entry-point')
Future<void> callkitBackgroundHandler(CallEvent event) async {
  if (event is CallEventActionCallDecline) {
    await CallkitService.declineRemote(event.callKitParams.extra);
  }
}
