import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_url.dart';
import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;
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
  var referenceBytes = await _readLocalImage(referenceImagePath);
  referenceBytes ??= await _readRemoteImage(referenceImageUrl);
  if (referenceBytes == null) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.referenceUnavailable,
    );
  }

  final capturedBytes = await _readLocalImage(capturedPath);
  if (capturedBytes == null) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.capturedPhotoUnavailable,
    );
  }

  const renderer = ComparisonExportRenderer();
  final outputBytes = await renderer.render(
    referenceBytes: referenceBytes,
    capturedBytes: capturedBytes,
    config: config,
    metadata: metadata,
    colorGradingSummary: colorGradingSummary,
  );
  if (outputBytes == null || !tauri.isTauriLauncherAvailable) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.renderFailed,
    );
  }

  final path =
      'assets/generated_comparisons/'
      'comparison_${DateTime.now().millisecondsSinceEpoch}.png';
  try {
    await tauri.writeDesktopAsset(
      path: path,
      dataBase64: base64Encode(outputBytes),
    );
    return ComparisonExportImageResult.success(path);
  } catch (_) {
    return const ComparisonExportImageResult.failure(
      ComparisonExportFailureReason.renderFailed,
    );
  }
}

Future<Uint8List?> _readLocalImage(String? path) async {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  if (tauri.isTauriLauncherAvailable && isDesktopAssetPath(value)) {
    try {
      final asset = await tauri.readDesktopAsset(path: value);
      if (asset.dataBase64.isNotEmpty) {
        return base64Decode(asset.dataBase64);
      }
    } catch (_) {}
  }

  if (value.startsWith('docs/sample_images/')) {
    try {
      final data = await rootBundle.load(value);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {}
  }
  return null;
}

Future<Uint8List?> _readRemoteImage(String? url) async {
  final value = url?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  try {
    final uri = Uri.parse(value);
    if (anitabiImageHosts.contains(uri.host)) {
      final bytes = await fetchAnitabiImageBytes(value);
      return bytes == null ? null : Uint8List.fromList(bytes);
    }
    final response = await http.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
  } catch (_) {}
  return null;
}
