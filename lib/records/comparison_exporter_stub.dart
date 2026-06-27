import 'comparison_export_config.dart';

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
  return const ComparisonExportImageResult.failure(
    ComparisonExportFailureReason.renderFailed,
  );
}
