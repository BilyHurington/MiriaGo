import 'dart:math';

class ColorGradingParams {
  const ColorGradingParams({
    this.exposure = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
  });

  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;

  static const defaults = ColorGradingParams();

  ColorGradingParams copyWith({
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
  }) {
    return ColorGradingParams(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
    );
  }

  ColorGradingParams clamped() {
    return ColorGradingParams(
      exposure: exposure.clamp(-1.0, 1.0),
      contrast: contrast.clamp(0.7, 1.4),
      saturation: saturation.clamp(0.5, 1.6),
      temperature: temperature.clamp(-1.0, 1.0),
      tint: tint.clamp(-1.0, 1.0),
    );
  }

  static ColorGradingParams lerp(
    ColorGradingParams a,
    ColorGradingParams b,
    double t,
  ) {
    final amount = t.clamp(0.0, 1.0);
    double mix(double x, double y) => x + (y - x) * amount;
    return ColorGradingParams(
      exposure: mix(a.exposure, b.exposure),
      contrast: mix(a.contrast, b.contrast),
      saturation: mix(a.saturation, b.saturation),
      temperature: mix(a.temperature, b.temperature),
      tint: mix(a.tint, b.tint),
    ).clamped();
  }

  Map<String, Object?> toJson() {
    return {
      'exposure': exposure,
      'contrast': contrast,
      'saturation': saturation,
      'temperature': temperature,
      'tint': tint,
    };
  }

  factory ColorGradingParams.fromJson(Map<String, Object?> json) {
    double value(String key, double fallback) {
      return (json[key] as num?)?.toDouble() ?? fallback;
    }

    return ColorGradingParams(
      exposure: value('exposure', 0),
      contrast: value('contrast', 1),
      saturation: value('saturation', 1),
      temperature: value('temperature', 0),
      tint: value('tint', 0),
    ).clamped();
  }

  List<double> toColorMatrix() {
    final p = clamped();
    var matrix = _identityMatrix();
    matrix = _multiplyMatrix(
      _exposureMatrix(pow(2.0, p.exposure).toDouble()),
      matrix,
    );
    matrix = _multiplyMatrix(_contrastMatrix(p.contrast), matrix);
    matrix = _multiplyMatrix(_saturationMatrix(p.saturation), matrix);
    matrix = _multiplyMatrix(
      _channelBalanceMatrix(p.temperature, p.tint),
      matrix,
    );
    return matrix;
  }
}

List<double> _identityMatrix() {
  return const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
}

List<double> _exposureMatrix(double scale) {
  return [
    scale,
    0,
    0,
    0,
    0,
    0,
    scale,
    0,
    0,
    0,
    0,
    0,
    scale,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _contrastMatrix(double contrast) {
  final offset = 128 * (1 - contrast);
  return [
    contrast,
    0,
    0,
    0,
    offset,
    0,
    contrast,
    0,
    0,
    offset,
    0,
    0,
    contrast,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _saturationMatrix(double saturation) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final inv = 1 - saturation;
  return [
    lumR * inv + saturation,
    lumG * inv,
    lumB * inv,
    0,
    0,
    lumR * inv,
    lumG * inv + saturation,
    lumB * inv,
    0,
    0,
    lumR * inv,
    lumG * inv,
    lumB * inv + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _channelBalanceMatrix(double temperature, double tint) {
  final r = 1 + 0.10 * temperature - 0.04 * tint;
  final g = 1 + 0.08 * tint;
  final b = 1 - 0.10 * temperature - 0.04 * tint;
  return [r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
}

List<double> _multiplyMatrix(List<double> a, List<double> b) {
  final result = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row += 1) {
    for (var col = 0; col < 4; col += 1) {
      var sum = 0.0;
      for (var k = 0; k < 4; k += 1) {
        sum += a[row * 5 + k] * b[k * 5 + col];
      }
      result[row * 5 + col] = sum;
    }

    var offset = a[row * 5 + 4];
    for (var k = 0; k < 4; k += 1) {
      offset += a[row * 5 + k] * b[k * 5 + 4];
    }
    result[row * 5 + 4] = offset;
  }
  return result;
}
