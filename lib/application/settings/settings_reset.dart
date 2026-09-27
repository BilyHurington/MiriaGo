import '../../plan/pilgrimage_models.dart';
import '../../records/comparison_export_config.dart';
import '../../records/comparison_export_config_storage_stub.dart'
    if (dart.library.io) '../../records/comparison_export_config_storage_io.dart';
import '../settings_store.dart';

/// Confirmation copy of 「恢复初始设置」 (DESIGN §8.19: now also mentions
/// that the data-source addresses are reset).
abstract final class ResetSettingsCopy {
  static const title = '恢复初始设置';
  static const message =
      '所有外观、拍摄和地图设置将恢复为默认值，地图源、Anitabi 服务地址和路径规划服务地址等数据源设置也会一起恢复。';
  static const confirmLabel = '恢复';
  static const notice = '恢复后仍可重新调整各项设置';
  static const emphasizedValues = ['所有外观、拍摄和地图设置', '数据源设置'];
  static const done = '已恢复初始设置';
}

/// Saves the default [AppSettings] and resets the comparison export config
/// (old `_confirmResetSettings`). [onSaved] runs once the settings are saved
/// and before the export config is cleared (where the old screen showed
/// 「已恢复初始设置」); a failed save throws and skips it.
Future<void> resetAppSettingsToDefaults(
  SettingsStore store, {
  Future<void> Function() clearExportConfig = clearComparisonExportConfig,
  void Function()? onSaved,
}) async {
  const settings = AppSettings();
  ComparisonExportConfig.lastUsed = const ComparisonExportConfig();
  await store.update(settings);
  onSaved?.call();
  await clearExportConfig();
}
