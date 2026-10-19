import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Enable background audio session
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("AVAudioSession error: \(error)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry
    guard let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController else {
      return
    }

    let engineChannel = FlutterMethodChannel(name: "com.streammagnet/torrent_engine", binaryMessenger: controller.binaryMessenger)
    engineChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "init":
        result(true)
      case "pause":
        result(true)
      case "resume":
        result(true)
      case "stop":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(name: "com.streammagnet/torrent_events", binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(TorrentStreamHandler())
  }
}

class TorrentStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
