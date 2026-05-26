import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'color_grading_params.dart';

class ColorMatchResult {
  const ColorMatchResult({
    required this.targetParams,
    required this.mode,
    required this.beforeScore,
    required this.afterScore,
  });

  final ColorGradingParams targetParams;
  final ColorMatchMode mode;
  final int beforeScore;
  final int afterScore;
}

Future<ColorMatchResult?> autoMatchColorTone({
  required Uint8List capturedBytes,
  required Uint8List referenceBytes,
  required ColorMatchMode mode,
}) async {
  final result = await compute(_autoMatchWorker, {
    'capturedBytes': capturedBytes,
    'referenceBytes': referenceBytes,
    'mode': mode.name,
  });
  if (result == null) {
    return null;
  }

  return ColorMatchResult(
    targetParams: ColorGradingParams.fromJson(
      Map<String, Object?>.from(result['params']! as Map),
    ),
    mode: ColorMatchMode.values.firstWhere(
      (candidate) => candidate.name == result['mode'],
      orElse: () => ColorMatchMode.standard,
    ),
    beforeScore: result['beforeScore']! as int,
    afterScore: result['afterScore']! as int,
  );
}

Future<Uint8List> renderGradedJpeg({
  required Uint8List imageBytes,
  required ColorGradingParams params,
}) {
  return compute(_renderGradedWorker, {
    'imageBytes': imageBytes,
    'params': params.toJson(),
  });
}

Map<String, Object?>? _autoMatchWorker(Map<String, Object?> input) {
  final capturedBytes = input['capturedBytes']! as Uint8List;
  final referenceBytes = input['referenceBytes']! as Uint8List;
  final mode = ColorMatchMode.values.firstWhere(
    (candidate) => candidate.name == input['mode'],
    orElse: () => ColorMatchMode.standard,
  );
  final config = _ModeConfig.forMode(mode);
  final captured = _decodePrepared(capturedBytes, maxLongSide: 256);
  final reference = _decodePrepared(referenceBytes, maxLongSide: 256);
  if (captured == null || reference == null) {
    return null;
  }

  final referenceStats = _ImageStats.fromImage(reference);
  final capturedStats = _ImageStats.fromImage(captured);
  var bestParams = _estimateInitialParams(
    referenceStats,
    capturedStats,
    config,
  );
  var bestLoss = _colorLoss(
    referenceStats,
    _adjustedStats(captured, bestParams),
  );
  final beforeLoss = _colorLoss(referenceStats, capturedStats);

  final steps = <String, double>{
    'brightness': 0.05 * config.stepScale,
    'exposure': 0.18 * config.stepScale,
    'contrast': 0.10 * config.stepScale,
    'saturation': 0.12 * config.stepScale,
    'temperature': 0.18 * config.stepScale,
    'tint': 0.14 * config.stepScale,
  };
  if (config.matchToneZones) {
    steps.addAll({
      'highlights': 0.20 * config.stepScale,
      'shadows': 0.20 * config.stepScale,
    });
  }
  if (config.matchRgbCurves) {
    steps.addAll({
      'redCurve': 0.18 * config.stepScale,
      'greenCurve': 0.18 * config.stepScale,
      'blueCurve': 0.18 * config.stepScale,
    });
  }

  for (var round = 0; round < config.rounds; round += 1) {
    var improved = false;
    for (final key in steps.keys) {
      for (final direction in const [-1.0, 1.0]) {
        final trial = _shiftParam(bestParams, key, steps[key]! * direction);
        final loss = _colorLoss(
          referenceStats,
          _adjustedStats(captured, trial),
        );
        if (loss < bestLoss) {
          bestLoss = loss;
          bestParams = trial;
          improved = true;
        }
      }
    }

    for (final key in steps.keys) {
      steps[key] = steps[key]! * 0.55;
    }
    if (!improved && steps.values.every((step) => step < 0.02)) {
      break;
    }
  }

  return {
    'params': bestParams.toJson(),
    'mode': mode.name,
    'beforeScore': _scoreFromLoss(beforeLoss),
    'afterScore': _scoreFromLoss(bestLoss),
  };
}

Uint8List _renderGradedWorker(Map<String, Object?> input) {
  final imageBytes = input['imageBytes']! as Uint8List;
  final params = ColorGradingParams.fromJson(
    Map<String, Object?>.from(input['params']! as Map),
  );
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    return imageBytes;
  }

  final image = img.bakeOrientation(decoded);
  _applyColorGrading(image, params);
  return Uint8List.fromList(img.encodeJpg(image, quality: 94));
}

img.Image? _decodePrepared(Uint8List bytes, {required int maxLongSide}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  final baked = img.bakeOrientation(decoded);
  final longSide = max(baked.width, baked.height);
  if (longSide <= maxLongSide) {
    return baked;
  }

  final scale = maxLongSide / longSide;
  return img.copyResize(
    baked,
    width: max(1, (baked.width * scale).round()),
    height: max(1, (baked.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}

ColorGradingParams _estimateInitialParams(
  _ImageStats reference,
  _ImageStats captured,
  _ModeConfig config,
) {
  const epsilon = 0.0001;
  return ColorGradingParams(
    brightness: ((reference.meanLuma - captured.meanLuma) * 0.5).clamp(
      -config.maxBrightness,
      config.maxBrightness,
    ),
    exposure:
        (log((reference.meanLuma + epsilon) / (captured.meanLuma + epsilon)) /
                ln2)
            .clamp(-config.maxExposure, config.maxExposure),
    contrast: (reference.stdLuma / (captured.stdLuma + epsilon)).clamp(
      config.minContrast,
      config.maxContrast,
    ),
    saturation: (reference.meanSaturation / (captured.meanSaturation + epsilon))
        .clamp(config.minSaturation, config.maxSaturation),
    temperature: ((reference.redBlueBalance - captured.redBlueBalance) * 3.0)
        .clamp(-config.maxColorBalance, config.maxColorBalance),
    tint: ((reference.greenBalance - captured.greenBalance) * 3.0).clamp(
      -config.maxColorBalance,
      config.maxColorBalance,
    ),
    highlights: config.matchToneZones
        ? ((reference.highlightLuma - captured.highlightLuma) * 2.4).clamp(
            -config.maxToneZone,
            config.maxToneZone,
          )
        : 0,
    shadows: config.matchToneZones
        ? ((reference.shadowLuma - captured.shadowLuma) * 2.4).clamp(
            -config.maxToneZone,
            config.maxToneZone,
          )
        : 0,
    redCurve: config.matchRgbCurves
        ? _initialCurve(reference.meanR, captured.meanR, config)
        : 0,
    greenCurve: config.matchRgbCurves
        ? _initialCurve(reference.meanG, captured.meanG, config)
        : 0,
    blueCurve: config.matchRgbCurves
        ? _initialCurve(reference.meanB, captured.meanB, config)
        : 0,
  ).clamped();
}

double _initialCurve(
  double referenceMean,
  double capturedMean,
  _ModeConfig config,
) {
  return ((referenceMean - capturedMean) * 2.2).clamp(
    -config.maxRgbCurve,
    config.maxRgbCurve,
  );
}

ColorGradingParams _shiftParam(
  ColorGradingParams params,
  String key,
  double delta,
) {
  return switch (key) {
    'brightness' => params.copyWith(brightness: params.brightness + delta),
    'exposure' => params.copyWith(exposure: params.exposure + delta),
    'contrast' => params.copyWith(contrast: params.contrast + delta),
    'saturation' => params.copyWith(saturation: params.saturation + delta),
    'temperature' => params.copyWith(temperature: params.temperature + delta),
    'tint' => params.copyWith(tint: params.tint + delta),
    'highlights' => params.copyWith(highlights: params.highlights + delta),
    'shadows' => params.copyWith(shadows: params.shadows + delta),
    'redCurve' => params.copyWith(redCurve: params.redCurve + delta),
    'greenCurve' => params.copyWith(greenCurve: params.greenCurve + delta),
    'blueCurve' => params.copyWith(blueCurve: params.blueCurve + delta),
    _ => params,
  }.clamped();
}

_ImageStats _adjustedStats(img.Image source, ColorGradingParams params) {
  final image = img.Image.from(source);
  _applyColorGrading(image, params);
  return _ImageStats.fromImage(image);
}

double _colorLoss(_ImageStats reference, _ImageStats candidate) {
  final luma = (reference.meanLuma - candidate.meanLuma).abs();
  final contrast = (reference.stdLuma - candidate.stdLuma).abs();
  final saturation = (reference.meanSaturation - candidate.meanSaturation)
      .abs();
  final temp = (reference.redBlueBalance - candidate.redBlueBalance).abs();
  final tint = (reference.greenBalance - candidate.greenBalance).abs();
  final highlights = (reference.highlightLuma - candidate.highlightLuma).abs();
  final shadows = (reference.shadowLuma - candidate.shadowLuma).abs();
  final red = (reference.meanR - candidate.meanR).abs();
  final green = (reference.meanG - candidate.meanG).abs();
  final blue = (reference.meanB - candidate.meanB).abs();
  return 0.24 * luma +
      0.17 * contrast +
      0.16 * saturation +
      0.09 * temp +
      0.08 * tint +
      0.09 * highlights +
      0.09 * shadows +
      0.03 * red +
      0.03 * green +
      0.02 * blue;
}

int _scoreFromLoss(double loss) {
  return (100 * exp(-3.2 * loss)).round().clamp(0, 100);
}

void _applyColorGrading(img.Image image, ColorGradingParams params) {
  final p = params.clamped();
  final exposureMul = pow(2.0, p.exposure).toDouble();
  final contrastOffset = 0.5 * (1 - p.contrast) + p.brightness;
  final rBalance = 1 + 0.10 * p.temperature - 0.04 * p.tint;
  final gBalance = 1 + 0.08 * p.tint;
  final bBalance = 1 - 0.10 * p.temperature - 0.04 * p.tint;
  final redGamma = pow(2.0, -0.42 * p.redCurve).toDouble();
  final greenGamma = pow(2.0, -0.42 * p.greenCurve).toDouble();
  final blueGamma = pow(2.0, -0.42 * p.blueCurve).toDouble();

  for (final pixel in image) {
    var r = pixel.rNormalized.toDouble();
    var g = pixel.gNormalized.toDouble();
    var b = pixel.bNormalized.toDouble();

    r = r * exposureMul;
    g = g * exposureMul;
    b = b * exposureMul;

    r = r * p.contrast + contrastOffset;
    g = g * p.contrast + contrastOffset;
    b = b * p.contrast + contrastOffset;

    final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    r = luma + p.saturation * (r - luma);
    g = luma + p.saturation * (g - luma);
    b = luma + p.saturation * (b - luma);

    r *= rBalance;
    g *= gBalance;
    b *= bBalance;

    final zoneLuma = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
    final shadowMask = (1 - zoneLuma) * (1 - zoneLuma);
    final highlightMask = zoneLuma * zoneLuma;
    final toneOffset =
        p.shadows * 0.16 * shadowMask + p.highlights * 0.16 * highlightMask;
    r += toneOffset;
    g += toneOffset;
    b += toneOffset;

    r = pow(r.clamp(0.0, 1.0), redGamma).toDouble();
    g = pow(g.clamp(0.0, 1.0), greenGamma).toDouble();
    b = pow(b.clamp(0.0, 1.0), blueGamma).toDouble();

    pixel
      ..r = (r.clamp(0.0, 1.0) * 255).round()
      ..g = (g.clamp(0.0, 1.0) * 255).round()
      ..b = (b.clamp(0.0, 1.0) * 255).round();
  }
}

class _ModeConfig {
  const _ModeConfig({
    required this.rounds,
    required this.stepScale,
    required this.maxBrightness,
    required this.maxExposure,
    required this.minContrast,
    required this.maxContrast,
    required this.minSaturation,
    required this.maxSaturation,
    required this.maxColorBalance,
    required this.matchToneZones,
    required this.matchRgbCurves,
    required this.maxToneZone,
    required this.maxRgbCurve,
  });

  final int rounds;
  final double stepScale;
  final double maxBrightness;
  final double maxExposure;
  final double minContrast;
  final double maxContrast;
  final double minSaturation;
  final double maxSaturation;
  final double maxColorBalance;
  final bool matchToneZones;
  final bool matchRgbCurves;
  final double maxToneZone;
  final double maxRgbCurve;

  static _ModeConfig forMode(ColorMatchMode mode) {
    return switch (mode) {
      ColorMatchMode.natural => const _ModeConfig(
        rounds: 4,
        stepScale: 0.7,
        maxBrightness: 0.10,
        maxExposure: 0.45,
        minContrast: 0.85,
        maxContrast: 1.20,
        minSaturation: 0.80,
        maxSaturation: 1.25,
        maxColorBalance: 0.55,
        matchToneZones: false,
        matchRgbCurves: false,
        maxToneZone: 0,
        maxRgbCurve: 0,
      ),
      ColorMatchMode.standard => const _ModeConfig(
        rounds: 6,
        stepScale: 1.0,
        maxBrightness: 0.16,
        maxExposure: 0.80,
        minContrast: 0.75,
        maxContrast: 1.35,
        minSaturation: 0.65,
        maxSaturation: 1.45,
        maxColorBalance: 1.0,
        matchToneZones: true,
        matchRgbCurves: false,
        maxToneZone: 0.65,
        maxRgbCurve: 0,
      ),
      ColorMatchMode.strong => const _ModeConfig(
        rounds: 8,
        stepScale: 1.45,
        maxBrightness: 0.24,
        maxExposure: 1.0,
        minContrast: 0.70,
        maxContrast: 1.40,
        minSaturation: 0.50,
        maxSaturation: 1.60,
        maxColorBalance: 1.0,
        matchToneZones: true,
        matchRgbCurves: true,
        maxToneZone: 1.0,
        maxRgbCurve: 1.0,
      ),
    };
  }
}

class _ImageStats {
  const _ImageStats({
    required this.meanLuma,
    required this.stdLuma,
    required this.meanSaturation,
    required this.redBlueBalance,
    required this.greenBalance,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.shadowLuma,
    required this.highlightLuma,
  });

  final double meanLuma;
  final double stdLuma;
  final double meanSaturation;
  final double redBlueBalance;
  final double greenBalance;
  final double meanR;
  final double meanG;
  final double meanB;
  final double shadowLuma;
  final double highlightLuma;

  factory _ImageStats.fromImage(img.Image image) {
    var sumR = 0.0;
    var sumG = 0.0;
    var sumB = 0.0;
    var sumLuma = 0.0;
    var sumLumaSquared = 0.0;
    var sumSaturation = 0.0;
    var sumShadowLuma = 0.0;
    var sumHighlightLuma = 0.0;
    var shadowCount = 0;
    var highlightCount = 0;
    var count = 0;

    for (final pixel in image) {
      final r = pixel.rNormalized.toDouble();
      final g = pixel.gNormalized.toDouble();
      final b = pixel.bNormalized.toDouble();
      final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final maxChannel = max(r, max(g, b));
      final minChannel = min(r, min(g, b));
      final saturation = maxChannel <= 0
          ? 0.0
          : (maxChannel - minChannel) / maxChannel;

      sumR += r;
      sumG += g;
      sumB += b;
      sumLuma += luma;
      sumLumaSquared += luma * luma;
      sumSaturation += saturation;
      if (luma < 0.35) {
        sumShadowLuma += luma;
        shadowCount += 1;
      }
      if (luma > 0.65) {
        sumHighlightLuma += luma;
        highlightCount += 1;
      }
      count += 1;
    }

    final safeCount = max(count, 1);
    final meanR = sumR / safeCount;
    final meanG = sumG / safeCount;
    final meanB = sumB / safeCount;
    final meanLuma = sumLuma / safeCount;
    final variance = max(0.0, sumLumaSquared / safeCount - meanLuma * meanLuma);

    return _ImageStats(
      meanLuma: meanLuma,
      stdLuma: sqrt(variance),
      meanSaturation: sumSaturation / safeCount,
      redBlueBalance: meanR - meanB,
      greenBalance: meanG - (meanR + meanB) * 0.5,
      meanR: meanR,
      meanG: meanG,
      meanB: meanB,
      shadowLuma: shadowCount == 0 ? meanLuma : sumShadowLuma / shadowCount,
      highlightLuma: highlightCount == 0
          ? meanLuma
          : sumHighlightLuma / highlightCount,
    );
  }
}
