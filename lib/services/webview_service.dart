import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/app_config.dart';
import 'url_router.dart';

/// Where a photo picked for a page's file input comes from.
enum PhotoSource { camera, gallery }

/// Callbacks the screen layer supplies so this service can report state
/// without owning any UI itself.
class WebViewServiceCallbacks {
  final void Function(int progress) onProgress;
  final void Function() onPageFinished;
  final void Function(String description) onError;
  final void Function(String path) onPurchaseRoute;

  /// Asks the user Camera or Gallery when a page opens a file input
  /// (Android only — WKWebView shows its own sheet). Null = cancelled.
  final Future<PhotoSource?> Function() onChoosePhotoSource;

  /// The page's window.alert / confirm / prompt. Without these the WebView
  /// answers "cancel" instantly, so confirm-gated buttons did nothing.
  final Future<void> Function(String message) onJsAlert;
  final Future<bool> Function(String message) onJsConfirm;
  final Future<String?> Function(String message, String? defaultText) onJsPrompt;

  const WebViewServiceCallbacks({
    required this.onProgress,
    required this.onPageFinished,
    required this.onError,
    required this.onPurchaseRoute,
    required this.onChoosePhotoSource,
    required this.onJsAlert,
    required this.onJsConfirm,
    required this.onJsPrompt,
  });
}

/// Builds and configures the single WebViewController used by the app.
///
/// All WebView behavior policy (JS, storage, navigation delegate, user
/// agent) lives here so webview_screen.dart stays a thin UI layer.
class WebViewService {
  late final WebViewController controller;
  late final WebViewServiceCallbacks _callbacks;
  String? _currentUrl;
  bool _failedThisLoad = false;

  WebViewService({required WebViewServiceCallbacks callbacks}) {
    _callbacks = callbacks;
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: _onPermissionRequest,
    );

    _configure(callbacks);

    controller
      ..setOnJavaScriptAlertDialog((request) => callbacks.onJsAlert(request.message))
      ..setOnJavaScriptConfirmDialog((request) => callbacks.onJsConfirm(request.message))
      // A cancelled prompt must reach JS as null; the platform API takes a
      // String, and an empty string is the closest it allows.
      ..setOnJavaScriptTextInputDialog(
          (request) async => await callbacks.onJsPrompt(request.message, request.defaultText) ?? '');
  }

  void _configure(WebViewServiceCallbacks callbacks) {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF091123))
      ..setUserAgent(_buildUserAgent())
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: callbacks.onProgress,
          onPageStarted: (url) {
            _currentUrl = url;
            _failedThisLoad = false;
          },
          // A failed load still "finishes" — with the WebView's own error page.
          // Don't let that clear our custom error screen.
          onPageFinished: (_) {
            if (!_failedThisLoad) callbacks.onPageFinished();
          },
          onWebResourceError: (error) {
            // Only surface main-frame failures as a full error state; sub-
            // resource failures (a broken image, a blocked tracker) are
            // common and shouldn't take over the screen.
            if (error.isForMainFrame ?? true) {
              _failedThisLoad = true;
              callbacks.onError(error.description);
            }
          },
          // Server error pages for the page itself (origin restarting, proxy
          // 5xx, the web server's bare 404 for the home page) are replaced by
          // our own screen instead of showing the raw response.
          onHttpError: (error) {
            final uri = error.request?.uri;
            final status = error.response?.statusCode ?? 0;
            if (uri == null || uri.toString() != _currentUrl) return;
            final isHome = uri.path.isEmpty || uri.path == '/';
            if (status >= 500 || (status == 404 && isHome)) {
              _failedThisLoad = true;
              callbacks.onError('HTTP $status');
            }
          },
          onNavigationRequest: (request) => _handleNavigation(request),
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      // Chrome remote debugging — enabled only for non-production builds.
      // See docs/WEBVIEW_BRIDGE.md for the debug/staging vs release policy.
      AndroidWebViewController.enableDebugging(!AppConfig.environment.name.contains('production'));

      // Nearby matches: answer the site's navigator.geolocation prompt with
      // the Android runtime location permission. (WKWebView on iOS prompts
      // by itself using NSLocationWhenInUseUsageDescription.)
      androidController.setGeolocationEnabled(true);
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final status = await Permission.locationWhenInUse.request();
          return GeolocationPermissionsResponse(allow: status.isGranted, retain: status.isGranted);
        },
      );

      // <input type="file"> (signup photos, chat images, posts). Android's
      // WebView does nothing on a file input unless the app answers it, which
      // left people stuck on the photo step. iOS handles this natively.
      androidController.setOnShowFileSelector(_onShowFileSelector);
    }
  }

  final ImagePicker _picker = ImagePicker();

  static List<XFile> _one(XFile? f) => f == null ? const [] : [f];

  /// Returns file:// URIs for the picked files, or [] when cancelled (which
  /// resets the input so it can be tapped again).
  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    final accept = params.acceptTypes.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
    bool allows(String kind) => accept.isEmpty || accept.any((t) => t == '*/*' || t.startsWith('$kind/') || (kind == 'image' && const ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'].contains(t)));
    final wantsImages = allows('image');
    final wantsVideo = allows('video');
    final multiple = params.mode == FileSelectorMode.openMultiple;

    try {
      // Camera only makes sense for photos; video-only inputs go to the gallery.
      PhotoSource? source = PhotoSource.gallery;
      if (wantsImages) {
        source = params.isCaptureEnabled ? PhotoSource.camera : await _callbacks.onChoosePhotoSource();
        if (source == null) return const [];
      }

      List<XFile> files;
      if (source == PhotoSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) await openAppSettings();
          return const [];
        }
        final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048);
        files = shot == null ? [] : [shot];
      } else if (wantsImages && wantsVideo) {
        files = multiple ? await _picker.pickMultipleMedia() : _one(await _picker.pickMedia());
      } else if (wantsVideo) {
        files = _one(await _picker.pickVideo(source: ImageSource.gallery));
      } else {
        files = multiple
            ? await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2048)
            : _one(await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048));
      }
      return files.map((f) => Uri.file(f.path).toString()).toList();
    } catch (e) {
      debugPrint('[WebViewService] file selector failed: $e');
      return const [];
    }
  }

  /// Camera / microphone requests from the page (getUserMedia for voice and
  /// video calls, in-app photo capture). Granted to the WebView only after
  /// the user grants the matching OS permission, and only for our own site.
  Future<void> _onPermissionRequest(WebViewPermissionRequest request) async {
    final wantsCamera = request.types.contains(WebViewPermissionResourceType.camera);
    final wantsMic = request.types.contains(WebViewPermissionResourceType.microphone);
    if (!wantsCamera && !wantsMic) {
      await request.deny();
      return;
    }
    final permissions = <Permission>[
      if (wantsCamera) Permission.camera,
      if (wantsMic) Permission.microphone,
    ];
    try {
      final results = await permissions.request();
      final allGranted = results.values.every((s) => s.isGranted || s.isLimited);
      if (allGranted) {
        await request.grant();
      } else {
        await request.deny();
      }
    } catch (e) {
      debugPrint('[WebViewService] permission request failed: $e');
      await request.deny();
    }
  }

  FutureOr<NavigationDecision> _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    // Iframes the page creates for itself (Stripe, embeds) also come through
    // here. Routing them sent hidden third-party frames to the external
    // browser — the "Stripe page opened at random" bug. Only top-level
    // navigations are the user going somewhere.
    if (!request.isMainFrame) return NavigationDecision.navigate;

    final action = UrlRouter.classify(uri);

    switch (action) {
      case RouteAction.internal:
        return NavigationDecision.navigate;
      case RouteAction.purchase:
        // Fallback path for a plain <a href="/premium"> the site didn't
        // wire through the JS bridge — routed to PurchaseRouter by the
        // screen layer, which owns the purchase system dependency.
        _callbacks.onPurchaseRoute(uri.path);
        return NavigationDecision.prevent;
      case RouteAction.telephone:
      case RouteAction.email:
      case RouteAction.maps:
      case RouteAction.external:
        UrlRouter.openExternally(uri);
        return NavigationDecision.prevent;
    }
  }

  String _buildUserAgent() {
    final platform = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Desktop');
    // Preserve the platform's normal WebView UA and append our identifier
    // rather than replacing it, so nothing else on the site that sniffs the
    // UA for browser capability breaks.
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 '
          '${AppConfig.userAgentSuffix} ($platform)';
    }
    return 'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Version/4.0 Chrome/ Mobile Safari/537.36 ${AppConfig.userAgentSuffix} ($platform)';
  }

  Future<void> loadInitialUrl() => controller.loadRequest(Uri.parse(AppConfig.websiteUrl));

  Future<bool> handleBackPress() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return true; // handled — don't let the system also pop the app
    }
    return false; // not handled — caller decides exit behavior
  }

  Future<void> reload() => controller.reload();
}
