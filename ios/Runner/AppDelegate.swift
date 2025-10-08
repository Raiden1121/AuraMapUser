import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.auramap.audio/headphone_detection",
                                   binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "isHeadsetConnected":
        let audioSession = AVAudioSession.sharedInstance()
        do {
          try audioSession.setCategory(.playback, mode: .default)
          try audioSession.setActive(true)
          let outputs = audioSession.currentRoute.outputs
          let hasHeadphones = outputs.contains { output in
            return [
              AVAudioSession.Port.headphones,
              AVAudioSession.Port.bluetoothA2DP,
              AVAudioSession.Port.bluetoothLE,
              AVAudioSession.Port.bluetoothHFP
            ].contains(output.portType)
          }
          result(hasHeadphones)
        } catch {
          result(FlutterError(code: "AUDIO_ERROR",
                             message: error.localizedDescription,
                             details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
