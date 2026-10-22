import UIKit
import Flutter
import AVFoundation
import CallKit
import PushKit
import flutter_callkit_incoming

// UIScene lifecycle (required by upcoming iOS SDKs): the window lives in
// FlutterSceneDelegate (Info.plist → UIApplicationSceneManifest), and plugins
// and our own channels are registered once the implicit engine exists.
//
// Firebase is initialized from Dart (NotificationService) with the options in
// lib/firebase_options.dart. Don't call FirebaseApp.configure() here: there is
// no GoogleService-Info.plist in the bundle, so it would crash on launch.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Incoming calls ring full-screen through CallKit (iOS side of Android's
    // flutter_callkit_incoming screen). The server sends an Apple VoIP push;
    // see EliteMeet Web src/lib/apns.server.ts.
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Call audio routing (speaker / earpiece) for voice & video calls in the WebView.
    // Same channel and methods as MainActivity.kt on Android.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EliteMeetCallAudio") else { return }
    let channel = FlutterMethodChannel(name: "net.elitemeet.app/audio", binaryMessenger: registrar.messenger())
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

  // MARK: - PushKit (VoIP pushes)

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    // Stored by the plugin and emitted to Dart, which hands it to the website.
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  // iOS terminates the app (and eventually stops VoIP delivery) unless every
  // VoIP push reports a call to CallKit, so this always reports one — even
  // for a stale push, which is then ended straight away.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else { completion(); return }
    var p: [String: Any] = [:]
    for (k, v) in payload.dictionaryPayload {
      if let key = k as? String { p[key] = v }
    }

    let callId = (p["call_id"] as? String) ?? UUID().uuidString
    let video = (p["mode"] as? String) == "video"
    let data = flutter_callkit_incoming.Data(
      id: callId,
      nameCaller: (p["caller_name"] as? String) ?? "EliteMeet",
      handle: video ? "EliteMeet video call" : "EliteMeet voice call",
      type: video ? 1 : 0
    )
    data.appName = "EliteMeet"
    data.avatar = (p["caller_photo"] as? String) ?? ""
    data.duration = 45000
    data.extra = p as NSDictionary
    data.iconName = "CallKitLogo"
    data.handleType = "generic"
    data.supportsVideo = true
    data.maximumCallGroups = 1
    data.maximumCallsPerCallGroup = 1
    data.supportsDTMF = false
    data.supportsHolding = false
    data.supportsGrouping = false
    data.supportsUngrouping = false
    data.includesCallsInRecents = false
    data.missedNotificationSubtitle = "Missed call"
    data.isShowCallback = false

    let sentAt = Double((p["sent_at"] as? String) ?? "") ?? 0
    let stale = sentAt > 0 && Date().timeIntervalSince1970 * 1000 - sentAt > 45000
    // App open: the website's own ringing screen handles it (as on Android),
    // so the CallKit call that iOS insists on is ended straight away.
    let inForeground = UIApplication.shared.applicationState == .active
    let endImmediately = stale || inForeground
    if endImmediately {
      // Ending it below runs the decline path — this isn't a user decline,
      // so the server must not be told (checked in onDecline / Dart).
      p["auto_ended"] = "1"
      data.extra = p as NSDictionary
    }

    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // Plugin not registered yet (should not happen: the engine starts in
      // didFinishLaunching). Report a minimal call so iOS doesn't kill us.
      reportAndEnd(callId: callId, completion: completion)
      return
    }
    plugin.showCallkitIncoming(data, fromPushKit: true) {
      if endImmediately { plugin.endCall(data) }
      completion()
    }
  }

  private var fallbackProvider: CXProvider?

  private func reportAndEnd(callId: String, completion: @escaping () -> Void) {
    let provider = fallbackProvider ?? CXProvider(configuration: CXProviderConfiguration())
    fallbackProvider = provider
    let uuid = UUID(uuidString: callId) ?? UUID()
    provider.reportNewIncomingCall(with: uuid, update: CXCallUpdate()) { _ in
      provider.reportCall(with: uuid, endedAt: nil, reason: .failed)
      completion()
    }
  }

  // MARK: - CallkitIncomingAppDelegate

  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    // Dart (CallkitService) opens the call screen in the WebView.
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    // Tell the server here, natively: the app may have been launched in the
    // background just for this push and Flutter may not be listening yet.
    Self.postDecline(call.data.extra)
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {}

  func didActivateAudioSession(_ audioSession: AVAudioSession) {}

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {}

  func providerDidReset() {}

  /// Same signed request as CallkitService.declineRemote on Android.
  private static func postDecline(_ extra: NSDictionary) {
    if extra["auto_ended"] as? String == "1" { return }
    guard let urlString = extra["action_url"] as? String,
          let url = URL(string: urlString),
          let callId = extra["call_id"] as? String,
          let sig = extra["sig"] as? String else { return }
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["call_id": callId, "action": "decline", "sig": sig])
    let task = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
    URLSession.shared.dataTask(with: request) { _, _, _ in
      UIApplication.shared.endBackgroundTask(task)
    }.resume()
  }
}
