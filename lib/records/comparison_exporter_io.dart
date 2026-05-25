import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'comparison_export_config.dart';
import 'comparison_export_renderer.dart';

Future<String?> exportComparisonImage({
  required String? referenceImagePath,
  required String? referenceImageUrl,
  required String capturedPath,
  required ComparisonExportConfig config,
  required Map<ComparisonMetadataField, String> metadata,
}) async {
  Uint8List? refBytes;
  if (referenceImagePath != null) {
    final refFile = File(referenceImagePath);
    if (refFile.existsSync()) {
      refBytes = refFile.readAsBytesSync();
    }
  }
  if (refBytes == null && referenceImageUrl != null) {
    try {
      final response = await http.get(Uri.parse(referenceImageUrl));
      if (response.statusCode == 200) {
        refBytes = response.bodyBytes;
      }
    } catch (_) {}
  }

  final capFile = File(capturedPath);
  if (!capFile.existsSync()) return null;
  final capBytes = capFile.readAsBytesSync();

  const renderer = ComparisonExportRenderer();
  final outputBytes = await renderer.render(
    referenceBytes: refBytes,
    capturedBytes: capBytes,
    config: config,
    metadata: metadata,
  );

  if (outputBytes == null) return null;

  final directory = await getApplicationDocumentsDirectory();
  final recordsDirectory = Directory('${directory.path}/visit_record_images');
  if (!recordsDirectory.existsSync()) {
    recordsDirectory.createSync(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '${recordsDirectory.path}/comparison_$timestamp.png';
  await File(path).writeAsBytes(outputBytes, flush: true);
  return path;
}
