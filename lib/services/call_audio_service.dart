import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native call-audio routing for voice/video calls running in the WebView.
///
/// A WebView can't choose between the earpiece and the loudspeaker, so the
/// call screen asks the app to do it via `window.EliteMeetApp.setSpeakerphone`.
/// Implemented in MainActivity.kt (Android) and AppDelegate.swift (iOS).
class CallAudioService {
  CallAudioService._();
  static final CallAudioService instance = CallAudioService._();

  static const _channel = MethodChannel('net.elitemeet.app/audio');

  /// True while the web call screen has a call connected. The app must not
  /// reload, navigate or cover the WebView then — that hides or drops the call.
  final ValueNotifier<bool> inCall = ValueNotifier<bool>(false);

  Future<bool> start({bool speaker = false}) {
    inCall.value = true;
    return _invoke('startCallAudio', {'speaker': speaker});
  }

  Future<bool> setSpeakerphone(bool on) => _invoke('setSpeakerphone', {'on': on});

  Future<bool> stop() {
    inCall.value = false;
    return _invoke('stopCallAudio', const {});
  }

  Future<bool> _invoke(String method, Map<String, Object?> args) async {
    try {
      return (await _channel.invokeMethod<bool>(method, args)) ?? false;
    } catch (e) {
      debugPrint('[CallAudioService] $method failed: $e');
      return false;
    }
  }
}
