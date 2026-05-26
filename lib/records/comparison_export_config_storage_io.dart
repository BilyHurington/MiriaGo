import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'comparison_export_config.dart';

Future<File> _configFile() async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}/comparison_export_config.json');
}

Future<ComparisonExportConfig?> loadComparisonExportConfig() async {
  try {
    final file = await _configFile();
    if (!file.existsSync()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map) {
      return ComparisonExportConfig.fromJson(
        Map<String, Object?>.from(decoded),
      );
    }
  } catch (_) {}
  return null;
}

Future<void> saveComparisonExportConfig(ComparisonExportConfig config) async {
  try {
    final file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  } catch (_) {}
}
