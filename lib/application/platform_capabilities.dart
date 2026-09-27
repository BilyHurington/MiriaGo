import 'package:flutter/foundation.dart';

import '../desktop/tauri_bridge.dart';

/// How a plan package/CSV export is handed to the user.
enum ExportDelivery { share, saveDialog, browserDownload }

/// How a plan package is imported.
enum PlanImportMode { filePicker, openInFromOtherApp }

/// Everything the UI needs to know about the current platform, so pages
/// ask "can we?" instead of checking platforms themselves.
///
/// Mirrors the platform branch table of the old app (see
/// docs/FEATURE_CHECKLIST.md §J).
@immutable
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isWeb,
    required this.isTauri,
    required this.isAndroid,
    required this.isIOS,
    required this.isDesktopNative,
  });

  factory PlatformCapabilities.current() {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return PlatformCapabilities(
      isWeb: kIsWeb,
      isTauri: kIsWeb && isTauriLauncherAvailable,
      isAndroid: android,
      isIOS: ios,
      isDesktopNative: !kIsWeb && !android && !ios,
    );
  }

  final bool isWeb;
  final bool isTauri;
  final bool isAndroid;
  final bool isIOS;
  final bool isDesktopNative;

  bool get isMobile => isAndroid || isIOS;

  /// Plain browser preview (not inside the Tauri launcher).
  bool get isPlainWeb => isWeb && !isTauri;

  /// Live camera preview (native CameraX / AVFoundation or CameraAwesome).
  bool get hasLiveCamera => isMobile || isDesktopNative;

  /// Photos and comparisons can be saved to the system gallery.
  bool get canSaveToGallery => isMobile;

  /// Plan package import can restore bundled resources locally.
  bool get canRestoreImportAssets => !isPlainWeb;

  /// Reference cache cleanup page is available.
  bool get canCleanReferenceCache => !isPlainWeb;

  /// "桌面端" settings page is shown (web builds, including Tauri).
  bool get showsDesktopSettings => isWeb;

  /// Photo location settings are shown (mobile or debug builds).
  bool get showsPhotoLocationSettings => isMobile || kDebugMode;

  PlanImportMode get planImportMode =>
      isIOS ? PlanImportMode.openInFromOtherApp : PlanImportMode.filePicker;

  ExportDelivery get exportDelivery {
    if (isMobile) return ExportDelivery.share;
    if (isPlainWeb) return ExportDelivery.browserDownload;
    return ExportDelivery.saveDialog;
  }
}
