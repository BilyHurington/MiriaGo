import 'comparison_export_config.dart';

import 'comparison_export_result.dart';

export 'comparison_export_result.dart';

Future<ComparisonExportImageResult> exportComparisonImage({
  required String? referenceImagePath,
  required String? referenceImageUrl,
  required String capturedPath,
  required ComparisonExportConfig config,
  required Map<ComparisonMetadataField, String> metadata,
  required String? colorGradingSummary,
}) async {
  return const ComparisonExportImageResult.failure(
    ComparisonExportFailureReason.renderFailed,
  );
}
