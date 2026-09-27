import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../color_grading/color_grading_params.dart';
import '../../data/pilgrimage_repository.dart';
import '../../desktop/desktop_asset_image.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/reference_image_status.dart';
import '../../records/comparison_export_config.dart';
import '../../records/visit_record_file_ops_stub.dart'
    if (dart.library.io) '../../records/visit_record_file_ops_io.dart'
    as file_ops;
import '../../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../../records/visit_record_photo_io.dart'
    as photo_ops;

/// Resolved images of a record (old `VisitRecordDetailScreen` helpers).
@immutable
class RecordImages {
  const RecordImages({
    required this.referencePath,
    required this.referenceUrl,
    required this.photoPath,
  });

  /// Local reference (record path → point full image), or null.
  final String? referencePath;

  /// Remote reference (record url → point remote url), or null.
  final String? referenceUrl;

  /// Displayed pilgrimage photo (graded preferred), or null when missing.
  final String? photoPath;

  bool get hasReference => referencePath != null || referenceUrl != null;
}

/// Outcome of deleting a record (maps to the old snack messages).
enum RecordDeleteOutcome {
  /// Record deleted (and photos removed when asked).
  deleted,

  /// Metadata deletion failed: 「删除记录失败，照片未删除，请重试」.
  failed,

  /// Record deleted but some photos remain: 「记录已删除，部分照片未清理」.
  deletedWithLeftovers,
}

/// Record detail logic ported line by line from the old
/// `VisitRecordDetailScreen`. Pure except for the file checks, which can be
/// replaced in tests.
class RecordDetails {
  const RecordDetails({
    this.localFileExists = file_ops.visitRecordLocalFileExists,
    this.isWeb = kIsWeb,
  });

  final bool Function(String path) localFileExists;
  final bool isWeb;

  static const deleteFailedMessage = '删除记录失败，照片未删除，请重试';
  static const deleteLeftoversMessage = '记录已删除，部分照片未清理';
  static const orphanNotice = '这条记录对应的点位已不在当前计划中，照片和导出功能仍然可以使用。';

  RecordImages imagesFor(PilgrimageVisitRecord record, PilgrimagePoint? point) {
    return RecordImages(
      referencePath: referenceImagePath(record, point),
      referenceUrl: referenceImageUrl(record, point),
      photoPath: displayPhotoPath(record),
    );
  }

  /// Graded → photo → original, first one that can be displayed.
  static String? displayPhotoPath(PilgrimageVisitRecord record) =>
      photo_ops.resolveVisitRecordDisplayPhotoPath(record);

  /// Original → photo → graded (the grading source).
  static String? sourcePhotoPath(PilgrimageVisitRecord record) =>
      photo_ops.resolveVisitRecordSourcePhotoPath(record);

  /// Record local path → point full reference (web also accepts desktop
  /// asset paths).
  String? referenceImagePath(
    PilgrimageVisitRecord record,
    PilgrimagePoint? point,
  ) {
    for (final path in [
      record.referenceImagePath,
      point?.referenceFullImagePath,
    ].whereType<String>()) {
      if (localFileExists(path) || (isWeb && isDesktopAssetPath(path))) {
        return path;
      }
    }
    return null;
  }

  /// Record url → point remote url.
  String? referenceImageUrl(
    PilgrimageVisitRecord record,
    PilgrimagePoint? point,
  ) {
    if (record.referenceImageUrl != null) {
      return record.referenceImageUrl;
    }
    if (point == null || !hasRemoteReferenceImage(point)) {
      return null;
    }
    return point.referenceImageUrl;
  }

  static String title(PilgrimageVisitRecord record, PilgrimagePoint? point) =>
      point?.name ?? record.displayPointNameSnapshot;

  static String subtitle(PilgrimageVisitRecord record, PilgrimagePoint? point) {
    if (point == null) {
      final workTitle = record.displayWorkTitleSnapshot;
      final pointSubtitle = record.displayPointSubtitleSnapshot;
      if (pointSubtitle.isEmpty) {
        return workTitle;
      }
      return '$workTitle / $pointSubtitle';
    }
    return '${point.work.title} / ${point.subtitle}';
  }

  /// 「未分组」, the group name or 「未知片区」.
  static String groupName(PilgrimagePlan plan, PilgrimagePoint point) {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未分组';
    }
    return plan.groups
            .where((group) => group.id == groupId)
            .firstOrNull
            ?.name ??
        '未知片区';
  }

  /// 「yyyy-MM-dd HH:mm」.
  static String formatDateTime(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// Comparison metadata (point values, or the record snapshot for an
  /// orphan record).
  static Map<ComparisonMetadataField, String> comparisonMetadata(
    PilgrimageVisitRecord record,
    PilgrimagePoint? point,
  ) {
    final meta = <ComparisonMetadataField, String>{
      ComparisonMetadataField.capturedAt: formatDateTime(record.capturedAt),
    };
    if (point != null) {
      meta[ComparisonMetadataField.pointName] = point.name;
      meta[ComparisonMetadataField.workTitle] = point.work.title;
      meta[ComparisonMetadataField.episodeLabel] = point.displayEpisodeLabel;
      if (point.hasCoordinate) {
        meta[ComparisonMetadataField.coordinates] =
            '${point.position.latitude.toStringAsFixed(5)}, '
            '${point.position.longitude.toStringAsFixed(5)}';
      }
      if (point.sourceId != null) {
        meta[ComparisonMetadataField.anitabiId] = point.sourceId!;
      }
    } else {
      meta[ComparisonMetadataField.pointName] = record.displayPointNameSnapshot;
      meta[ComparisonMetadataField.workTitle] = record.displayWorkTitleSnapshot;
    }
    return meta;
  }

  /// Parameter summary printed on comparison images, or null.
  static String? colorGradingSummary(PilgrimageVisitRecord record) {
    final paramsJson = record.colorGradingParamsJson;
    if (paramsJson == null || paramsJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is! Map) {
        return null;
      }
      final targetParams = ColorGradingParams.fromJson(
        Map<String, Object?>.from(decoded),
      );
      final intensity = (record.colorGradingIntensity ?? 1).clamp(0.0, 1.0);
      final params = ColorGradingParams.lerp(
        ColorGradingParams.defaults,
        targetParams,
        intensity,
      );
      const threshold = 0.005;
      final defaults = ColorGradingParams.defaults;
      final parts = <String>[];

      String signed(double value) =>
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
      String plain(double value) => value.toStringAsFixed(2);
      bool changed(double value, double fallback) =>
          (value - fallback).abs() >= threshold;
      void addZeroBased(String label, double value, double fallback) {
        if (changed(value, fallback)) {
          parts.add('$label ${signed(value)}');
        }
      }

      addZeroBased('亮度', params.brightness, defaults.brightness);
      addZeroBased('曝光', params.exposure, defaults.exposure);
      if (changed(params.contrast, defaults.contrast)) {
        parts.add('对比 ${plain(params.contrast)}');
      }
      if (changed(params.saturation, defaults.saturation)) {
        parts.add('饱和 ${plain(params.saturation)}');
      }
      addZeroBased('色温', params.temperature, defaults.temperature);
      addZeroBased('色调', params.tint, defaults.tint);
      addZeroBased('高光', params.highlights, defaults.highlights);
      addZeroBased('阴影', params.shadows, defaults.shadows);
      addZeroBased('R暗', params.redShadowCurve, defaults.redShadowCurve);
      addZeroBased('R中', params.redMidCurve, defaults.redMidCurve);
      addZeroBased('R亮', params.redHighlightCurve, defaults.redHighlightCurve);
      addZeroBased('G暗', params.greenShadowCurve, defaults.greenShadowCurve);
      addZeroBased('G中', params.greenMidCurve, defaults.greenMidCurve);
      addZeroBased(
        'G亮',
        params.greenHighlightCurve,
        defaults.greenHighlightCurve,
      );
      addZeroBased('B暗', params.blueShadowCurve, defaults.blueShadowCurve);
      addZeroBased('B中', params.blueMidCurve, defaults.blueMidCurve);
      addZeroBased(
        'B亮',
        params.blueHighlightCurve,
        defaults.blueHighlightCurve,
      );

      if (parts.isEmpty) {
        return null;
      }
      return parts.join('  ');
    } catch (_) {
      return null;
    }
  }
}

/// Deletes a record and, when asked, its photos that nothing else uses.
///
/// Photos are only touched after the metadata deletion has succeeded.
Future<RecordDeleteOutcome> deleteVisitRecordWithPhotos({
  required PilgrimageVisitRecord record,
  required Future<void> Function() deleteRecord,
  required PilgrimageRepository? repository,
  required bool deleteFiles,
  Future<void> Function({
        required PilgrimageVisitRecord record,
        required PilgrimageRepository repository,
      })
      deletePhotos =
      file_ops.deleteUnreferencedVisitRecordPhotos,
}) async {
  try {
    await deleteRecord();
  } catch (_) {
    return RecordDeleteOutcome.failed;
  }
  if (deleteFiles && repository != null) {
    try {
      await deletePhotos(record: record, repository: repository);
    } catch (_) {
      return RecordDeleteOutcome.deletedWithLeftovers;
    }
  }
  return RecordDeleteOutcome.deleted;
}
