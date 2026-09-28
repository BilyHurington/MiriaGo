import 'comparison_export_config.dart';

enum ComparisonExportFailureReason {
  referenceUnavailable,
  capturedPhotoUnavailable,
  budgetExceeded,
  unsupportedFormat,
  invalidData,
  renderFailed,
}

enum ComparisonExportDisposition { localFile, downloaded, canceled, failed }

class ComparisonExportImageResult {
  const ComparisonExportImageResult.success(String path)
    : this._(path: path, disposition: ComparisonExportDisposition.localFile);
  const ComparisonExportImageResult.downloaded()
    : this._(disposition: ComparisonExportDisposition.downloaded);
  const ComparisonExportImageResult.canceled()
    : this._(disposition: ComparisonExportDisposition.canceled);
  const ComparisonExportImageResult.failure(
    ComparisonExportFailureReason reason, {
    String? message,
  }) : this._(
         failureReason: reason,
         message: message,
         disposition: ComparisonExportDisposition.failed,
       );
  const ComparisonExportImageResult._({
    this.path,
    this.failureReason,
    this.message,
    required this.disposition,
  });

  final String? path;
  final ComparisonExportFailureReason? failureReason;
  final String? message;
  final ComparisonExportDisposition disposition;
  bool get isSuccess =>
      disposition == ComparisonExportDisposition.localFile ||
      disposition == ComparisonExportDisposition.downloaded;
}

typedef ComparisonImageExporter =
    Future<ComparisonExportImageResult> Function({
      required String? referenceImagePath,
      required String? referenceImageUrl,
      required String capturedPath,
      required ComparisonExportConfig config,
      required Map<ComparisonMetadataField, String> metadata,
      required String? colorGradingSummary,
    });
