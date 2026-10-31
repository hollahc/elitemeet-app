import 'environment.dart';

/// Single source of truth for EliteMeet app identity.
///
/// Change the domain here (or override at build time via
/// `--dart-define=ELITEMEET_BASE_URL=...`) — nothing else in the codebase
/// should hard-code elitemeet.net directly.
class AppConfig {
  AppConfig._();

  static const String appName = 'EliteMeet';
  static const String appVersion = '1.0.0';

  /// The default/canonical production domain. Prefer [websiteUrl] below,
  /// which is environment-aware.
  static const String eliteMeetBaseUrl = 'https://elitemeet.net';

  /// The URL the WebView actually loads, resolved from the selected
  /// environment (dev/staging/production).
  static String get websiteUrl => Environment.baseUrl;

  static AppEnvironment get environment => Environment.current;

  /// Host used to decide which navigations stay inside the WebView vs.
  /// route externally. Derived from [websiteUrl] so it tracks environment
  /// changes automatically.
  static String get internalHost => Uri.parse(websiteUrl).host;

  /// Android application ID / iOS bundle ID (confirmed final — see
  /// android/app/build.gradle and ios/Runner.xcodeproj).
  static const String applicationId = 'net.elitemeet.app';

  /// Custom URL scheme (`elitemeet://…`) the website uses to hand a browser
  /// sign-in back to the app. Registered in Info.plist and AndroidManifest.
  static const String appScheme = 'elitemeet';

  /// Identifier appended to the WebView user agent so the website can
  /// detect the native app. See docs/WEBVIEW_BRIDGE.md.
  static const String userAgentSuffix = 'EliteMeetApp/1.0';
}
