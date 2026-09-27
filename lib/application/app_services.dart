import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local/sqlite_pilgrimage_repository.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart';
import '../data/sample_pilgrimage_repository.dart';
import '../desktop/desktop_pilgrimage_repository.dart';
import '../desktop/tauri_bridge.dart';
import '../records/comparison_export_temp_stub.dart'
    if (dart.library.io) '../records/comparison_export_temp_io.dart';
import 'platform_capabilities.dart';

/// Long-lived app services, created once at startup.
class AppServices {
  AppServices({
    required this.repository,
    required this.capabilities,
    this.launcherInfo,
  });

  final PilgrimageRepository repository;
  final PlatformCapabilities capabilities;

  /// Tauri launcher info (desktop only).
  final DesktopLauncherInfo? launcherInfo;
}

typedef RepositoryLoader = Future<PilgrimageRepository> Function();

/// Startup orchestration ported from the old `main.dart` / `AppShell`.
abstract final class StartupService {
  /// Mobile → SQLite; Tauri → desktop repository; plain web → sample data.
  static Future<PilgrimageRepository> createDefaultRepository() async {
    if (!kIsWeb) return SqlitePilgrimageRepository();
    if (isTauriLauncherAvailable) return DesktopPilgrimageRepository.create();
    return SamplePilgrimageRepository();
  }

  static Future<DesktopLauncherInfo?> loadLauncherInfo() async {
    if (!isTauriLauncherAvailable) return null;
    try {
      return await loadDesktopLauncherInfo();
    } catch (_) {
      return null;
    }
  }

  /// Fire-and-forget housekeeping done once per launch.
  static void runStartupSideEffects(PilgrimageRepository repository) {
    unawaited(prepareReferenceCacheStorage());
    unawaited(sweepStaleComparisonExports(repository: repository));
  }

  /// Appends to the Tauri startup log (no-op elsewhere).
  static Future<void> writeDesktopError(
    String label,
    Object error,
    StackTrace? stackTrace,
  ) async {
    if (!isTauriLauncherAvailable) return;
    try {
      await appendDesktopStartupLog(
        message: '$label: $error${stackTrace == null ? '' : '\n$stackTrace'}',
      );
    } catch (_) {}
  }
}
