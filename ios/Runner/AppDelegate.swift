import AVFoundation
import CoreLocation
import Flutter
import ImageIO
import Photos
import UIKit

private func bestNativeCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
  let preferredDeviceTypes: [AVCaptureDevice.DeviceType] = position == .back
    ? [
      .builtInTripleCamera,
      .builtInDualWideCamera,
      .builtInDualCamera,
      .builtInWideAngleCamera,
    ]
    : [
      .builtInWideAngleCamera,
      .builtInTrueDepthCamera,
    ]
  return preferredDeviceTypes.lazy.compactMap {
    AVCaptureDevice.default($0, for: .video, position: position)
  }.first
}

private func nativeCameraDisplayZoomMultiplier(for device: AVCaptureDevice) -> CGFloat {
  if #available(iOS 18.0, *) {
    return max(device.displayVideoZoomFactorMultiplier, 0.01)
  }

  switch device.deviceType {
  case .builtInDualWideCamera, .builtInTripleCamera:
    guard
      let mainLensSwitchFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first
    else {
      return 1
    }
    return 1 / max(CGFloat(truncating: mainLensSwitchFactor), 1)
  default:
    return 1
  }
}

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
    if let appRegistrar = registrar(forPlugin: "AppDelegate") {
      registerNativeCameraPreview(
        registry: self,
        messenger: appRegistrar.messenger()
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterEventChannel(name: "miriago/map_heading", binaryMessenger: messenger)
      .setStreamHandler(MapHeadingStream())
    registerNativeCameraPreview(
      registry: engineBridge.pluginRegistry,
      messenger: messenger
    )

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
    let cameraCapabilitiesChannel = FlutterMethodChannel(
      name: "seichi/camera_capabilities",
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
    cameraCapabilitiesChannel.setMethodCallHandler { call, result in
      guard call.method == "getBackCameraZoomRange" else {
        result(FlutterMethodNotImplemented)
        return
      }

      self.getBackCameraZoomRange(result: result)
    }
  }

  private func registerNativeCameraPreview(
    registry: FlutterPluginRegistry,
    messenger: FlutterBinaryMessenger
  ) {
    let pluginKey = "NativeCameraPreviewPlugin"
    guard !registry.hasPlugin(pluginKey) else {
      return
    }
    guard
      let nativeCameraRegistrar = registry.registrar(
        forPlugin: pluginKey
      )
    else {
      return
    }

    nativeCameraRegistrar.register(
      NativeCameraPreviewFactory(messenger: messenger),
      withId: "seichi/native_camera_preview"
    )
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

  private func getBackCameraZoomRange(result: FlutterResult) {
    guard let device = bestNativeCameraDevice(position: .back) else {
      result(["minZoomRatio": 1.0, "maxZoomRatio": 20.0])
      return
    }

    let displayMultiplier = nativeCameraDisplayZoomMultiplier(for: device)
    result([
      "minZoomRatio": Double(device.minAvailableVideoZoomFactor * displayMultiplier),
      "maxZoomRatio": Double(
        min(device.maxAvailableVideoZoomFactor * displayMultiplier, 20)
      ),
    ])
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

private final class MapHeadingStream: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    manager.headingFilter = 1
    // True-north heading requires location on this same manager. Navigation
    // owns precise positioning; this coarse stream only supplies declination.
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.distanceFilter = 1000
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    guard CLLocationManager.headingAvailable() else {
      events(nil)
      return nil
    }
    manager.startUpdatingLocation()
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    guard heading.headingAccuracy >= 0, heading.headingAccuracy <= 45,
      heading.trueHeading >= 0 else { sink?(nil); return }
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?.interfaceOrientation
    let offset: Double
    switch orientation {
    case .landscapeRight: offset = 90
    case .landscapeLeft: offset = -90
    case .portraitUpsideDown: offset = 180
    default: offset = 0
    }
    sink?((heading.trueHeading + offset + 360).truncatingRemainder(dividingBy: 360))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    sink?(nil)
  }

  deinit {
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
  }
}

private final class NativeCameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeCameraPreviewView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

private final class NativeCameraPreviewView: NSObject, FlutterPlatformView {
  private let previewView: NativeCameraPreviewUIView
  private let channel: FlutterMethodChannel
  private let session = AVCaptureSession()
  private let photoOutput = AVCapturePhotoOutput()
  private let sessionQueue = DispatchQueue(label: "app.miriago.nativeCamera.session")

  private var currentInput: AVCaptureDeviceInput?
  private var lensFacing = "back"
  private var flashMode = AVCaptureDevice.FlashMode.auto
  private var torchEnabled = false
  private var targetAspectRatio = 1.0
  private var cropCaptureToAspectRatio = true
  private var captureDelegate: NativePhotoCaptureDelegate?

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    previewView = NativeCameraPreviewUIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "seichi/native_camera_preview_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    previewView.previewLayer.session = session
    previewView.previewLayer.videoGravity = .resizeAspectFill
    channel.setMethodCallHandler(handle)
  }

  func view() -> UIView {
    previewView
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      targetAspectRatio = sanitizedAspectRatio(
        doubleArgument(call, "targetAspectRatio") ?? targetAspectRatio
      )
      initialize(result: result)
    case "getZoomState":
      result(zoomStateMap())
    case "setZoomRatio":
      setZoomRatio(call: call, result: result)
    case "setTargetAspectRatio":
      targetAspectRatio = sanitizedAspectRatio(
        doubleArgument(call, "targetAspectRatio") ?? targetAspectRatio
      )
      result(nil)
    case "setCropCaptureToAspectRatio":
      cropCaptureToAspectRatio =
        boolArgument(call, "enabled") ?? cropCaptureToAspectRatio
      result(nil)
    case "setFlashMode":
      setFlashMode(call: call, result: result)
    case "switchCamera", "switchLens":
      switchCamera(result: result)
    case "takePicture":
      takePicture(call: call, result: result)
    case "writePhotoLocation":
      writePhotoLocation(call: call, result: result)
    case "dispose":
      dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initialize(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureSession(result: result)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        guard granted else {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "camera_permission_denied",
                message: "Camera permission is not granted.",
                details: nil
              )
            )
          }
          return
        }
        self?.configureSession(result: result)
      }
    default:
      result(
        FlutterError(
          code: "camera_permission_denied",
          message: "Camera permission is not granted.",
          details: nil
        )
      )
    }
  }

  private func configureSession(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      do {
        try self.configureSessionInput()
        if !self.session.outputs.contains(self.photoOutput) {
          guard self.session.canAddOutput(self.photoOutput) else {
            throw NativeCameraError.message("Cannot add photo output.")
          }
          self.session.addOutput(self.photoOutput)
        }
        self.updatePreviewOrientation()
        self.session.startRunning()

        DispatchQueue.main.async {
          result(self.zoomStateMap())
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "camera_initialize_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func configureSessionInput() throws {
    let position: AVCaptureDevice.Position = lensFacing == "front" ? .front : .back
    guard let device = bestDevice(position: position) else {
      throw NativeCameraError.message("Camera device is not available.")
    }
    let input = try AVCaptureDeviceInput(device: device)

    session.beginConfiguration()
    session.sessionPreset = .photo
    if let currentInput {
      session.removeInput(currentInput)
    }
    guard session.canAddInput(input) else {
      session.commitConfiguration()
      throw NativeCameraError.message("Cannot add camera input.")
    }
    session.addInput(input)
    currentInput = input
    session.commitConfiguration()
    applyTorchIfNeeded(device: device)
  }

  private func bestDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    bestNativeCameraDevice(position: position)
  }

  private func setZoomRatio(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let requestedDisplayZoom = CGFloat(doubleArgument(call, "zoomRatio") ?? 1.0)
    sessionQueue.async { [weak self] in
      guard let self, let device = self.currentInput?.device else {
        DispatchQueue.main.async { result(self?.zoomStateMap()) }
        return
      }

      do {
        try device.lockForConfiguration()
        let displayMultiplier = nativeCameraDisplayZoomMultiplier(for: device)
        let requestedNativeZoom = requestedDisplayZoom / displayMultiplier
        let minNativeZoom = device.minAvailableVideoZoomFactor
        let maxNativeZoom = min(
          device.maxAvailableVideoZoomFactor,
          20 / displayMultiplier
        )
        device.videoZoomFactor = min(
          max(requestedNativeZoom, minNativeZoom),
          maxNativeZoom
        )
        device.unlockForConfiguration()
        DispatchQueue.main.async { result(self.zoomStateMap()) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "camera_zoom_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func setFlashMode(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let mode = stringArgument(call, "flashMode") ?? "auto"
    switch mode {
    case "off":
      flashMode = .off
      torchEnabled = false
    case "on":
      flashMode = .on
      torchEnabled = false
    case "torch":
      flashMode = .off
      torchEnabled = true
    default:
      flashMode = .auto
      torchEnabled = false
    }

    sessionQueue.async { [weak self] in
      if let device = self?.currentInput?.device {
        self?.applyTorchIfNeeded(device: device)
      }
      DispatchQueue.main.async { result(self?.zoomStateMap()) }
    }
  }

  private func switchCamera(result: @escaping FlutterResult) {
    lensFacing = lensFacing == "back" ? "front" : "back"
    sessionQueue.async { [weak self] in
      guard let self else { return }
      do {
        try self.configureSessionInput()
        self.updatePreviewOrientation()
        DispatchQueue.main.async { result(self.zoomStateMap()) }
      } catch {
        self.lensFacing = "back"
        try? self.configureSessionInput()
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "camera_switch_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func takePicture(call: FlutterMethodCall, result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.updatePhotoOrientation()

      let settings = AVCapturePhotoSettings()
      if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
        settings.flashMode = self.flashMode
      }

      let delegate = NativePhotoCaptureDelegate(
        targetAspectRatio: self.targetAspectRatio,
        cropCaptureToAspectRatio: self.cropCaptureToAspectRatio,
        location: photoLocation(from: call)
      ) { [weak self] path, error in
        guard let self else { return }
        self.captureDelegate = nil
        DispatchQueue.main.async {
          if let path {
            result(path)
          } else {
            result(
              FlutterError(
                code: "capture_failed",
                message: error ?? "Failed to capture photo.",
                details: nil
              )
            )
          }
        }
      }
      self.captureDelegate = delegate
      self.photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
  }

  private func writePhotoLocation(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let location = photoLocation(from: call)
    else {
      result(
        FlutterError(
          code: "invalid_photo_location",
          message: "Photo path or location is invalid.",
          details: nil
        )
      )
      return
    }

    sessionQueue.async {
      do {
        try writePhotoLocationMetadata(at: URL(fileURLWithPath: path), location: location)
        DispatchQueue.main.async { result(true) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "photo_location_write_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func applyTorchIfNeeded(device: AVCaptureDevice) {
    guard device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      if torchEnabled {
        try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
      } else {
        device.torchMode = .off
      }
      device.unlockForConfiguration()
    } catch {
      device.unlockForConfiguration()
    }
  }

  private func updatePreviewOrientation() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let orientation = self.currentVideoOrientation()
      if self.previewView.previewLayer.connection?.isVideoOrientationSupported == true {
        self.previewView.previewLayer.connection?.videoOrientation = orientation
      }
    }
  }

  private func updatePhotoOrientation() {
    guard let connection = photoOutput.connection(with: .video) else { return }
    if connection.isVideoOrientationSupported {
      connection.videoOrientation = currentVideoOrientation()
    }
    if connection.isVideoMirroringSupported {
      connection.isVideoMirrored = lensFacing == "front"
    }
  }

  private func currentVideoOrientation() -> AVCaptureVideoOrientation {
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .interfaceOrientation

    switch orientation {
    case .landscapeLeft:
      return .landscapeLeft
    case .landscapeRight:
      return .landscapeRight
    case .portraitUpsideDown:
      return .portraitUpsideDown
    default:
      return .portrait
    }
  }

  private func zoomStateMap() -> [String: Any] {
    guard let device = currentInput?.device else {
      return [
        "minZoomRatio": 1.0,
        "maxZoomRatio": 1.0,
        "zoomRatio": 1.0,
        "lensFacing": lensFacing,
      ]
    }

    let displayMultiplier = nativeCameraDisplayZoomMultiplier(for: device)
    return [
      "minZoomRatio": Double(device.minAvailableVideoZoomFactor * displayMultiplier),
      "maxZoomRatio": Double(
        min(device.maxAvailableVideoZoomFactor * displayMultiplier, 20)
      ),
      "zoomRatio": Double(device.videoZoomFactor * displayMultiplier),
      "lensFacing": lensFacing,
    ]
  }

  private func sanitizedAspectRatio(_ value: Double) -> Double {
    min(max(value, 0.2), 5.0)
  }

  private func dispose() {
    channel.setMethodCallHandler(nil)
    sessionQueue.async { [weak self] in
      self?.session.stopRunning()
      self?.session.inputs.forEach { self?.session.removeInput($0) }
      self?.session.outputs.forEach { self?.session.removeOutput($0) }
    }
  }

  private func doubleArgument(_ call: FlutterMethodCall, _ key: String) -> Double? {
    guard let arguments = call.arguments as? [String: Any] else { return nil }
    if let value = arguments[key] as? Double {
      return value
    }
    if let value = arguments[key] as? NSNumber {
      return value.doubleValue
    }
    return nil
  }

  private func boolArgument(_ call: FlutterMethodCall, _ key: String) -> Bool? {
    guard let arguments = call.arguments as? [String: Any] else { return nil }
    if let value = arguments[key] as? Bool {
      return value
    }
    if let value = arguments[key] as? NSNumber {
      return value.boolValue
    }
    return nil
  }

  private func photoLocation(from call: FlutterMethodCall) -> PhotoGPSLocation? {
    guard
      let latitude = doubleArgument(call, "latitude"),
      let longitude = doubleArgument(call, "longitude"),
      latitude.isFinite,
      longitude.isFinite,
      (-90...90).contains(latitude),
      (-180...180).contains(longitude)
    else { return nil }

    let arguments = call.arguments as? [String: Any]
    let timestampMillis = (arguments?["locationTimestampMillis"] as? NSNumber)?.doubleValue
    return PhotoGPSLocation(
      latitude: latitude,
      longitude: longitude,
      altitude: doubleArgument(call, "altitude"),
      accuracy: doubleArgument(call, "accuracy"),
      timestamp: timestampMillis.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
    )
  }

  private func stringArgument(_ call: FlutterMethodCall, _ key: String) -> String? {
    guard let arguments = call.arguments as? [String: Any] else { return nil }
    return arguments[key] as? String
  }
}

private struct PhotoGPSLocation {
  let latitude: Double
  let longitude: Double
  let altitude: Double?
  let accuracy: Double?
  let timestamp: Date
}

private func jpegData(
  for image: UIImage,
  preserving sourceMetadata: [String: Any],
  location: PhotoGPSLocation?
) -> Data? {
  guard let cgImage = image.cgImage else { return nil }
  var metadata = sourceMetadata
  metadata[kCGImagePropertyOrientation as String] = 1
  metadata[kCGImagePropertyPixelWidth as String] = cgImage.width
  metadata[kCGImagePropertyPixelHeight as String] = cgImage.height

  var exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
  exif[kCGImagePropertyExifPixelXDimension as String] = cgImage.width
  exif[kCGImagePropertyExifPixelYDimension as String] = cgImage.height
  metadata[kCGImagePropertyExifDictionary as String] = exif

  var tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
  tiff[kCGImagePropertyTIFFSoftware as String] = "MiriaGo"
  metadata[kCGImagePropertyTIFFDictionary as String] = tiff
  if let location {
    metadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata(location)
  }
  metadata[kCGImageDestinationLossyCompressionQuality as String] = 0.95

  let output = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      output,
      "public.jpeg" as CFString,
      1,
      nil
    )
  else { return nil }
  CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
  guard CGImageDestinationFinalize(destination) else { return nil }
  return output as Data
}

private func gpsMetadata(_ location: PhotoGPSLocation) -> [String: Any] {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.dateFormat = "HH:mm:ss.SSSSSS"
  let dateFormatter = DateFormatter()
  dateFormatter.locale = Locale(identifier: "en_US_POSIX")
  dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
  dateFormatter.dateFormat = "yyyy:MM:dd"

  var gps: [String: Any] = [
    kCGImagePropertyGPSLatitude as String: abs(location.latitude),
    kCGImagePropertyGPSLatitudeRef as String: location.latitude < 0 ? "S" : "N",
    kCGImagePropertyGPSLongitude as String: abs(location.longitude),
    kCGImagePropertyGPSLongitudeRef as String: location.longitude < 0 ? "W" : "E",
    kCGImagePropertyGPSTimeStamp as String: formatter.string(from: location.timestamp),
    kCGImagePropertyGPSDateStamp as String: dateFormatter.string(from: location.timestamp),
  ]
  if let altitude = location.altitude, altitude.isFinite {
    gps[kCGImagePropertyGPSAltitude as String] = abs(altitude)
    gps[kCGImagePropertyGPSAltitudeRef as String] = altitude < 0 ? 1 : 0
  }
  if let accuracy = location.accuracy, accuracy.isFinite, accuracy >= 0 {
    gps[kCGImagePropertyGPSHPositioningError as String] = accuracy
  }
  return gps
}

private func writePhotoLocationMetadata(
  at file: URL,
  location: PhotoGPSLocation
) throws {
  guard
    let source = CGImageSourceCreateWithURL(file as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else {
    throw NativeCameraError.message("Photo data is invalid.")
  }
  let sourceMetadata =
    CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
  guard
    let data = jpegData(
      for: UIImage(cgImage: image),
      preserving: sourceMetadata,
      location: location
    )
  else {
    throw NativeCameraError.message("Failed to update photo metadata.")
  }
  try data.write(to: file, options: .atomic)
}

private final class NativeCameraPreviewUIView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }
}

private final class NativePhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let targetAspectRatio: Double
  private let cropCaptureToAspectRatio: Bool
  private let location: PhotoGPSLocation?
  private let completion: (String?, String?) -> Void

  init(
    targetAspectRatio: Double,
    cropCaptureToAspectRatio: Bool,
    location: PhotoGPSLocation?,
    completion: @escaping (String?, String?) -> Void
  ) {
    self.targetAspectRatio = targetAspectRatio
    self.cropCaptureToAspectRatio = cropCaptureToAspectRatio
    self.location = location
    self.completion = completion
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error {
      completion(nil, error.localizedDescription)
      return
    }

    guard
      let data = photo.fileDataRepresentation(),
      let image = UIImage(data: data)
    else {
      completion(nil, "Captured image data is invalid.")
      return
    }

    let normalized = image.normalizedOrientation()
    let outputImage =
      cropCaptureToAspectRatio
      ? normalized.cropped(toAspectRatio: targetAspectRatio)
      : normalized

    guard
      let jpegData = jpegData(
        for: outputImage,
        preserving: photo.metadata,
        location: location
      )
    else {
      completion(nil, "Failed to encode captured image.")
      return
    }

    do {
      let directory = try FileManager.default
        .url(
          for: .documentDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        .appendingPathComponent("visit_record_images", isDirectory: true)
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )

      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
      let file = directory.appendingPathComponent(
        "native_camera_\(formatter.string(from: Date())).jpg"
      )
      try jpegData.write(to: file, options: .atomic)
      completion(file.path, nil)
    } catch {
      completion(nil, error.localizedDescription)
    }
  }
}

private enum NativeCameraError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self {
    case .message(let message):
      return message
    }
  }
}

extension UIImage {
  fileprivate func normalizedOrientation() -> UIImage {
    if imageOrientation == .up {
      return self
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  fileprivate func cropped(toAspectRatio targetAspectRatio: Double) -> UIImage {
    guard targetAspectRatio > 0 else { return self }
    let currentRatio = size.width / size.height
    let targetRatio = CGFloat(targetAspectRatio)
    guard abs(currentRatio - targetRatio) >= 0.01 else { return self }

    let cropSize: CGSize
    if currentRatio > targetRatio {
      cropSize = CGSize(width: size.height * targetRatio, height: size.height)
    } else {
      cropSize = CGSize(width: size.width, height: size.width / targetRatio)
    }

    let cropRect = CGRect(
      x: (size.width - cropSize.width) / 2,
      y: (size.height - cropSize.height) / 2,
      width: cropSize.width,
      height: cropSize.height
    )

    guard let cgImage = cgImage?.cropping(to: cropRect.scaled(by: scale)) else {
      return self
    }
    return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
  }
}

extension CGRect {
  fileprivate func scaled(by scale: CGFloat) -> CGRect {
    CGRect(
      x: origin.x * scale,
      y: origin.y * scale,
      width: size.width * scale,
      height: size.height * scale
    )
  }
}
