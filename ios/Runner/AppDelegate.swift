import UIKit
import Flutter
import FirebaseCore
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is initialized here AND in Dart (NotificationService); the
    // Dart-side call is idempotent if this one has already run. Wrapped
    // implicitly safe by FirebaseApp.configure() being a no-op if called
    // twice with the same options.
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)

    // Call audio routing (speaker / earpiece) for voice & video calls in the WebView.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "net.elitemeet.app/audio", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        let session = AVAudioSession.sharedInstance()
        let args = call.arguments as? [String: Any]
        do {
          switch call.method {
          case "startCallAudio":
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            try session.overrideOutputAudioPort((args?["speaker"] as? Bool ?? false) ? .speaker : .none)
            result(true)
          case "setSpeakerphone":
            try session.overrideOutputAudioPort((args?["on"] as? Bool ?? false) ? .speaker : .none)
            result(true)
          case "stopCallAudio":
            try session.overrideOutputAudioPort(.none)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            result(true)
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "audio_error", message: error.localizedDescription, details: nil))
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
