/// What a press of the Android back button should do.
enum BackAction { goBack, showExitHint, exit }

/// Back press rules:
///   - one press at any normal pace goes back a page;
///   - two presses in a fast double-tap ([doubleTap]) show "Press back again
///     to exit" instead of going back;
///   - one more press while that message is up ([exitWindow]) closes the app.
/// With no page to go back to, [noPageToGoBack] arms the exit straight away.
///
/// Kept free of Flutter and the WebView so the timing can be unit tested —
/// see test/back_press_policy_test.dart.
class BackPressPolicy {
  static const doubleTap = Duration(milliseconds: 500);
  static const exitWindow = Duration(seconds: 2);

  DateTime? _lastPressAt;
  DateTime? _exitArmedUntil;

  BackAction onPress(DateTime now) {
    final armedUntil = _exitArmedUntil;
    if (armedUntil != null && !now.isAfter(armedUntil)) return BackAction.exit;
    _exitArmedUntil = null;

    final last = _lastPressAt;
    _lastPressAt = now;
    if (last != null && now.difference(last) <= doubleTap) {
      _exitArmedUntil = now.add(exitWindow);
      return BackAction.showExitHint;
    }
    return BackAction.goBack;
  }

  /// The WebView had no history for a [BackAction.goBack]: show the exit hint
  /// and let the next press close the app.
  void noPageToGoBack(DateTime now) {
    _exitArmedUntil = now.add(exitWindow);
  }
}
