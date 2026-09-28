import 'dart:io';

import 'plan_import_package.dart';
import 'plan_import_stream.dart';
import 'plan_transfer_background.dart';

/// Whether [path] names a local file the import worker can open itself, so
/// the package bytes never have to be copied into the worker isolate.
bool canReadPlanImportFromPath(String path) =>
    path.isNotEmpty && File(path).existsSync();

Future<PlanImportPackage> readPlanImportPackageFromPath(
  String path, {
  String? sourceName,
  PlanTransferCancellation? cancellation,
}) {
  // Reading, inflating and CRC-checking up to 256 MiB must not block the UI
  // isolate, so the whole read happens in a worker isolate.
  return runPlanTransferTask(
    () => _readPlanImportPackageFromPath(path, sourceName),
    cancellation: cancellation,
  );
}

Future<PlanImportPackage> _readPlanImportPackageFromPath(
  String path,
  String? sourceName,
) async {
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
    sourceName:
        sourceName ??
        (file.uri.pathSegments.isEmpty ? path : file.uri.pathSegments.last),
  );
}
