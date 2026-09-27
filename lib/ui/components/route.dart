import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../plan/pilgrimage_models.dart' show VisitStatus;
import '../design/theme.dart';

export '../../plan/pilgrimage_models.dart' show VisitStatus;

/// Path of the four-point ✦ sparkle centred in a square of [size].
Path sparklePath(Offset center, double size) {
  final r = size / 2;
  final waist = r * 0.28;
  return Path()
    ..moveTo(center.dx, center.dy - r)
    ..quadraticBezierTo(
      center.dx + waist * 0.35,
      center.dy - waist * 0.35,
      center.dx + r,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + waist * 0.35,
      center.dy + waist * 0.35,
      center.dx,
      center.dy + r,
    )
    ..quadraticBezierTo(
      center.dx - waist * 0.35,
      center.dy + waist * 0.35,
      center.dx - r,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - waist * 0.35,
      center.dy - waist * 0.35,
      center.dx,
      center.dy - r,
    )
    ..close();
}

/// The ✦ sparkle glyph drawn as a vector (crisp at any size, independent
/// of fonts). Defaults to the spot colour.
class Sparkle extends StatelessWidget {
  const Sparkle({this.size = 14, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SparklePainter(color ?? context.colors.spot),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      sparklePath(size.center(Offset.zero), size.shortestSide),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Paints one route node (pending hollow dot / current ✦ / completed
/// check) centred at [center].
void paintRouteNode(
  Canvas canvas,
  Offset center,
  VisitStatus status,
  MiriaColors c, {
  double size = 18,
}) {
  final r = size / 2;
  switch (status) {
    case VisitStatus.pending:
      canvas
        ..drawCircle(center, r - 2, Paint()..color = c.surface)
        ..drawCircle(
          center,
          r - 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c.hairlineStrong,
        );
    case VisitStatus.current:
      canvas
        ..drawCircle(center, r + 2, Paint()..color = c.spotContainer)
        ..drawPath(sparklePath(center, size + 2), Paint()..color = c.spot)
        ..drawPath(
          sparklePath(center, size + 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = c.onSpot.withValues(alpha: 0.25),
        );
    case VisitStatus.completed:
      canvas.drawCircle(center, r, Paint()..color = c.primary);
      final check = Path()
        ..moveTo(center.dx - r * 0.45, center.dy + r * 0.02)
        ..lineTo(center.dx - r * 0.1, center.dy + r * 0.36)
        ..lineTo(center.dx + r * 0.48, center.dy - r * 0.32);
      canvas.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = c.onPrimary,
      );
  }
}

/// The signature route connector for list rows (DESIGN §6.1): a thin
/// vertical line through every row with one node per point — pending
/// hollow, current ✦ in spot yellow, completed primary check.
///
/// Give it to `ListRow(routeLine: ...)`, or place it in any row with a
/// bounded height. The line above the node is omitted for [isFirst], the
/// line below for [isLast]. Segments leading into completed points are
/// primary tinted.
///
/// ```dart
/// RouteLine(status: VisitStatus.current, isFirst: i == 0, isLast: i == last)
/// ```
class RouteLine extends StatelessWidget {
  const RouteLine({
    required this.status,
    this.isFirst = false,
    this.isLast = false,
    this.previousCompleted = false,
    this.nodeY,
    this.width = 28,
    this.nodeSize = 18,
    super.key,
  });

  final VisitStatus status;
  final bool isFirst;
  final bool isLast;

  /// Tint the upper segment (the previous point is completed too).
  final bool previousCompleted;

  /// Node centre from the top; null centres it vertically.
  final double? nodeY;
  final double width;
  final double nodeSize;

  static String semanticsFor(VisitStatus status) => switch (status) {
    VisitStatus.pending => '待访问',
    VisitStatus.current => '当前目标',
    VisitStatus.completed => '已完成',
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, nodeSize + 8),
        painter: _RouteLinePainter(
          colors: context.colors,
          status: status,
          isFirst: isFirst,
          isLast: isLast,
          previousCompleted: previousCompleted,
          nodeY: nodeY,
          nodeSize: nodeSize,
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  _RouteLinePainter({
    required this.colors,
    required this.status,
    required this.isFirst,
    required this.isLast,
    required this.previousCompleted,
    required this.nodeY,
    required this.nodeSize,
  });

  final MiriaColors colors;
  final VisitStatus status;
  final bool isFirst;
  final bool isLast;
  final bool previousCompleted;
  final double? nodeY;
  final double nodeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final y = (nodeY ?? size.height / 2).clamp(0.0, size.height);
    final gap = nodeSize / 2 + 3;
    final base = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = colors.hairlineStrong;
    final done = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = colors.primary.withValues(alpha: 0.55);
    if (!isFirst && y - gap > 0) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, y - gap),
        status == VisitStatus.completed && previousCompleted ? done : base,
      );
    }
    if (!isLast && y + gap < size.height) {
      canvas.drawLine(Offset(x, y + gap), Offset(x, size.height), base);
    }
    paintRouteNode(canvas, Offset(x, y), status, colors, size: nodeSize);
  }

  @override
  bool shouldRepaint(_RouteLinePainter old) =>
      old.colors != colors ||
      old.status != status ||
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.previousCompleted != previousCompleted ||
      old.nodeY != nodeY ||
      old.nodeSize != nodeSize;
}

/// Group progress as a row of small dots (DESIGN §6.1): completed filled
/// primary, current ✦ spot, pending hollow. Collapses to 「x/y」 when there
/// are more than [maxDots] points or they do not fit the width.
///
/// ```dart
/// RouteDots(statuses: [for (final p in group.points) p.status])
/// RouteDots.counts(completed: 3, total: 8, hasCurrent: true)
/// ```
class RouteDots extends StatelessWidget {
  const RouteDots({
    required this.statuses,
    this.maxDots = 12,
    this.dotSize = 8,
    this.spacing = 4,
    super.key,
  });

  /// Dots from counts: completed first, then the current one, then pending.
  RouteDots.counts({
    required int completed,
    required int total,
    bool hasCurrent = false,
    this.maxDots = 12,
    this.dotSize = 8,
    this.spacing = 4,
    super.key,
  }) : statuses = [
         for (var i = 0; i < total; i++)
           i < completed
               ? VisitStatus.completed
               : (hasCurrent && i == completed)
               ? VisitStatus.current
               : VisitStatus.pending,
       ];

  final List<VisitStatus> statuses;
  final int maxDots;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final completed = statuses.where((s) => s == VisitStatus.completed).length;
    final total = statuses.length;
    final semantics = '已完成 $completed/$total';
    final label = _CountLabel(completed: completed, total: total);
    if (total == 0) return Semantics(label: semantics, child: label);
    if (total > maxDots) {
      return Semantics(label: semantics, excludeSemantics: true, child: label);
    }
    final needed = total * dotSize + (total - 1) * spacing + 4;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite && constraints.maxWidth < needed) {
            return label;
          }
          return CustomPaint(
            size: Size(needed, dotSize + 4),
            painter: _DotsPainter(
              colors: context.colors,
              statuses: statuses,
              dotSize: dotSize,
              spacing: spacing,
            ),
          );
        },
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      '$completed/$total',
      style: context.text.labelMedium?.copyWith(
        color: completed == total && total > 0
            ? c.primaryText
            : c.textSecondary,
        fontFeatures: MiriaFonts.tabular,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.colors,
    required this.statuses,
    required this.dotSize,
    required this.spacing,
  });

  final MiriaColors colors;
  final List<VisitStatus> statuses;
  final double dotSize;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final r = dotSize / 2;
    final y = size.height / 2;
    for (var i = 0; i < statuses.length; i++) {
      final center = Offset(2 + r + i * (dotSize + spacing), y);
      switch (statuses[i]) {
        case VisitStatus.completed:
          canvas.drawCircle(center, r, Paint()..color = colors.primary);
        case VisitStatus.current:
          canvas.drawPath(
            sparklePath(center, dotSize + 4),
            Paint()..color = colors.spot,
          );
        case VisitStatus.pending:
          canvas.drawCircle(
            center,
            r - 0.75,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = colors.hairlineStrong,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.colors != colors ||
      old.dotSize != dotSize ||
      old.spacing != spacing ||
      !_listEquals(old.statuses, statuses);

  static bool _listEquals(List<VisitStatus> a, List<VisitStatus> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Brand motif: a gentle route line with three stops (pending, current ✦,
/// completed). Used by [EmptyState] and image placeholders (DESIGN §6.7).
class RouteMotif extends StatelessWidget {
  const RouteMotif({this.width = 120, this.height = 44, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _MotifPainter(context.colors),
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  _MotifPainter(this.colors);
  final MiriaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final points = [
      Offset(w * 0.08, h * 0.70),
      Offset(w * 0.38, h * 0.30),
      Offset(w * 0.64, h * 0.66),
      Offset(w * 0.92, h * 0.28),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final next = points[i];
      final mid = (prev.dx + next.dx) / 2;
      path.cubicTo(mid, prev.dy, mid, next.dy, next.dx, next.dy);
    }
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = colors.primary.withValues(alpha: 0.35);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 7, metric.length)),
          dash,
        );
        d += 12;
      }
    }
    final dot = math.min(14.0, h * 0.34);
    paintRouteNode(canvas, points[0], VisitStatus.completed, colors, size: dot);
    paintRouteNode(canvas, points[1], VisitStatus.completed, colors, size: dot);
    paintRouteNode(canvas, points[2], VisitStatus.current, colors, size: dot);
    paintRouteNode(canvas, points[3], VisitStatus.pending, colors, size: dot);
  }

  @override
  bool shouldRepaint(_MotifPainter old) => old.colors != colors;
}
