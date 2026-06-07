class DesktopLauncherInfo {
  const DesktopLauncherInfo({
    required this.appVersion,
    required this.platform,
    required this.portable,
    required this.fallbackUsed,
    required this.dataDir,
    required this.assetsDir,
    required this.exportsDir,
    required this.logsDir,
    required this.tempDir,
  });

  final String appVersion;
  final String platform;
  final bool portable;
  final bool fallbackUsed;
  final String dataDir;
  final String assetsDir;
  final String exportsDir;
  final String logsDir;
  final String tempDir;
}

class DesktopExportDestination {
  const DesktopExportDestination({required this.path});

  final String path;
}

class DesktopExportSaveResult {
  const DesktopExportSaveResult({required this.action, this.path});

  final String action;
  final String? path;
}

class DesktopStateResult {
  const DesktopStateResult({this.stateJson, required this.databasePath});

  final String? stateJson;
  final String databasePath;
}

class DesktopRestoreImportAssetsResult {
  const DesktopRestoreImportAssetsResult({required this.restoredPaths});

  final Map<String, String> restoredPaths;
}

class DesktopAssetResult {
  const DesktopAssetResult({required this.dataBase64, required this.mimeType});

  final String dataBase64;
  final String mimeType;
}

bool get isTauriLauncherAvailable => false;

Future<DesktopLauncherInfo?> loadDesktopLauncherInfo() async {
  return null;
}

Future<DesktopExportDestination?> prepareDesktopExportDestination({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  return null;
}

Future<DesktopExportSaveResult> writeDesktopExportFile({
  required String path,
  required String extension,
  required String dataBase64,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult?> loadDesktopState() async {
  return null;
}

Future<DesktopStateResult> saveDesktopState({required String stateJson}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> saveDesktopPlanBundle({
  required String planJson,
  required String visitRecordsJson,
  required String? activePlanId,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> deleteDesktopPlan({
  required String planId,
  required String? activePlanId,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> setDesktopActivePlan({
  required String planId,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> saveDesktopSettings({
  required String settingsJson,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> saveDesktopVisitRecord({
  required String recordJson,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopStateResult> deleteDesktopVisitRecord({
  required String recordId,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopRestoreImportAssetsResult> restoreDesktopImportAssets({
  required String? packageId,
  required String? sourceName,
  required Map<String, String> assetsBase64,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopAssetResult> readDesktopAsset({required String path}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}

Future<DesktopAssetResult> writeDesktopAsset({
  required String path,
  required String dataBase64,
}) async {
  throw UnsupportedError('Tauri desktop launcher is not available.');
}
