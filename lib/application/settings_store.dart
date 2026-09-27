import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app_theme.dart' show applyAppColorsFromSettings;
import '../data/anitabi_service_config.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../records/comparison_export_config_migration.dart';

/// Owns the current [AppSettings].
///
/// Every change is applied immediately (no separate "apply" step) and
/// persisted through the repository in order. Side effects that the old
/// `AppShell._saveSettings` performed are reproduced here:
/// `AnitabiServiceConfig.current` and the legacy `AppColors` globals that
/// backend map helpers still read.
class SettingsStore extends ChangeNotifier {
  SettingsStore({required this.repository});

  final PilgrimageRepository repository;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  Future<void> _saveChain = Future.value();

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  /// Loads settings and runs the comparison-export config migration.
  Future<void> load() async {
    final loaded = await repository.loadAppSettings();
    final migrated = await migrateComparisonExportConfigSettings(
      repository: repository,
      settings: loaded,
    );
    _settings = migrated;
    _loaded = true;
    _applySideEffects();
    notifyListeners();
  }

  /// Re-reads settings written elsewhere (e.g. export config writes that go
  /// straight to the repository) without saving.
  Future<void> reloadFromRepository() async {
    _settings = await repository.loadAppSettings();
    _applySideEffects();
    notifyListeners();
  }

  /// Applies and persists [next]. Saves are serialised.
  Future<void> update(AppSettings next) {
    _settings = next;
    _applySideEffects();
    notifyListeners();
    final save = _saveChain.then((_) => repository.saveAppSettings(next));
    _saveChain = save.catchError((Object error) {
      debugPrint('Failed to save settings: $error');
    });
    return save;
  }

  Future<void> patch(AppSettings Function(AppSettings current) change) =>
      update(change(_settings));

  /// Re-applies globals after a platform brightness change.
  void platformBrightnessChanged() {
    _applySideEffects();
    notifyListeners();
  }

  Brightness resolvedBrightness(Brightness platformBrightness) {
    return switch (_settings.themeMode) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system => platformBrightness,
    };
  }

  void _applySideEffects() {
    AnitabiServiceConfig.current = _settings.anitabiServiceConfig;
    applyAppColorsFromSettings(
      _settings,
      platformBrightness:
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }
}
