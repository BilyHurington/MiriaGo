import 'package:flutter/material.dart';

enum ComparisonBorderWidth { none, w2, w4, w6, w8 }

enum ComparisonMetadataField {
  capturedAt,
  workTitle,
  pointName,
  coordinates,
  anitabiId,
  episodeLabel,
}

extension ComparisonBorderWidthValue on ComparisonBorderWidth {
  double get px => switch (this) {
    ComparisonBorderWidth.none => 0,
    ComparisonBorderWidth.w2 => 2,
    ComparisonBorderWidth.w4 => 4,
    ComparisonBorderWidth.w6 => 6,
    ComparisonBorderWidth.w8 => 8,
  };

  String get label => switch (this) {
    ComparisonBorderWidth.none => '无',
    ComparisonBorderWidth.w2 => '2px',
    ComparisonBorderWidth.w4 => '4px',
    ComparisonBorderWidth.w6 => '6px',
    ComparisonBorderWidth.w8 => '8px',
  };
}

extension ComparisonMetadataFieldLabel on ComparisonMetadataField {
  String get label => switch (this) {
    ComparisonMetadataField.capturedAt => '拍摄时间',
    ComparisonMetadataField.workTitle => '作品名称',
    ComparisonMetadataField.pointName => '地点名称',
    ComparisonMetadataField.coordinates => '坐标',
    ComparisonMetadataField.anitabiId => 'Anitabi ID',
    ComparisonMetadataField.episodeLabel => '场景/集数',
  };
}

class ComparisonExportConfig {
  const ComparisonExportConfig({
    this.borderWidth = ComparisonBorderWidth.w2,
    this.borderColor = Colors.white,
    this.metadataFields = const {
      ComparisonMetadataField.capturedAt,
      ComparisonMetadataField.workTitle,
      ComparisonMetadataField.pointName,
    },
  });

  final ComparisonBorderWidth borderWidth;
  final Color borderColor;
  final Set<ComparisonMetadataField> metadataFields;

  ComparisonExportConfig copyWith({
    ComparisonBorderWidth? borderWidth,
    Color? borderColor,
    Set<ComparisonMetadataField>? metadataFields,
  }) {
    return ComparisonExportConfig(
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      metadataFields: metadataFields ?? this.metadataFields,
    );
  }
}
