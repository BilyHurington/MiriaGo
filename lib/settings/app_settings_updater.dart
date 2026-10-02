import 'package:flutter/foundation.dart';

import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';

/// Lets pages opened outside the app shell (record details, pushed from
/// several places) change a setting through the shell, so its copy of the
/// settings stays current and a later save never rolls the change back.
abstract final class AppSettingsUpdater {
  /// Set by AppShell. Applies [update] to the current settings and stores
  /// them; resolves to false when saving failed (the shell has already told
  /// the user and restored the stored settings).
  static Future<bool> Function(
    AppSettings Function(AppSettings current) update,
  )?
  handler;

  /// Set by AppShell: the settings the app is using now. Pages opened with a
  /// settings snapshot read changes made since through this.
  static AppSettings? Function()? currentSettings;

  /// [snapshot] unless the shell has newer settings.
  static AppSettings latest(AppSettings snapshot) =>
      currentSettings?.call() ?? snapshot;

  /// Changes one part of the settings: through the shell when it is running,
  /// otherwise on top of the settings stored in [repository] (or
  /// [fallbackBase] when they cannot be read). Resolves to whether the
  /// change was stored; it never throws.
  static Future<bool> update(
    PilgrimageRepository? repository,
    AppSettings Function(AppSettings current) update, {
    AppSettings? fallbackBase,
  }) async {
    final shell = handler;
    if (shell != null) {
      return shell(update);
    }
    if (repository == null) {
      return false;
    }
    try {
      AppSettings base;
      try {
        base = await repository.loadAppSettings();
      } on Object {
        if (fallbackBase == null) rethrow;
        base = fallbackBase;
      }
      await repository.saveAppSettings(update(base));
      return true;
    } on Object catch (error) {
      debugPrint('Failed to save settings: $error');
      return false;
    }
  }
}
