import 'dart:io';

import 'plan_import_package.dart';
import 'plan_import_stream.dart';
import 'plan_transfer_background.dart';

Future<PlanImportPackage> readPlanImportPackageFromPath(
  String path, {
  PlanTransferCancellation? cancellation,
}) {
  // Reading, inflating and CRC-checking up to 256 MiB must not block the UI
  // isolate, so the whole read happens in a worker isolate.
  return runPlanTransferTask(
    () => _readPlanImportPackageFromPath(path),
    cancellation: cancellation,
  );
}

Future<PlanImportPackage> _readPlanImportPackageFromPath(String path) async {
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
