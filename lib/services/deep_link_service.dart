import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Handles incoming deep links from Android App Links / iOS Universal
/// Links — i.e. the user tapping an `https://elitemeet.net/...` link
/// somewhere outside the app (another app, a text message, search results)
/// while the app is installed.
///
/// This is distinct from [NotificationService.pendingDeepLink], which
/// handles navigation targets that arrive inside an FCM payload. Both
/// funnel into the same WebView-navigation mechanism at the screen layer,
/// but the trigger and transport are different, so they're kept separate
/// services rather than merged.
///
/// Native config required for this to actually fire (documented in
/// docs/DEEP_LINKS.md, not implemented by Dart code alone):
///   Android: intent-filter + `assetlinks.json` hosted at
///            https://elitemeet.net/.well-known/assetlinks.json
///   iOS:     Associated Domains capability + `apple-app-site-association`
///            hosted at https://elitemeet.net/.well-known/apple-app-site-association
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Set by the screen layer; navigates the WebView when a deep link
  /// resolves to an internal EliteMeet URL. Kept as a plain callback (not a
  /// ValueNotifier like NotificationService's pendingDeepLink) since deep
  /// links should be handled immediately as they arrive rather than parked
  /// for the screen to poll.
  void Function(Uri uri)? onInternalLink;

  Future<void> initialize() async {
    // App launched directly from a deep link (cold start).
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handle(initialUri);
    } catch (e) {
      debugPrint('[DeepLinkService] getInitialLink failed: $e');
    }

    // App already running (foreground/background) and a deep link arrives.
    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (error) => debugPrint('[DeepLinkService] uriLinkStream error: $error'),
    );
  }

  /// `elitemeet://app-signin?th=…` — the custom scheme the browser uses to
  /// hand a Google / Apple sign-in back to the app (iOS won't open a
  /// Universal Link from a page on the same domain) — becomes the same page
  /// on the site. Any other link is returned unchanged.
  static Uri normalize(Uri uri) {
    if (uri.scheme.toLowerCase() != AppConfig.appScheme) return uri;
    final path = uri.host.isEmpty ? uri.path : '/${uri.host}${uri.path}';
    return Uri(scheme: 'https', host: AppConfig.internalHost, path: path, query: uri.hasQuery ? uri.query : null);
  }

  void _handle(Uri uri) {
    uri = normalize(uri);
    if (!isInternalUri(uri)) {
      // A link scoped to this app's App Links/Universal Links config should
      // always be an elitemeet.net URL; if it isn't, don't silently eat it
      // — log so a misconfiguration is visible during testing.
      debugPrint('[DeepLinkService] Ignoring non-EliteMeet deep link: $uri');
      return;
    }
    onInternalLink?.call(uri);
  }

  /// Whether [uri] belongs to the configured EliteMeet domain. Public and
  /// static so it's directly unit-testable without needing the platform
  /// channels `AppLinks()` depends on — see test/deep_link_service_test.dart.
  static bool isInternalUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final internal = AppConfig.internalHost.toLowerCase();
    return host == internal || host == 'www.$internal';
  }

  void dispose() {
    _subscription?.cancel();
  }
}
