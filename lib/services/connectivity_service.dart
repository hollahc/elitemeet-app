import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks device connectivity so the app can show the offline screen
/// proactively (e.g. on resume with no connection) rather than only
/// reacting after a WebView load has already failed.
///
/// Note: connectivity_plus reports *network* reachability (Wi-Fi/cellular
/// attached), not guaranteed internet access — a WebView load failure is
/// still the authoritative signal for "the site didn't load." This service
/// complements that, it doesn't replace it.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> initialize() async {
    final initial = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(initial);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
