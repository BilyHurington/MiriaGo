import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/color_grading/color_adjustment.dart';
import 'package:miriago/color_grading/color_grading_params.dart';

void main() {
  group('ColorGradingParams', () {
    test('keeps old saved json compatible with new parameters', () {
      final params = ColorGradingParams.fromJson({
        'brightness': 0.1,
        'exposure': 0.2,
        'contrast': 1.1,
        'saturation': 1.2,
        'temperature': 0.3,
        'tint': -0.4,
      });

      expect(params.brightness, 0.1);
      expect(params.exposure, 0.2);
      expect(params.contrast, 1.1);
      expect(params.saturation, 1.2);
      expect(params.temperature, 0.3);
      expect(params.tint, -0.4);
      expect(params.highlights, 0);
      expect(params.shadows, 0);
      expect(params.redMidCurve, 0);
      expect(params.greenMidCurve, 0);
      expect(params.blueMidCurve, 0);
    });

    test('serializes extended tone and three-point rgb curve parameters', () {
      const params = ColorGradingParams(
        highlights: 0.3,
        shadows: -0.2,
        redShadowCurve: 0.1,
        redMidCurve: 0.4,
        redHighlightCurve: 0.2,
        greenShadowCurve: -0.1,
        greenMidCurve: -0.5,
        greenHighlightCurve: -0.2,
        blueShadowCurve: 0.3,
        blueMidCurve: 0.6,
        blueHighlightCurve: 0.5,
      );

      final restored = ColorGradingParams.fromJson(params.toJson());

      expect(restored.highlights, 0.3);
      expect(restored.shadows, -0.2);
      expect(restored.redShadowCurve, 0.1);
      expect(restored.redMidCurve, 0.4);
      expect(restored.redHighlightCurve, 0.2);
      expect(restored.greenShadowCurve, -0.1);
      expect(restored.greenMidCurve, -0.5);
      expect(restored.greenHighlightCurve, -0.2);
      expect(restored.blueShadowCurve, 0.3);
      expect(restored.blueMidCurve, 0.6);
      expect(restored.blueHighlightCurve, 0.5);
    });

    test('maps legacy single rgb curve values to midtone points', () {
      final params = ColorGradingParams.fromJson({
        'redCurve': 0.4,
        'greenCurve': -0.5,
        'blueCurve': 0.6,
      });

      expect(params.redShadowCurve, 0);
      expect(params.redMidCurve, 0.4);
      expect(params.redHighlightCurve, 0);
      expect(params.greenMidCurve, -0.5);
      expect(params.blueMidCurve, 0.6);
    });
  });

  group('preview matrix matches saved render', () {
    const samples = [
      [100, 150, 200],
      [12, 40, 90],
      [230, 210, 180],
      [128, 128, 128],
      [0, 0, 0],
      [255, 255, 255],
    ];

    test('brightness is added after exposure and contrast', () {
      const params = ColorGradingParams(
        brightness: 0.1,
        exposure: 0.5,
        contrast: 1.2,
      );
      final exposure = pow(2.0, 0.5).toDouble();
      for (final sample in samples) {
        final expected = sample
            .map(
              (value) =>
                  ((value / 255 * exposure * 1.2 + 0.5 * (1 - 1.2) + 0.1).clamp(
                            0.0,
                            1.0,
                          ) *
                          255)
                      .round(),
            )
            .toList();
        expect(_renderPixel(sample, params), expected, reason: '$sample');
        _expectClose(_matrixPixel(sample, params), expected, '$sample');
      }
    });

    test('linear adjustments agree within rounding for sample colors', () {
      const paramSets = [
        ColorGradingParams(
          brightness: -0.12,
          exposure: 0.3,
          contrast: 0.85,
          saturation: 1.3,
          temperature: 0.4,
          tint: -0.3,
        ),
        ColorGradingParams(
          brightness: 0.2,
          exposure: -0.6,
          contrast: 1.35,
          saturation: 0.7,
          temperature: -0.5,
          tint: 0.6,
        ),
      ];
      for (final params in paramSets) {
        expect(params.hasNonLinearAdjustments, isFalse);
        for (final sample in samples) {
          _expectClose(
            _matrixPixel(sample, params),
            _renderPixel(sample, params),
            '$sample ${params.toJson()}',
          );
        }
      }
    });

    testWidgets('low-resolution preview is bounded and uses render path', (
      tester,
    ) async {
      final source = img.Image(width: 2000, height: 1000);
      img.fill(source, color: img.ColorRgb8(100, 150, 200));
      final bytes = Uint8List.fromList(img.encodePng(source));
      const params = ColorGradingParams(
        exposure: 0.2,
        shadows: 0.4,
        redMidCurve: 0.5,
        blueHighlightCurve: -0.3,
      );

      final preview = await tester.runAsync(
        () => prepareGradingPreviewSource(bytes),
      );

      expect(preview!.width, 1024);
      expect(preview.height, 512);
      expect(preview.rgba.length, 1024 * 512 * 4);
      final graded = gradeRgbaPixels(
        rgba: preview.rgba,
        width: preview.width,
        height: preview.height,
        params: params,
      );
      expect(graded.sublist(0, 3), _renderPixel([100, 150, 200], params));
      // The cached source must stay untouched for later renders.
      expect(preview.rgba.sublist(0, 3), [100, 150, 200]);
    });

    test('flags tone zones and curves as needing a rendered preview', () {
      expect(ColorGradingParams.defaults.hasNonLinearAdjustments, isFalse);
      expect(
        const ColorGradingParams(highlights: 0.2).hasNonLinearAdjustments,
        isTrue,
      );
      expect(
        const ColorGradingParams(blueShadowCurve: -0.1).hasNonLinearAdjustments,
        isTrue,
      );
      expect(
        const ColorGradingParams(brightness: 0.1, exposure: 0.4) ==
            const ColorGradingParams(brightness: 0.1, exposure: 0.4),
        isTrue,
      );
    });
  });
}

List<int> _renderPixel(List<int> rgb, ColorGradingParams params) {
  final output = gradeRgbaPixels(
    rgba: Uint8List.fromList([...rgb, 255]),
    width: 1,
    height: 1,
    params: params,
  );
  return output.sublist(0, 3);
}

List<int> _matrixPixel(List<int> rgb, ColorGradingParams params) {
  // Flutter's ColorFilter.matrix uses a 0-255 translation column.
  final m = params.toColorMatrix();
  final input = [...rgb.map((value) => value.toDouble()), 255.0];
  return [
    for (var row = 0; row < 3; row += 1)
      (m[row * 5] * input[0] +
              m[row * 5 + 1] * input[1] +
              m[row * 5 + 2] * input[2] +
              m[row * 5 + 3] * input[3] +
              m[row * 5 + 4])
          .clamp(0.0, 255.0)
          .round(),
  ];
}

void _expectClose(List<int> actual, List<int> expected, String reason) {
  for (var channel = 0; channel < 3; channel += 1) {
    expect(
      (actual[channel] - expected[channel]).abs(),
      lessThanOrEqualTo(1),
      reason: '$reason channel $channel: $actual vs $expected',
    );
  }
}
