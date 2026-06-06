import 'dart:io';

import 'plan_import_package.dart';

Future<PlanImportPackage> readPlanImportPackageFromPath(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('Plan package file does not exist.', path);
  }
  return readPlanImportPackageFromBytes(
    await file.readAsBytes(),
    sourceName: file.uri.pathSegments.isEmpty
        ? path
        : file.uri.pathSegments.last,
  );
}
