import 'package:flutter/material.dart';

double normalizedMapMarkerScale(double scale) => scale.clamp(0.6, 1.2);

double scaledMapMarkerDimension(double dimension, double scale) {
  return dimension * normalizedMapMarkerScale(scale);
}

class ScaledMapMarker extends StatelessWidget {
  const ScaledMapMarker({
    required this.baseWidth,
    required this.baseHeight,
    required this.scale,
    required this.child,
    super.key,
  });

  final double baseWidth;
  final double baseHeight;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: scaledMapMarkerDimension(baseWidth, scale),
      height: scaledMapMarkerDimension(baseHeight, scale),
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: baseWidth, height: baseHeight, child: child),
      ),
    );
  }
}
