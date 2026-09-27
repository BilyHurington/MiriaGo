import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/bounded_image_decoder.dart';
import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;
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
}) async {
  try {
    const renderer = ComparisonExportRenderer();
    final output = await renderer.renderLoaded(
      loadSources: () async {
        final reference =
            await _readLocalImage(referenceImagePath) ??
            await readRemoteComparisonImage(referenceImageUrl);
        if (reference == null) {
          throw const ComparisonSourceUnavailable(
            ComparisonExportFailureReason.referenceUnavailable,
          );
        }
        final capture = await _readLocalImage(capturedPath);
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
    if (!tauri.isTauriLauncherAvailable) {
      return await downloadComparisonImage(output);
    }
    final path = 'assets/generated_comparisons/${comparisonFileName(output)}';
    await tauri.writeDesktopAsset(
      path: path,
      dataBase64: base64Encode(output.bytes),
    );
    return ComparisonExportImageResult.success(path);
  } catch (error) {
    return comparisonExportFailure(error);
  }
}

Future<Uint8List?> _readLocalImage(String? path) async {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;
  if (tauri.isTauriLauncherAvailable && isDesktopAssetPath(value)) {
    final asset = await tauri.readDesktopAsset(
      path: value,
      maxBytes: maxImageEncodedBytes,
    );
    final bytes = base64Decode(asset.dataBase64);
    checkImageEncodedLength(bytes.length);
    return bytes;
  }
  if (value.startsWith('docs/sample_images/')) {
    try {
      final data = await rootBundle.load(value);
      checkImageEncodedLength(data.lengthInBytes);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on ImageBudgetException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
  return readRemoteComparisonImage(value);
}
