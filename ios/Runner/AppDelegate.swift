import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BackgroundService.registerTaskHandler()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let _ = BackgroundService(messenger: engineBridge.binaryMessenger)

    let channel = FlutterMethodChannel(
      name: "hdr2sdr/path",
      binaryMessenger: engineBridge.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getOutputDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let documents = NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true
      ).first
      result(documents)
    }
  }
}
