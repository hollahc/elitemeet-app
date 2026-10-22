import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
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
  StreamSubscription<PendingVerification>? _verifySub;
  double _bottomInset = 0;

  @override
  void initState() {
    super.initState();
    _service = WebViewService(
      callbacks: WebViewServiceCallbacks(
        onProgress: (progress) => setState(() => _progress = progress),
        onPageFinished: () {
          setState(() {
            _isLoading = false;
            _errorDescription = null;
          });
          // Some WebView implementations reset injected `window.*` objects
          // on navigation — re-install defensively after every page load.
          _bridge.reinject();
          _sendBottomInset();
        },
        onError: (description) => setState(() {
          _isLoading = false;
          _errorDescription = description;
        }),
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

    // Section 23: react to connectivity proactively rather than only after
    // a load has already failed, and auto-retry once connectivity returns.
    _isOffline = !ConnectivityService.instance.isOnline.value;
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);

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

  void _onExternalDeepLink(Uri uri) {
    _service.controller.loadRequest(uri);
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
    if (online && wasOffline) {
      _retry();
    }
  }

  void _onTokenChanged() {
    _bridge.sendTokenUpdate(NotificationService.instance.currentToken.value);
  }

  void _onDeepLink() {
    final target = NotificationService.instance.pendingDeepLink.value;
    if (target == null || target.isEmpty) return;

    final resolved = target.startsWith('http')
        ? target
        : Uri.parse(AppConfig.websiteUrl).resolve(target).toString();

    _service.controller.loadRequest(Uri.parse(resolved));

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
    ConnectivityService.instance.isOnline.removeListener(_onConnectivityChanged);
    PurchaseService.instance.lastResult.removeListener(_onPurchaseResult);
    _verifySub?.cancel();
    DeepLinkService.instance.onInternalLink = null;
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    // Keep the custom error screen up while retrying; it's cleared only when
    // a load actually succeeds (onPageFinished), so it never flickers to the
    // WebView's own error page between attempts.
    if (_errorDescription == null && !_isOffline) {
      setState(() {
        _isLoading = true;
        _progress = 0;
      });
    }
    await _service.reload();
  }

  Future<bool> _onWillPop() async {
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
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        // Same navy as the site's background/bottom nav, so anything showing
        // around the WebView (e.g. while loading) blends in.
        backgroundColor: const Color(0xFF091123),
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
              if (_errorDescription != null || _isOffline)
                ErrorView(onRetry: _retry, offline: _isOffline || !ConnectivityService.instance.isOnline.value),
            ],
          ),
        ),
      ),
    );
  }
}
