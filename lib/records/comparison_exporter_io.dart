import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../data/app_managed_file_paths_io.dart';
import '../data/bounded_image_decoder.dart';
import 'comparison_export_config.dart';
import 'comparison_export_renderer.dart';
import 'comparison_export_result.dart';
import 'comparison_export_support.dart';

export 'comparison_export_result.dart';

Future<ComparisonExportImageResult> exportComparisonImage({
  required String? referenceImagePath,
  required String? referenceImageUrl,
  required String capturedPath,
  required ComparisonExportConfig config,
  required Map<ComparisonMetadataField, String> metadata,
  required String? colorGradingSummary,
  int maxSourceBytes = maxImageEncodedBytes,
  ComparisonExportRenderer renderer = const ComparisonExportRenderer(),
}) async {
  Directory? owned;
  try {
    final output = await renderer.renderLoaded(
      loadSources: () async {
        final reference =
            await _readLocal(referenceImagePath, maxSourceBytes) ??
            await readRemoteComparisonImage(
              referenceImageUrl,
              maxBytes: maxSourceBytes,
            );
        if (reference == null) {
          throw const ComparisonSourceUnavailable(
            ComparisonExportFailureReason.referenceUnavailable,
          );
        }
        final capture = await _readLocal(capturedPath, maxSourceBytes);
        if (capture == null) {
          throw const ComparisonSourceUnavailable(
            ComparisonExportFailureReason.capturedPhotoUnavailable,
          );
        }
        return ComparisonRenderInputs(
          referenceBytes: reference,
          capturedBytes: capture,
        );
      },
      config: config,
      metadata: metadata,
      colorGradingSummary: colorGradingSummary,
    );
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/visit_record_images');
    await root.create(recursive: true);
    owned = await root.createTemp('comparison-');
    final file = File('${owned.path}/${comparisonFileName(output)}');
    await file.writeAsBytes(output.bytes, flush: true);
    return ComparisonExportImageResult.success(file.path);
  } catch (error) {
    if (owned != null) {
      try {
        await owned.delete(recursive: true);
      } catch (_) {}
    }
    return comparisonExportFailure(error);
  }
}

Future<Uint8List?> _readLocal(String? path, int maxBytes) async {
  if (path == null || path.isEmpty) return null;
  final resolved = resolveExistingAppManagedFilePathSync(path) ?? path;
  final file = File(resolved);
  if (!await file.exists()) return null;
  return readImageStreamBounded(
    file.openRead(),
    maxBytes: maxBytes,
    declaredLength: await file.length(),
  );
}
