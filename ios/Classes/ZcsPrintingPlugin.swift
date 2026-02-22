import Flutter
import UIKit

public class ZcsPrintingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.example.zcs_printing/printer", binaryMessenger: registrar.messenger())
    let instance = ZcsPrintingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // iOS is not supported - return platform unsupported error
    result(FlutterError(
      code: "platformUnsupported",
      message: "Printer is not supported on this device. This feature is available only on Android.",
      details: nil
    ))
  }
}
