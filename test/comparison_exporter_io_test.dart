import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_exporter_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_comparison_export_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      p.join(tempDirectory.path, 'documents'),
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('fails explicitly when reference image is unavailable', () async {
    final captured = File(p.join(tempDirectory.path, 'captured.jpg'))
      ..writeAsBytesSync(<int>[1, 2, 3], flush: true);

    final result = await exportComparisonImage(
      referenceImagePath: null,
      referenceImageUrl: null,
      capturedPath: captured.path,
      config: const ComparisonExportConfig(),
      metadata: const {},
      colorGradingSummary: null,
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.failureReason,
      ComparisonExportFailureReason.referenceUnavailable,
    );
  });
}
