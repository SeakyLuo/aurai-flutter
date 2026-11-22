import Flutter
import UIKit
import MobileCoreServices

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.haiskynology.aurai/platform",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "copyChatAttachment" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as! [String: Any]
      let mimeType = arguments["mimeType"] as! String
      let path = arguments["path"] as? String
      let bytes = arguments["bytes"] as? FlutterStandardTypedData
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let data = try path.map { try Data(contentsOf: URL(fileURLWithPath: $0)) } ?? bytes!.data
          let type = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassMIMEType, mimeType as CFString, kUTTypeData
          )?.takeRetainedValue() ?? kUTTypeData
          DispatchQueue.main.async {
            UIPasteboard.general.setItems([[type as String: data]], options: [.localOnly: true])
            result(nil)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "copy_attachment", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }
}
