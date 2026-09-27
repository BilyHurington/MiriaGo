import 'dart:convert';

import 'package:flutter/material.dart';

import '../plan/pilgrimage_models.dart';

enum ComparisonOutputWidth { auto, w1080, w1920, w2560, w3840 }

enum ComparisonImageEncoding { jpegRecommended, jpegHighQuality, png }

extension ComparisonImageEncodingValue on ComparisonImageEncoding {
  int? get jpegQuality => switch (this) {
    ComparisonImageEncoding.jpegRecommended => 85,
    ComparisonImageEncoding.jpegHighQuality => 95,
    ComparisonImageEncoding.png => null,
  };

  String get extension => this == ComparisonImageEncoding.png ? 'png' : 'jpg';
  String get mimeType =>
      this == ComparisonImageEncoding.png ? 'image/png' : 'image/jpeg';
  String get label => switch (this) {
    ComparisonImageEncoding.jpegRecommended => 'JPEG 推荐 (85)',
    ComparisonImageEncoding.jpegHighQuality => 'JPEG 高画质 (95)',
    ComparisonImageEncoding.png => 'PNG 无损',
  };
}

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
    this.imageEncoding = ComparisonImageEncoding.jpegRecommended,
    this.showLabels = false,
    this.showPilgrimName = false,
    this.pilgrimName = '',
    this.showColorGradingParams = false,
    this.metadataFields = const {
      ComparisonMetadataField.capturedAt,
      ComparisonMetadataField.workTitle,
      ComparisonMetadataField.pointName,
    },
  });

  final double borderWidthPercent;
  final Color borderColor;
  final ComparisonOutputWidth outputWidth;
  final ComparisonImageEncoding imageEncoding;
  final bool showLabels;
  final bool showPilgrimName;
  final String pilgrimName;
  final bool showColorGradingParams;
  final Set<ComparisonMetadataField> metadataFields;

  static ComparisonExportConfig lastUsed = const ComparisonExportConfig();

  factory ComparisonExportConfig.fromSettings(AppSettings settings) {
    ComparisonExportConfig config = const ComparisonExportConfig();
    final encoded = settings.comparisonExportConfigJson.trim();
    if (encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          config = ComparisonExportConfig.fromJson(
            Map<String, Object?>.from(decoded),
          );
        }
      } catch (_) {}
    }
    return config.withSettings(settings);
  }

  ComparisonExportConfig withSettings(AppSettings settings) {
    return copyWith(
      showPilgrimName: settings.comparisonShowPilgrimName,
      pilgrimName: settings.comparisonPilgrimName,
    );
  }

  AppSettings applyToSettings(AppSettings settings) {
    return settings.copyWith(
      comparisonShowPilgrimName: showPilgrimName,
      comparisonPilgrimName: pilgrimName,
      comparisonExportConfigJson: jsonEncode(toJson()),
      comparisonExportConfigMigrated: true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'borderWidthPercent': borderWidthPercent,
      'borderColor': borderColor.toARGB32(),
      'outputWidth': outputWidth.name,
      'imageEncoding': imageEncoding.name,
      'showLabels': showLabels,
      'showPilgrimName': showPilgrimName,
      'pilgrimName': pilgrimName,
      'showColorGradingParams': showColorGradingParams,
      'metadataFields': metadataFields.map((field) => field.name).toList(),
    };
  }

  factory ComparisonExportConfig.fromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(List<T> values, Object? value, T fallback) {
      return values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => fallback,
      );
    }

    final fields = json['metadataFields'];
    return ComparisonExportConfig(
      borderWidthPercent:
          (json['borderWidthPercent'] as num?)?.toDouble().clamp(0.0, 3.0) ??
          0.5,
      borderColor: Color((json['borderColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
      outputWidth: enumValue(
        ComparisonOutputWidth.values,
        json['outputWidth'],
        ComparisonOutputWidth.auto,
      ),
      imageEncoding: enumValue(
        ComparisonImageEncoding.values,
        json['imageEncoding'],
        ComparisonImageEncoding.jpegRecommended,
      ),
      showLabels: json['showLabels'] as bool? ?? false,
      showPilgrimName: json['showPilgrimName'] as bool? ?? false,
      pilgrimName: json['pilgrimName'] as String? ?? '',
      showColorGradingParams: json['showColorGradingParams'] as bool? ?? false,
      metadataFields: fields is List
          ? fields
                .map(
                  (field) => enumValue(
                    ComparisonMetadataField.values,
                    field,
                    ComparisonMetadataField.capturedAt,
                  ),
                )
                .toSet()
          : const {
              ComparisonMetadataField.capturedAt,
              ComparisonMetadataField.workTitle,
              ComparisonMetadataField.pointName,
            },
    );
  }

  ComparisonExportConfig copyWith({
    double? borderWidthPercent,
    Color? borderColor,
    ComparisonOutputWidth? outputWidth,
    ComparisonImageEncoding? imageEncoding,
    bool? showLabels,
    bool? showPilgrimName,
    String? pilgrimName,
    bool? showColorGradingParams,
    Set<ComparisonMetadataField>? metadataFields,
  }) {
    return ComparisonExportConfig(
      borderWidthPercent: borderWidthPercent ?? this.borderWidthPercent,
      borderColor: borderColor ?? this.borderColor,
      outputWidth: outputWidth ?? this.outputWidth,
      imageEncoding: imageEncoding ?? this.imageEncoding,
      showLabels: showLabels ?? this.showLabels,
      showPilgrimName: showPilgrimName ?? this.showPilgrimName,
      pilgrimName: pilgrimName ?? this.pilgrimName,
      showColorGradingParams:
          showColorGradingParams ?? this.showColorGradingParams,
      metadataFields: metadataFields ?? this.metadataFields,
    );
  }
}
