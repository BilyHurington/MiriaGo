import 'package:flutter/material.dart';

enum ComparisonOutputWidth { auto, w1080, w1920, w2560, w3840 }

enum ComparisonMetadataField {
  capturedAt,
  workTitle,
  pointName,
  coordinates,
  anitabiId,
  episodeLabel,
}

extension ComparisonOutputWidthValue on ComparisonOutputWidth {
  double? get px => switch (this) {
    ComparisonOutputWidth.auto => null,
    ComparisonOutputWidth.w1080 => 1080,
    ComparisonOutputWidth.w1920 => 1920,
    ComparisonOutputWidth.w2560 => 2560,
    ComparisonOutputWidth.w3840 => 3840,
  };

  String get label => switch (this) {
    ComparisonOutputWidth.auto => '自动',
    ComparisonOutputWidth.w1080 => '1080px',
    ComparisonOutputWidth.w1920 => '1920px',
    ComparisonOutputWidth.w2560 => '2560px',
    ComparisonOutputWidth.w3840 => '3840px',
  };
}

extension ComparisonMetadataFieldLabel on ComparisonMetadataField {
  String get label => switch (this) {
    ComparisonMetadataField.capturedAt => '拍摄时间',
    ComparisonMetadataField.workTitle => '作品',
    ComparisonMetadataField.pointName => '地点',
    ComparisonMetadataField.coordinates => '坐标',
    ComparisonMetadataField.anitabiId => 'Anitabi ID',
    ComparisonMetadataField.episodeLabel => '场景',
  };
}

class ComparisonExportConfig {
  const ComparisonExportConfig({
    this.borderWidthPercent = 0.5,
    this.borderColor = Colors.white,
    this.outputWidth = ComparisonOutputWidth.auto,
    this.showLabels = false,
    this.metadataFields = const {
      ComparisonMetadataField.capturedAt,
      ComparisonMetadataField.workTitle,
      ComparisonMetadataField.pointName,
    },
  });

  final double borderWidthPercent;
  final Color borderColor;
  final ComparisonOutputWidth outputWidth;
  final bool showLabels;
  final Set<ComparisonMetadataField> metadataFields;

  static ComparisonExportConfig lastUsed = const ComparisonExportConfig();

  ComparisonExportConfig copyWith({
    double? borderWidthPercent,
    Color? borderColor,
    ComparisonOutputWidth? outputWidth,
    bool? showLabels,
    Set<ComparisonMetadataField>? metadataFields,
  }) {
    return ComparisonExportConfig(
      borderWidthPercent: borderWidthPercent ?? this.borderWidthPercent,
      borderColor: borderColor ?? this.borderColor,
      outputWidth: outputWidth ?? this.outputWidth,
      showLabels: showLabels ?? this.showLabels,
      metadataFields: metadataFields ?? this.metadataFields,
    );
  }
}
