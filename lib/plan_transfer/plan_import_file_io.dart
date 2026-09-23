import 'dart:io';

import 'plan_import_package.dart';
import 'plan_import_stream.dart';

Future<PlanImportPackage> readPlanImportPackageFromPath(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('Plan package file does not exist.', path);
  }
  const limits = PlanImportLimits();
  final size = await file.length();
  if (size > limits.maxCompressedBytes) {
    throw PlanImportLimitException('压缩包字节数', size, limits.maxCompressedBytes);
  }
  return readPlanImportPackageFromBytes(
    await readBoundedPlanImportStream(file.openRead()),
    sourceName: file.uri.pathSegments.isEmpty
        ? path
        : file.uri.pathSegments.last,
  );
}
