import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import 'call_audio_service.dart';
import 'callkit_service.dart';
import 'notification_service.dart';
import 'purchase_service.dart';

/// Implements the `window.EliteMeetApp` JavaScript API — the documented
/// contract between the native app and elitemeet.net. See
/// docs/WEBVIEW_BRIDGE.md and docs/WEBSITE_INTEGRATION.md for the full
/// versioned spec ("EliteMeetApp API v1").
///
/// Deliberately narrow surface: only what the website actually needs is
/// exposed, nothing that reaches into native internals unnecessarily
/// (Section 25 — no dangerous JS interfaces).
class JavaScriptBridge {
  final WebViewController controller;

  /// Called when the website requests a purchase via
  /// `window.EliteMeetApp.purchase({...})`. Wired to the purchase router in
  /// a later step; kept as an injectable callback here so this file has no
  /// direct dependency on billing code.
  final void Function(String productId, {String? accountId, bool? subscription})
      onPurchaseRequested;

  JavaScriptBridge({
    required this.controller,
    required this.onPurchaseRequested,
  });

  /// Installs the `window.EliteMeetApp` object and registers the Flutter
  /// side channel it posts messages to. Call once after the controller is
  /// created, before the first page load, so the object exists from the
  /// very first script execution on the page.
  Future<void> install() async {
    await controller.addJavaScriptChannel(
      'EliteMeetNative',
      onMessageReceived: _onMessageFromWeb,
    );

    await controller.runJavaScript(_bridgeScript());
  }

  /// Re-injects the bridge script. Some WebView implementations reset JS
  /// channels' associated `window.*` objects on navigation — call this from
  /// `onPageFinished` to be safe rather than assuming it survives.
  Future<void> reinject() => controller.runJavaScript(_bridgeScript());

  /// Hands the page the bottom system inset (home indicator / Android nav
  /// bar) the WebView now draws under. The site reads these in `html.in-app`
  /// to pad its tab bar and bottom sheets: `navSafe` for the tab bar, which
  /// may sit partly over the iOS home indicator, `safeBottom` for the rest.
  Future<void> setBottomInset({required double safeBottom, required double navSafe}) {
    return controller.runJavaScript(
      "(function(){var s=document.documentElement.style;"
      "s.setProperty('--app-safe-bottom','${safeBottom}px');"
      "s.setProperty('--app-nav-safe','${navSafe}px');})();",
    );
  }

  /// Pushes a device token update to the page (initial token or a refresh).
  /// Fires the same event the page listens for after calling
  /// `getDeviceToken()`, so both paths (pull and push) use one code path on
  /// the JS side.
  Future<void> sendTokenUpdate(String? token) async {
    final encoded = token == null ? 'null' : jsonEncode(token);
    await controller.runJavaScript(
      "window.dispatchEvent(new CustomEvent('elitemeetTokenUpdate', "
      "{ detail: { token: $encoded } }));",
    );
  }

  /// iOS: a new PushKit (VoIP) token for the page to register, like
  /// [sendTokenUpdate] does for the FCM token.
  Future<void> sendVoipTokenUpdate(String? token) async {
    final detail = jsonEncode(
      token == null ? null : {'token': token, 'environment': CallkitService.voipEnvironment},
    );
    await controller.runJavaScript(
      "window.dispatchEvent(new CustomEvent('elitemeetVoipTokenUpdate', { detail: $detail }));",
    );
  }

  /// Notifies the page that a purchase finished (success or failure). See
  /// Section 50 — the page must not treat this alone as proof of payment;
  /// backend verification is the source of truth.
  /// Hands a completed store transaction to the page for server
  /// verification. The page answers with `finishPurchase({key, ok})`.
  Future<void> sendPurchaseForVerification(PendingVerification item) async {
    await controller.runJavaScript(
      "window.dispatchEvent(new CustomEvent('elitemeetPurchaseVerify', "
      "{ detail: ${jsonEncode(item.toJson())} }));",
    );
  }

  Future<void> sendPurchaseResult({
    required String productId,
    required String status, // 'cancelled' | 'pending' | 'error'
    String? errorMessage,
  }) async {
    final detail = jsonEncode({
      'productId': productId,
      'status': status,
      if (errorMessage != null) 'errorMessage': errorMessage,
    });
    await controller.runJavaScript(
      "window.dispatchEvent(new CustomEvent('elitemeetPurchaseComplete', "
      "{ detail: $detail }));",
    );
  }

  Future<void> _onMessageFromWeb(JavaScriptMessage message) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[JavaScriptBridge] Malformed message from web: ${message.message}');
      return;
    }

    final method = payload['method'] as String?;
    final requestId = payload['requestId'] as String?;
    final args = payload['args'] as Map<String, dynamic>? ?? const {};

    switch (method) {
      case 'getPlatform':
        await _respond(requestId, _platformName());
        break;

      case 'getAppVersion':
        final info = await PackageInfo.fromPlatform();
        await _respond(requestId, info.version);
        break;

      case 'getDeviceToken':
        final token = await NotificationService.instance.getToken();
        await _respond(requestId, token);
        break;

      case 'getVoipToken':
        // iOS only: PushKit token for full-screen (CallKit) incoming calls.
        final voip = CallkitService.instance.voipToken.value;
        await _respond(
          requestId,
          voip == null ? null : {'token': voip, 'environment': CallkitService.voipEnvironment},
        );
        break;

      case 'requestNotificationPermission':
        final granted = await NotificationService.instance.requestPermission();
        await _respond(requestId, granted);
        break;

      case 'purchase':
        final productId = args['productId'] as String?;
        if (productId != null) {
          onPurchaseRequested(
            productId,
            accountId: args['accountId'] as String?,
            subscription: args['subscription'] as bool?,
          );
        }
        // Resolves immediately; the outcome arrives later via the
        // `elitemeetPurchaseVerify` / `elitemeetPurchaseComplete` events.
        await _respond(requestId, true);
        break;

      case 'getProducts':
        final ids = (args['productIds'] as List?)?.whereType<String>().toList() ?? const <String>[];
        await _respond(requestId, await PurchaseService.instance.getProducts(ids));
        break;

      case 'getPendingPurchases':
        await _respond(
          requestId,
          PurchaseService.instance.pending.map((p) => p.toJson()).toList(),
        );
        break;

      case 'finishPurchase':
        final key = args['key'] as String?;
        if (key != null) {
          await PurchaseService.instance.finishPurchase(key, ok: args['ok'] == true);
        }
        await _respond(requestId, true);
        break;

      case 'callAudio':
        // action: "start" | "stop"; speaker: bool (start only)
        final action = args['action'] as String?;
        final ok = action == 'stop'
            ? await CallAudioService.instance.stop()
            : await CallAudioService.instance.start(speaker: args['speaker'] == true);
        await _respond(requestId, ok);
        break;

      case 'setSpeakerphone':
        await _respond(requestId, await CallAudioService.instance.setSpeakerphone(args['on'] == true));
        break;

      case 'restorePurchases':
        await PurchaseService.instance.restorePurchases();
        await _respond(requestId, true);
        break;

      case 'openStore':
        // Handled by the platform's own "open app store listing" intent —
        // routed through url_router / native intent in a later step if
        // EliteMeet needs an in-app "rate us" flow. No-op placeholder for
        // now so the call doesn't throw on the JS side.
        break;

      default:
        debugPrint('[JavaScriptBridge] Unknown method: $method');
    }
  }

  Future<void> _respond(String? requestId, Object? value) async {
    if (requestId == null) return;
    final encoded = jsonEncode(value);
    await controller.runJavaScript(
      "window.EliteMeetApp && window.EliteMeetApp._resolve('$requestId', $encoded);",
    );
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// The injected script defines `window.EliteMeetApp` with promise-based
  /// methods. Each call posts a JSON message to the `EliteMeetNative`
  /// channel and resolves a pending Promise when Flutter calls `_resolve`.
  String _bridgeScript() {
    return '''
(function () {
  if (window.EliteMeetApp && window.EliteMeetApp.__version === 1 && window.EliteMeetApp.getVoipToken) return;

  var pending = {};
  var counter = 0;

  function call(method, args) {
    return new Promise(function (resolve) {
      var requestId = 'req_' + (++counter);
      pending[requestId] = resolve;
      window.EliteMeetNative.postMessage(JSON.stringify({
        method: method,
        args: args || {},
        requestId: requestId
      }));
    });
  }

  window.EliteMeetApp = {
    __version: 1,
    platform: '${_platformName()}',
    version: '${AppConfig.appVersion}',

    getPlatform: function () { return call('getPlatform'); },
    getAppVersion: function () { return call('getAppVersion'); },
    getDeviceToken: function () { return call('getDeviceToken'); },
    getVoipToken: function () { return call('getVoipToken'); },
    requestNotificationPermission: function () { return call('requestNotificationPermission'); },
    purchase: function (args) { return call('purchase', args); },
    getProducts: function (args) { return call('getProducts', args); },
    getPendingPurchases: function () { return call('getPendingPurchases'); },
    finishPurchase: function (args) { return call('finishPurchase', args); },
    restorePurchases: function () { return call('restorePurchases'); },
    callAudio: function (args) { return call('callAudio', args); },
    setSpeakerphone: function (args) { return call('setSpeakerphone', args); },
    openStore: function () { return call('openStore'); },

    _resolve: function (requestId, value) {
      var resolve = pending[requestId];
      if (resolve) {
        resolve(value);
        delete pending[requestId];
      }
    }
  };
})();
''';
  }
}
