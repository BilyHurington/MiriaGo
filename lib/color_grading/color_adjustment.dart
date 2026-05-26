import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'color_grading_params.dart';

Future<Uint8List> applyColorGrading({
  required Uint8List imageBytes,
  required ColorGradingParams params,
  int? maxLongSide,
}) async {
  final image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes;

  if (maxLongSide != null && image.width > maxLongSide && image.height > maxLongSide) {
    final scale = maxLongSide / max(image.width, image.height);
    final small = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
    _adjust(small, params);
    return img.encodeJpg(small, quality: 92);
  }

  _adjust(image, params);
  return img.encodeJpg(image, quality: 94);
}

void _adjust(img.Image image, ColorGradingParams params) {
  final p = params;
  for (var y = 0; y < image.height; y += 1) {
    for (var x = 0; x < image.width; x += 1) {
      final pixel = image.getPixel(x, y);
      double r = pixel.r / 255.0;
      double g = pixel.g / 255.0;
      double b = pixel.b / 255.0;

      // Exposure
      final expMul = pow(2.0, p.exposure);
      r *= expMul;
      g *= expMul;
      b *= expMul;

      // Contrast
      r = (r - 0.5) * p.contrast + 0.5;
      g = (g - 0.5) * p.contrast + 0.5;
      b = (b - 0.5) * p.contrast + 0.5;

      // Gamma
      final invGamma = 1.0 / max(p.gamma, 0.01);
      r = pow(max(r, 0.0), invGamma).toDouble();
      g = pow(max(g, 0.0), invGamma).toDouble();
      b = pow(max(b, 0.0), invGamma).toDouble();

      // Saturation
      final yLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      r = yLuma + p.saturation * (r - yLuma);
      g = yLuma + p.saturation * (g - yLuma);
      b = yLuma + p.saturation * (b - yLuma);

      // Temperature (warm/cool)
      r *= 1.0 + 0.10 * p.temperature;
      b *= 1.0 - 0.10 * p.temperature;

      // Tint (green/magenta)
      r *= 1.0 - 0.04 * p.tint;
      g *= 1.0 + 0.08 * p.tint;
      b *= 1.0 - 0.04 * p.tint;

      // Tone curve
      r = p.toneCurve.map(r.clamp(0.0, 1.0));
      g = p.toneCurve.map(g.clamp(0.0, 1.0));
      b = p.toneCurve.map(b.clamp(0.0, 1.0));

      // Clamp and write
      image.setPixelRgba(
        x,
        y,
        (r.clamp(0.0, 1.0) * 255).round(),
        (g.clamp(0.0, 1.0) * 255).round(),
        (b.clamp(0.0, 1.0) * 255).round(),
        pixel.a,
      );
    }
  }
}
