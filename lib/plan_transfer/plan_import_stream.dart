import 'dart:typed_data';

import 'plan_import_package.dart';

Future<Uint8List> readBoundedPlanImportStream(
  Stream<List<int>> stream, {
  PlanImportLimits limits = const PlanImportLimits(),
}) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    final size = bytes.length + chunk.length;
    if (size > limits.maxCompressedBytes) {
      throw PlanImportLimitException('压缩包字节数', size, limits.maxCompressedBytes);
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
