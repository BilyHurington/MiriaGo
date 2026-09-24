import 'plan_import_package.dart';
import 'plan_import_asset_restore_stub.dart'
    if (dart.library.html) 'plan_import_asset_restore_web.dart'
    if (dart.library.io) 'plan_import_asset_restore_io.dart'
    as platform;

bool get supportsPlanImportAssetRestore =>
    platform.supportsPlanImportAssetRestore;

/// Restores only the package assets the imported plan references, plus those
/// of its visit records when [includeRecords] is set. Archive entries nothing
/// points to are never written.
Future<Map<String, String>> restorePlanImportAssets(
  PlanImportPackage importPackage, {
  required bool includeRecords,
}) {
  return platform.restorePlanImportAssets(
    importPackage.withReferencedAssetsOnly(includeRecords: includeRecords),
  );
}
