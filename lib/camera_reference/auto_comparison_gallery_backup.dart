import 'package:flutter/foundation.dart';

import '../plan/pilgrimage_models.dart';
import '../records/comparison_export_config.dart';
import '../records/comparison_export_config_storage_stub.dart'
    if (dart.library.io) '../records/comparison_export_config_storage_io.dart';
import '../records/comparison_exporter_stub.dart'
    if (dart.library.io) '../records/comparison_exporter_io.dart';
import '../records/gallery_saver_stub.dart'
    if (dart.library.io) '../records/gallery_saver_io.dart';
import '../records/visit_record_file_ops_stub.dart'
    if (dart.library.io) '../records/visit_record_file_ops_io.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';

enum AutoComparisonGalleryStatus {
  saved,
  referenceUnavailable,
  capturedPhotoUnavailable,
  renderFailed,
  galleryFailed,
}

class AutoComparisonGalleryResult {
  const AutoComparisonGalleryResult(this.status);

  final AutoComparisonGalleryStatus status;

  bool get isSuccess => status == AutoComparisonGalleryStatus.saved;
}

typedef AutoComparisonConfigLoader = Future<ComparisonExportConfig?> Function();

typedef AutoComparisonExporter =
    Future<ComparisonExportImageResult> Function({
      required String? referenceImagePath,
      required String? referenceImageUrl,
      required String capturedPath,
      required ComparisonExportConfig config,
      required Map<ComparisonMetadataField, String> metadata,
      required String? colorGradingSummary,
    });

typedef AutoComparisonGallerySaver = Future<bool> Function(String filePath);

bool shouldAutoSaveComparisonToGallery(AppSettings settings) {
  if (!settings.autoSaveComparisonToGallery || kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

Future<AutoComparisonGalleryResult> autoSaveComparisonImageToGallery({
  required PilgrimageVisitRecord record,
  required PilgrimagePoint point,
  required AppSettings settings,
  required String? pointReferenceFullImagePath,
  required String? pointReferenceImageUrl,
  AutoComparisonConfigLoader loadConfig = loadComparisonExportConfig,
  AutoComparisonExporter exporter = exportComparisonImage,
  AutoComparisonGallerySaver gallerySaver = saveImageToGallery,
}) async {
  final savedConfig = await loadConfig();
  final config = (savedConfig ?? ComparisonExportConfig.lastUsed).withSettings(
    settings,
  );
  final referenceImagePath = _firstExistingLocalPath([
    record.referenceImagePath,
    pointReferenceFullImagePath,
  ]);
  final referenceImageUrl = referenceImagePath == null
      ? (record.referenceImageUrl ?? pointReferenceImageUrl)
      : null;
  final capturedPath = resolveVisitRecordDisplayPhotoPath(record);
  if (capturedPath == null) {
    return const AutoComparisonGalleryResult(
      AutoComparisonGalleryStatus.capturedPhotoUnavailable,
    );
  }

  final result = await exporter(
    referenceImagePath: referenceImagePath,
    referenceImageUrl: referenceImageUrl,
    capturedPath: capturedPath,
    config: config,
    metadata: comparisonMetadataForRecord(record: record, point: point),
    colorGradingSummary: null,
  );

  if (!result.isSuccess) {
    return AutoComparisonGalleryResult(switch (result.failureReason) {
      ComparisonExportFailureReason.referenceUnavailable =>
        AutoComparisonGalleryStatus.referenceUnavailable,
      ComparisonExportFailureReason.capturedPhotoUnavailable =>
        AutoComparisonGalleryStatus.capturedPhotoUnavailable,
      ComparisonExportFailureReason.renderFailed ||
      null => AutoComparisonGalleryStatus.renderFailed,
    });
  }

  final saved = await gallerySaver(result.path!);
  return AutoComparisonGalleryResult(
    saved
        ? AutoComparisonGalleryStatus.saved
        : AutoComparisonGalleryStatus.galleryFailed,
  );
}

Map<ComparisonMetadataField, String> comparisonMetadataForRecord({
  required PilgrimageVisitRecord record,
  required PilgrimagePoint point,
}) {
  final meta = <ComparisonMetadataField, String>{
    ComparisonMetadataField.capturedAt: formatComparisonDateTime(
      record.capturedAt,
    ),
    ComparisonMetadataField.pointName: point.name,
    ComparisonMetadataField.workTitle: point.work.title,
    ComparisonMetadataField.episodeLabel: point.displayEpisodeLabel,
    ComparisonMetadataField.coordinates:
        '${point.position.latitude.toStringAsFixed(5)}, '
        '${point.position.longitude.toStringAsFixed(5)}',
  };
  if (point.sourceId != null) {
    meta[ComparisonMetadataField.anitabiId] = point.sourceId!;
  }
  return meta;
}

String formatComparisonDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String? _firstExistingLocalPath(Iterable<String?> paths) {
  for (final path in paths.whereType<String>()) {
    if (visitRecordLocalFileExists(path)) {
      return path;
    }
  }
  return null;
}
