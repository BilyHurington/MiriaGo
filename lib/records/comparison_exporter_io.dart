import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_url.dart';
import '../data/app_managed_file_paths_io.dart';
import 'comparison_export_config.dart';
import 'comparison_export_renderer.dart';

enum ComparisonExportFailureReason {
  referenceUnavailable,
  capturedPhotoUnavailable,
  renderFailed,
}

class ComparisonExportImageResult {
  const ComparisonExportImageResult._({this.path, this.failureReason});

  const ComparisonExportImageResult.success(String path) : this._(path: path);

  const ComparisonExportImageResult.failure(
    ComparisonExportFailureReason reason,
  ) : this._(failureReason: reason);

  final String? path;
  final ComparisonExportFailureReason? failureReason;

  bool get isSuccess => path != null;
}

Future<ComparisonExportImageResult> exportComparisonImage({
  required String? referenceImagePath,
  required String? referenceImageUrl,
  required String capturedPath,
  required ComparisonExportConfig config,
  required Map<ComparisonMetadataField, String> metadata,
  required String? colorGradingSummary,
}) async {
  Uint8List? refBytes;
  if (referenceImagePath != null) {
    final resolvedReferencePath =
        resolveExistingAppManagedFilePathSync(referenceImagePath) ??
        referenceImagePath;
    final refFile = File(resolvedReferencePath);
    if (refFile.existsSync()) {
      refBytes = refFile.readAsBytesSync();
    }
  }
  if (refBytes == null && referenceImageUrl != null) {
    try {
      final uri = Uri.parse(referenceImageUrl);
      if (anitabiImageHosts.contains(uri.host)) {
        final bytes = await fetchAnitabiImageBytes(referenceImageUrl);
        if (bytes != null) {
          refBytes = Uint8List.fromList(bytes);
        }
      } else {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          refBytes = response.bodyBytes;
        }
      }
    } catch (_) {}
  }

  if (refBytes == null) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.referenceUnavailable,
    );
  }

  final resolvedCapturedPath =
      resolveExistingAppManagedFilePathSync(capturedPath) ?? capturedPath;
  final capFile = File(resolvedCapturedPath);
  if (!capFile.existsSync()) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.capturedPhotoUnavailable,
    );
  }
  final capBytes = capFile.readAsBytesSync();

  const renderer = ComparisonExportRenderer();
  final outputBytes = await renderer.render(
    referenceBytes: refBytes,
    capturedBytes: capBytes,
    config: config,
    metadata: metadata,
    colorGradingSummary: colorGradingSummary,
  );

  if (outputBytes == null) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.renderFailed,
    );
  }

  final directory = await getApplicationDocumentsDirectory();
  final recordsDirectory = Directory('${directory.path}/visit_record_images');
  if (!recordsDirectory.existsSync()) {
    recordsDirectory.createSync(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '${recordsDirectory.path}/comparison_$timestamp.png';
  await File(path).writeAsBytes(outputBytes, flush: true);
  return ComparisonExportImageResult.success(path);
}
