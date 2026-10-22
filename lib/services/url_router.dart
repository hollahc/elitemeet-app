import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// How a given URL/navigation request should be handled.
enum RouteAction {
  /// Keep it inside the WebView (normal elitemeet.net navigation).
  internal,

  /// Route through the purchase system instead of ordinary navigation.
  purchase,

  /// Open in the native phone dialer.
  telephone,

  /// Open in the native email client.
  email,

  /// Open in a maps app / browser maps view.
  maps,

  /// Open in the external browser or a relevant native app (social links,
  /// unrelated third-party sites).
  external,
}

/// Centralized decision point for every navigation the WebView reports.
///
/// Nothing else in the app should decide "internal vs external" on its own —
/// route everything through here so the policy lives in one place.
class UrlRouter {
  UrlRouter._();

  /// Web paths that should be handed to the purchase system instead of
  /// loaded as a normal page. Kept intentionally small and explicit rather
  /// than pattern-matched, per Section 15 — the purchase config
  /// (`purchase_config.dart`, added in a later step) owns the authoritative
  /// list; this is the first-pass filter.
  static const List<String> _purchasePathPrefixes = [
    '/premium',
    '/checkout',
    '/upgrade',
  ];

  static RouteAction classify(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'tel') return RouteAction.telephone;
    if (scheme == 'mailto') return RouteAction.email;

    if (scheme != 'http' && scheme != 'https') {
      // Unknown custom scheme (e.g. an app-only deep link some other app
      // registered). Treat as external rather than silently swallowing it.
      return RouteAction.external;
    }

    final host = uri.host.toLowerCase();

    if (_isMapsHost(host)) return RouteAction.maps;

    if (_isInternalHost(host)) {
      if (_purchasePathPrefixes.any((p) => uri.path.startsWith(p))) {
        return RouteAction.purchase;
      }
      return RouteAction.internal;
    }

    return RouteAction.external;
  }

  static bool _isInternalHost(String host) {
    final internal = AppConfig.internalHost.toLowerCase();
    return host == internal || host == 'www.$internal';
  }

  static bool _isMapsHost(String host) {
    const mapsHosts = {
      'maps.google.com',
      'www.google.com',
      'maps.apple.com',
    };
    // Only treat www.google.com as maps if the path is actually a maps path;
    // callers should check uri.path == '/maps' themselves if precision
    // matters beyond this first-pass classification.
    return mapsHosts.contains(host);
  }

  /// Opens a URL using the appropriate native handler for its [RouteAction].
  /// Returns false if the platform couldn't launch it.
  static Future<bool> openExternally(Uri uri) async {
    final launchMode = switch (classify(uri)) {
      RouteAction.telephone || RouteAction.email => LaunchMode.externalApplication,
      _ => LaunchMode.externalApplication,
    };
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: launchMode);
  }
}
