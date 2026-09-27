import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import 'comparison_export_config.dart';
import 'comparison_export_config_storage_stub.dart'
    if (dart.library.io) 'comparison_export_config_storage_io.dart';

Future<AppSettings> migrateComparisonExportConfigSettings({
  required PilgrimageRepository repository,
  required AppSettings settings,
  Future<ComparisonExportConfig?> Function() loadLegacyConfig =
      loadComparisonExportConfig,
  Future<void> Function() clearLegacyConfig = clearComparisonExportConfig,
}) async {
  if (settings.comparisonExportConfigMigrated) {
    final config = ComparisonExportConfig.fromSettings(settings);
    ComparisonExportConfig.lastUsed = config;
    return settings;
  }

  try {
    final legacyConfig = await loadLegacyConfig();
    final config =
        legacyConfig ?? ComparisonExportConfig.fromSettings(settings);
    final migrated = config.applyToSettings(settings);
    await repository.saveAppSettings(migrated);
    await clearLegacyConfig();
    ComparisonExportConfig.lastUsed = config;
    return migrated;
  } catch (_) {
    return settings;
  }
}
