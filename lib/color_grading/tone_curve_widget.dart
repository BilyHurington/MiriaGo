import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'color_grading_params.dart';

class ToneCurveEditor extends StatefulWidget {
  const ToneCurveEditor({
    required this.curve,
    required this.onChanged,
    super.key,
  });

  final ToneCurve curve;
  final ValueChanged<ToneCurve> onChanged;

  @override
  State<ToneCurveEditor> createState() => _ToneCurveEditorState();
}

class _ToneCurveEditorState extends State<ToneCurveEditor> {
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onPanStart: (d) => _onDragStart(d.localPosition, size),
          onPanUpdate: (d) => _onDragUpdate(d.localPosition, size),
          onPanEnd: (_) => setState(() => _draggingIndex = null),
          child: CustomPaint(
            size: Size.square(size),
            painter: _CurvePainter(
              curve: widget.curve,
              draggingIndex: _draggingIndex,
            ),
          ),
        );
      },
    );
  }

  void _onDragStart(Offset pos, double size) {
    final curve = widget.curve;
    for (var i = 0; i < curve.points.length; i += 1) {
      final px = curve.points[i].dx * size;
      final py = (1.0 - curve.points[i].dy) * size;
      if ((pos - Offset(px, py)).distance < 24) {
        setState(() => _draggingIndex = i);
        return;
      }
    }
  }

  void _onDragUpdate(Offset pos, double size) {
    final i = _draggingIndex;
    if (i == null) return;

    final curve = widget.curve;
    final x = (pos.dx / size).clamp(0.0, 1.0);
    final y = (1.0 - pos.dy / size).clamp(0.0, 1.0);

    // Fixed endpoints
    if (i == 0 || i == curve.points.length - 1) return;

    // Keep points ordered
    final pts = [...curve.points];
    pts[i] = Offset(x, y);

    // Ensure monotonic x ordering
    if (x <= pts[i - 1].dx + 0.02 || x >= pts[i + 1].dx - 0.02) return;

    widget.onChanged(curve.copyWith(points: pts));
  }
}

class _CurvePainter extends CustomPainter {
  const _CurvePainter({required this.curve, required this.draggingIndex});

  final ToneCurve curve;
  final int? draggingIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF2A2A2E));

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF3A3A3E)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i += 1) {
      final t = i / 4;
      canvas.drawLine(Offset(t * w, 0), Offset(t * w, h), gridPaint);
      canvas.drawLine(Offset(0, t * h), Offset(w, t * h), gridPaint);
    }

    // Diagonal reference
    canvas.drawLine(
      Offset(0, h),
      Offset(w, 0),
      Paint()
        ..color = const Color(0xFF555555)
        ..strokeWidth = 1,
    );

    // Spline curve
    final path = ui.Path();
    path.moveTo(0, h);
    for (var i = 0; i <= 80; i += 1) {
      final t = i / 80.0;
      final y = curve.map(t);
      path.lineTo(t * w, (1.0 - y) * h);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Control points
    for (var i = 0; i < curve.points.length; i += 1) {
      final pt = curve.points[i];
      final cx = pt.dx * w;
      final cy = (1.0 - pt.dy) * h;
      final isDragging = i == draggingIndex;
      final isEndpoint = i == 0 || i == curve.points.length - 1;
      final radius = isDragging ? 10.0 : (isEndpoint ? 5.0 : 8.0);

      canvas.drawCircle(
        Offset(cx, cy),
        radius + 2,
        Paint()..color = isDragging ? Colors.white : const Color(0xFF333333),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..color = isDragging ? AppColors.accent : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
