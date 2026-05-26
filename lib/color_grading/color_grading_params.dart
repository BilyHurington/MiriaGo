import 'dart:math';
import 'dart:ui';

class ToneCurve {
  ToneCurve({required this.points});

  ToneCurve.identity()
      : points = [
          const Offset(0.0, 0.0),
          const Offset(0.25, 0.25),
          const Offset(0.5, 0.5),
          const Offset(0.75, 0.75),
          const Offset(1.0, 1.0),
        ];

  final List<Offset> points;

  ToneCurve copyWith({List<Offset>? points}) {
    return ToneCurve(points: points ?? this.points);
  }

  Map<String, dynamic> toJson() => {
        'points': points
            .map((p) => {'x': p.dx, 'y': p.dy})
            .toList(growable: false),
      };

  factory ToneCurve.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
        .toList(growable: false);
    return ToneCurve(points: pts);
  }

  double map(double t) {
    final pts = points;
    final clamped = t.clamp(0.0, 1.0);
    if (clamped <= pts.first.dx) return pts.first.dy;
    if (clamped >= pts.last.dx) return pts.last.dy;

    for (var i = 0; i < pts.length - 1; i += 1) {
      if (clamped >= pts[i].dx && clamped <= pts[i + 1].dx) {
        final range = pts[i + 1].dx - pts[i].dx;
        final local = range > 0 ? (clamped - pts[i].dx) / range : 0.0;
        final t2 = local * local;
        final t3 = t2 * local;
        final m0 = _slope(i);
        final m1 = _slope(i + 1);
        final p0 = pts[i].dy;
        final p1 = pts[i + 1].dy;
        final result = (2 * t3 - 3 * t2 + 1) * p0 +
            (t3 - 2 * t2 + local) * range * m0 +
            (-2 * t3 + 3 * t2) * p1 +
            (t3 - t2) * range * m1;
        return result.clamp(0.0, 1.0);
      }
    }
    return pts.last.dy;
  }

  double _slope(int i) {
    final pts = points;
    if (i == 0) return (pts[1].dy - pts[0].dy) / max(pts[1].dx - pts[0].dx, 0.001);
    if (i == pts.length - 1) {
      return (pts[i].dy - pts[i - 1].dy) /
          max(pts[i].dx - pts[i - 1].dx, 0.001);
    }
    return (pts[i + 1].dy - pts[i - 1].dy) /
        max(pts[i + 1].dx - pts[i - 1].dx, 0.001);
  }
}

class ColorGradingParams {
  ColorGradingParams({
    this.exposure = 0.0,
    this.contrast = 1.0,
    this.gamma = 1.0,
    this.saturation = 1.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    ToneCurve? toneCurve,
  }) : toneCurve = toneCurve ?? ToneCurve.identity();

  final double exposure;
  final double contrast;
  final double gamma;
  final double saturation;
  final double temperature;
  final double tint;
  final ToneCurve toneCurve;

  static final defaults = ColorGradingParams();

  ColorGradingParams copyWith({
    double? exposure,
    double? contrast,
    double? gamma,
    double? saturation,
    double? temperature,
    double? tint,
    ToneCurve? toneCurve,
  }) {
    return ColorGradingParams(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
      saturation: saturation ?? this.saturation,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      toneCurve: toneCurve ?? this.toneCurve,
    );
  }

  Map<String, dynamic> toJson() => {
        'exposure': exposure,
        'contrast': contrast,
        'gamma': gamma,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        'toneCurve': toneCurve.toJson(),
      };

  factory ColorGradingParams.fromJson(Map<String, dynamic> json) {
    return ColorGradingParams(
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      gamma: (json['gamma'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0.0,
      toneCurve: json['toneCurve'] != null
          ? ToneCurve.fromJson(json['toneCurve'] as Map<String, dynamic>)
          : ToneCurve.identity(),
    );
  }
}
