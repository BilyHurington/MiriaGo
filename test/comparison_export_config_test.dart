import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/records/comparison_export_config.dart';

void main() {
  test('serializes comparison export config for global reuse', () {
    const config = ComparisonExportConfig(
      borderWidthPercent: 1.5,
      borderColor: Colors.black,
      outputWidth: ComparisonOutputWidth.w1920,
      showLabels: true,
      showPilgrimName: true,
      pilgrimName: 'BilyHurington',
      showColorGradingParams: true,
      metadataFields: {
        ComparisonMetadataField.pointName,
        ComparisonMetadataField.episodeLabel,
      },
    );

    final restored = ComparisonExportConfig.fromJson(config.toJson());

    expect(restored.borderWidthPercent, 1.5);
    expect(restored.borderColor, Colors.black);
    expect(restored.outputWidth, ComparisonOutputWidth.w1920);
    expect(restored.showLabels, isTrue);
    expect(restored.showPilgrimName, isTrue);
    expect(restored.pilgrimName, 'BilyHurington');
    expect(restored.showColorGradingParams, isTrue);
    expect(restored.metadataFields, {
      ComparisonMetadataField.pointName,
      ComparisonMetadataField.episodeLabel,
    });
  });
}
