import 'plan_import_package.dart';
import 'plan_import_asset_restore_stub.dart'
    if (dart.library.io) 'plan_import_asset_restore_io.dart'
    as platform;

bool get supportsPlanImportAssetRestore =>
    platform.supportsPlanImportAssetRestore;

Future<Map<String, String>> restorePlanImportAssets(
  PlanImportPackage importPackage,
) {
  return platform.restorePlanImportAssets(importPackage);
}
