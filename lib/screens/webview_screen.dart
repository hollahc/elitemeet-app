import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import '../services/call_audio_service.dart';
import '../services/callkit_service.dart';
import '../services/connectivity_service.dart';
import '../services/deep_link_service.dart';
import '../services/javascript_bridge.dart';
import '../services/notification_service.dart';
import '../services/purchase_router.dart';
import '../services/purchase_service.dart';
import '../services/webview_service.dart';
import '../widgets/app_loading.dart';
import '../widgets/error_view.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewService _service;
  late final JavaScriptBridge _bridge;

  bool _isLoading = true;
  int _progress = 0;
  String? _errorDescription;
  bool _isOffline = false;
  double _bottomInset = 0;

  /// A page has loaded successfully. From then on a connection blip (common
  /// when switching apps) shows a small banner instead of covering the page —
  /// the full-screen error used to hide an ongoing call — and doesn't reload.
  bool _pageLoaded = false;

  /// A notification / link that arrived during a call; opened once it ends.
  Uri? _deferredLink;
  StreamSubscription<PendingVerification>? _verifySub;

  @override
  void initState() {
    super.initState();
    _service = WebViewService(
      callbacks: WebViewServiceCallbacks(
        onProgress: (progress) => setState(() => _progress = progress),
        onPageFinished: () {
          // A full page load ends any call the previous page had.
          CallAudioService.instance.inCall.value = false;
          setState(() {
            _isLoading = false;
            _errorDescription = null;
            _pageLoaded = true;
          });
          // Some WebView implementations reset injected `window.*` objects
          // on navigation — re-install defensively after every page load.
          _bridge.reinject();
          _sendBottomInset();
        },
        onError: (description) {
          // Never cover a live call; it reconnects by itself.
          if (CallAudioService.instance.inCall.value) return;
          setState(() {
            _isLoading = false;
            _errorDescription = description;
          });
        },
        onPurchaseRoute: (path) => PurchaseRouter.instance.routeWebPath(path),
        onChoosePhotoSource: _choosePhotoSource,
        onJsAlert: _jsAlert,
        onJsConfirm: _jsConfirm,
        onJsPrompt: _jsPrompt,
      ),
    );

    _bridge = JavaScriptBridge(
      controller: _service.controller,
      onPurchaseRequested: (productId, {accountId, subscription}) {
        PurchaseRouter.instance.routeProductId(
          productId,
          accountId: accountId,
          subscription: subscription,
        );
      },
    );
    _bridge.install();

    _service.loadInitialUrl();

    // Section 12: a notification tap (foreground, background, or terminated
    // launch) sets this — navigate the WebView to the internal URL and keep
    // it inside the WebView rather than opening a browser.
    NotificationService.instance.pendingDeepLink.addListener(_onDeepLink);
    // A notification tap / answered call that happened before this screen
    // existed (cold start) is already waiting — open it.
    if (NotificationService.instance.pendingDeepLink.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onDeepLink());
    }

    // Section 11 step 4: token refreshes must update the website, not just
    // the initial token.
    NotificationService.instance.currentToken.addListener(_onTokenChanged);
    CallkitService.instance.voipToken.addListener(_onVoipTokenChanged);

    // Section 23: react to connectivity proactively rather than only after
    // a load has already failed, and auto-retry once connectivity returns.
    _isOffline = !ConnectivityService.instance.isOnline.value;
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
    CallAudioService.instance.inCall.addListener(_onInCallChanged);

    // Section 50/51: forward the verified purchase outcome back to the
    // page as `elitemeetPurchaseComplete`.
    PurchaseService.instance.lastResult.addListener(_onPurchaseResult);

    // Completed store transactions go to the page for server verification.
    // (Anything missed here — page not loaded yet, user signed out — stays
    // queued and the page pulls it via getPendingPurchases on load.)
    _verifySub = PurchaseService.instance.verificationRequests.listen(
      _bridge.sendPurchaseForVerification,
    );

    // Section 27: App Links / Universal Links. Callback must be set before
    // initialize() so a cold-start deep link (app launched directly from
    // the link) isn't missed.
    DeepLinkService.instance.onInternalLink = _onExternalDeepLink;
    DeepLinkService.instance.initialize();
  }

  void _onExternalDeepLink(Uri uri) => _open(uri);

  /// Loads [uri] in the WebView — unless a call is live, since loading a new
  /// page would drop it. Then it waits until the call ends.
  void _open(Uri uri) {
    if (CallAudioService.instance.inCall.value) {
      _deferredLink = uri;
      return;
    }
    _service.controller.loadRequest(uri);
  }

  void _onInCallChanged() {
    final link = _deferredLink;
    if (!CallAudioService.instance.inCall.value && link != null) {
      _deferredLink = null;
      _service.controller.loadRequest(link);
    }
  }

  void _onPurchaseResult() {
    final result = PurchaseService.instance.lastResult.value;
    if (result == null) return;
    _bridge.sendPurchaseResult(
      productId: result.productId,
      status: switch (result.outcome) {
        PurchaseOutcome.success || PurchaseOutcome.restored => 'purchased',
        PurchaseOutcome.cancelled => 'cancelled',
        PurchaseOutcome.pending => 'pending',
        PurchaseOutcome.error => 'error',
      },
      errorMessage: result.errorMessage,
    );
  }

  void _onConnectivityChanged() {
    final online = ConnectivityService.instance.isOnline.value;
    final wasOffline = _isOffline;
    setState(() => _isOffline = !online);
    // Reload only a page that failed; a loaded page (and any call on it)
    // reconnects by itself — reloading it would hang up the call.
    if (online && wasOffline && (_errorDescription != null || !_pageLoaded)) {
      _retry();
    }
  }

  void _onTokenChanged() {
    _bridge.sendTokenUpdate(NotificationService.instance.currentToken.value);
  }

  void _onVoipTokenChanged() {
    _bridge.sendVoipTokenUpdate(CallkitService.instance.voipToken.value);
  }

  void _onDeepLink() {
    final target = NotificationService.instance.pendingDeepLink.value;
    if (target == null || target.isEmpty) return;

    final resolved = target.startsWith('http')
        ? target
        : Uri.parse(AppConfig.websiteUrl).resolve(target).toString();

    _open(Uri.parse(resolved));

    // Consume it so re-navigating within the app doesn't re-trigger this.
    NotificationService.instance.pendingDeepLink.value = null;
  }

  Future<void> _jsAlert(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<bool> _jsConfirm(String message) async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _jsPrompt(String message, String? defaultText) async {
    if (!mounted) return null;
    final field = TextEditingController(text: defaultText ?? '');
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(controller: field, autofocus: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      field.dispose();
    }
  }

  /// Camera / Gallery sheet for the page's photo inputs (what Chrome shows
  /// for an <input type="file" accept="image/*">).
  Future<PhotoSource?> _choosePhotoSource() {
    if (!mounted) return Future.value(null);
    return showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.instance.pendingDeepLink.removeListener(_onDeepLink);
    NotificationService.instance.currentToken.removeListener(_onTokenChanged);
    CallkitService.instance.voipToken.removeListener(_onVoipTokenChanged);
    ConnectivityService.instance.isOnline.removeListener(_onConnectivityChanged);
    CallAudioService.instance.inCall.removeListener(_onInCallChanged);
    PurchaseService.instance.lastResult.removeListener(_onPurchaseResult);
    _verifySub?.cancel();
    DeepLinkService.instance.onInternalLink = null;
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _errorDescription = null;
      _progress = 0;
    });
    await _service.reload();
  }

  Future<bool> _onWillPop() async {
    // Android back during a call would leave the call page and hang up.
    // Like a phone call, it's ended with the End button instead.
    if (CallAudioService.instance.inCall.value) return false;
    final handled = await _service.handleBackPress();
    return !handled; // if the WebView handled it, don't also pop the route
  }

  /// The bottom inset goes to the page as CSS variables (the WebView draws
  /// under the system bar so the site's tab bar can sit at the very bottom).
  /// `padding`, not `viewPadding`: it drops to 0 while the keyboard is up,
  /// when the body is already resized above it.
  void _sendBottomInset() {
    final bottom = _bottomInset;
    // iOS: let the tab bar overlap the home indicator a little, as the site
    // does in Safari. Android's nav bar holds buttons, so keep fully clear.
    final navSafe = Platform.isIOS ? math.max(0.0, bottom - 14) : bottom;
    _bridge.setBottomInset(safeBottom: bottom, navSafe: navSafe);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (bottomInset != _bottomInset) {
      _bottomInset = bottomInset;
      _sendBottomInset();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          // Nothing left in WebView history and nothing above this route —
          // let the platform's normal "press back again to exit" / app-exit
          // behavior take over rather than force-closing here.
          Navigator.of(this.context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        // Bottom is left to the page: the WebView runs to the screen edge and
        // the site pads its tab bar by the inset sent in _sendBottomInset.
        // Keeping it here left an empty band under the tab bar.
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _service.controller),
              if (_isLoading && _errorDescription == null && !_isOffline)
                AppLoading(progress: _progress),
              if (_errorDescription != null || (_isOffline && !_pageLoaded))
                ErrorView(onRetry: _retry)
              else if (_isOffline)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: _OfflineBanner()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin, non-blocking notice shown over an already-loaded page.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE6B00020),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Text(
        'No connection — reconnecting…',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
