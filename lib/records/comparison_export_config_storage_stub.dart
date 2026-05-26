import 'comparison_export_config.dart';

ComparisonExportConfig? _cachedConfig;

Future<ComparisonExportConfig?> loadComparisonExportConfig() async {
  return _cachedConfig;
}

Future<void> saveComparisonExportConfig(ComparisonExportConfig config) async {
  _cachedConfig = config;
}
