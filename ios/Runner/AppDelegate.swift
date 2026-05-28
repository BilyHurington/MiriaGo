import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var planFileChannel: FlutterMethodChannel?
  private var pendingPlanPath: String?

  static weak var shared: AppDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppDelegate.shared = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    planFileChannel = FlutterMethodChannel(
      name: "seichi/plan_file",
      binaryMessenger: messenger
    )
    planFileChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitialPath" else {
        result(FlutterMethodNotImplemented)
        return
      }

      result(self?.pendingPlanPath)
      self?.pendingPlanPath = nil
    }

    let galleryChannel = FlutterMethodChannel(
      name: "seichi/gallery_saver",
      binaryMessenger: messenger
    )
    galleryChannel.setMethodCallHandler { call, result in
      guard call.method == "saveToGallery" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let filePath = arguments["filePath"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "filePath is required",
            details: nil
          )
        )
        return
      }

      self.saveImageToGallery(filePath: filePath, result: result)
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return handleIncomingPlanFile(url: url)
  }

  @discardableResult
  func handleIncomingPlanFile(url: URL) -> Bool {
    guard let copiedPath = copyPlanFileToInbox(url: url) else {
      return false
    }

    pendingPlanPath = copiedPath
    planFileChannel?.invokeMethod("openPath", arguments: copiedPath)
    return true
  }

  private func saveImageToGallery(filePath: String, result: @escaping FlutterResult) {
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(
        FlutterError(
          code: "FILE_NOT_FOUND",
          message: "Image file does not exist.",
          details: nil
        )
      )
      return
    }

    requestPhotoAddPermission { granted in
      guard granted else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "PHOTO_PERMISSION_DENIED",
              message: "Photo library add permission is not granted.",
              details: nil
            )
          )
        }
        return
      }

      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAssetFromImage(
          atFileURL: URL(fileURLWithPath: filePath)
        )
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            result(filePath)
          } else {
            result(
              FlutterError(
                code: "SAVE_FAILED",
                message: error?.localizedDescription ?? "Failed to save image.",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private func requestPhotoAddPermission(completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        completion(status == .authorized || status == .limited)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        completion(status == .authorized)
      }
    }
  }

  private func copyPlanFileToInbox(url: URL) -> String? {
    let shouldStopAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if shouldStopAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("incoming_plans", isDirectory: true)
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let destination = directory.appendingPathComponent(
        "incoming_\(Int(Date().timeIntervalSince1970 * 1000)).sjhplan"
      )
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: url, to: destination)
      return destination.path
    } catch {
      return nil
    }
  }
}
