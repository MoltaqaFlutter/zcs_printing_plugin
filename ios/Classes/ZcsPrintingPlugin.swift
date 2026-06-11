import Flutter
import UIKit

public class ZcsPrintingPlugin: NSObject, FlutterPlugin {
  /// Current print interaction controller, if the system print sheet is visible (used for cancel).
  private weak var currentPrintController: UIPrintInteractionController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.example.zcs_printing/printer", binaryMessenger: registrar.messenger())
    let instance = ZcsPrintingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "printPdf":
      handlePrintPdf(call: call, result: result)
    case "printWithSystem":
      handlePrintWithSystem(call: call, result: result)
    case "cancelPrint":
      handleCancelPrint(result: result)
    default:
      // All other methods: iOS (ZCS hardware) is not supported
      result(FlutterError(
        code: "platformUnsupported",
        message: "This feature is not supported on iOS. Use Print with System for system print.",
        details: nil
      ))
    }
  }

  private func handlePrintPdf(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let pdfData = (args["pdfBytes"] as? FlutterStandardTypedData)?.data else {
      result(FlutterError(code: "invalidPdf", message: "pdfBytes is required", details: nil))
      return
    }

    DispatchQueue.main.async { [weak self] in
      self?.presentPdfPrintSheet(pdfData: pdfData, result: result)
    }
  }

  private func presentPdfPrintSheet(pdfData: Data, result: @escaping FlutterResult) {
    guard let rootVC = rootViewController() else {
      result(FlutterError(code: "printerNotAvailable", message: "No view controller to present print sheet", details: nil))
      return
    }

    let printInfo = UIPrintInfo(dictionary: nil)
    printInfo.jobName = "Print PDF"
    printInfo.outputType = .general

    let printController = UIPrintInteractionController.shared
    printController.printInfo = printInfo
    printController.printingItem = pdfData
    printController.showsNumberOfCopies = true

    currentPrintController = printController

    printController.present(
      animated: true,
      completionHandler: { [weak self] _, completed, error in
        self?.currentPrintController = nil
        if let error = error {
          result(FlutterError(code: "unknown", message: error.localizedDescription, details: nil))
        } else {
          result(completed)
        }
      }
    )
  }

  private func handlePrintWithSystem(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let imageData = args["imageBytes"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "invalidImage", message: "imageBytes is required", details: nil))
      return
    }
    let copies = (args["copies"] as? Int) ?? 1

    guard let image = UIImage(data: imageData.data) else {
      result(FlutterError(code: "invalidImage", message: "Failed to decode image", details: nil))
      return
    }

    DispatchQueue.main.async { [weak self] in
      self?.presentPrintSheet(image: image, copies: copies, result: result)
    }
  }

  private func presentPrintSheet(image: UIImage, copies: Int, result: @escaping FlutterResult) {
    guard let rootVC = rootViewController() else {
      result(FlutterError(code: "printerNotAvailable", message: "No view controller to present print sheet", details: nil))
      return
    }

    let printInfo = UIPrintInfo(dictionary: nil)
    printInfo.jobName = "Print"
    printInfo.outputType = .photo

    let printController = UIPrintInteractionController.shared
    printController.printInfo = printInfo
    printController.printingItem = image
    printController.showsNumberOfCopies = true
    // Note: Number of copies is set by the user in the system print sheet; UIPrintInfo has no copies API.

    currentPrintController = printController

    printController.present(
      animated: true,
      completionHandler: { [weak self] _, completed, error in
        self?.currentPrintController = nil
        if let error = error {
          result(FlutterError(code: "unknown", message: error.localizedDescription, details: nil))
        } else {
          result(completed)
        }
      }
    )
  }

  private func handleCancelPrint(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let controller = self.currentPrintController else {
        result(false)
        return
      }
      // UIPrintInteractionController.dismiss(animated:) has no completion parameter
      controller.dismiss(animated: true)
      self.currentPrintController = nil
      result(true)
    }
  }

  private func rootViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
      return nil
    }
    guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
      return nil
    }
    var vc = window.rootViewController
    while let presented = vc?.presentedViewController {
      vc = presented
    }
    return vc
  }
}
