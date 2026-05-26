import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/color_grading/color_grading_params.dart';

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
}
