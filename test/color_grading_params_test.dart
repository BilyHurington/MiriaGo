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
      expect(params.redCurve, 0);
      expect(params.greenCurve, 0);
      expect(params.blueCurve, 0);
    });

    test('serializes extended tone and rgb curve parameters', () {
      const params = ColorGradingParams(
        highlights: 0.3,
        shadows: -0.2,
        redCurve: 0.4,
        greenCurve: -0.5,
        blueCurve: 0.6,
      );

      final restored = ColorGradingParams.fromJson(params.toJson());

      expect(restored.highlights, 0.3);
      expect(restored.shadows, -0.2);
      expect(restored.redCurve, 0.4);
      expect(restored.greenCurve, -0.5);
      expect(restored.blueCurve, 0.6);
    });
  });
}
