import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'screens/webview_screen.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/callkit_service.dart';
import 'services/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // System bars match the site's navy so the bottom nav looks continuous.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF091123),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF091123),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Color(0xFF091123),
  ));

  // Portrait lock (Section 5). Kept here, in one place, so it's easy to
  // relax later (e.g. only for a specific screen) without hunting through
  // the app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Safe no-op until google-services.json / GoogleService-Info.plist exist
  // and `flutterfire configure` has been run — see lib/firebase_options.dart.
  await NotificationService.instance.initialize();

  await ConnectivityService.instance.initialize();

  await PurchaseService.instance.initialize();

  // Native incoming-call screen (Android) — after NotificationService so an
  // Accept tapped while the app was closed can deep-link into the call.
  await CallkitService.instance.initialize();

  runApp(const EliteMeetApp());
}

class EliteMeetApp extends StatelessWidget {
  const EliteMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8860B),
          brightness: Brightness.dark,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}
