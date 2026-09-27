import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_symbols_icons/symbols.dart';

import '../../data/anitabi_image_source_scope.dart';
import '../../map/map_marker_scale.dart';
import '../../plan/pilgrimage_models.dart';
import '../../widgets/image_load_limiter.dart';
import '../../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../../widgets/reference_thumbnail_io.dart';
import '../design/theme.dart';

/// White contrast ring around map markers. Map chrome sits on arbitrary
/// tiles, so the ring is white in both themes (map data exception to the
/// "token colours only" rule).
const Color kMapMarkerRing = Color(0xFFFFFFFF);

/// What a point marker represents.
enum PointMarkerKind {
  /// Plan point still to visit: cream circle, primary ring, place icon.
  pending,

  /// The plan's current target: sunflower star ✦ with a slow pulse.
  current,

  /// Visited: primary filled circle with a check, 80% size.
  completed,

  /// Anitabi candidate already in the plan (「已导入点位」).
  imported,

  /// Anitabi candidate that can be imported (「可导入点位」).
  importable,
}

/// Maps the plan runtime status to a marker kind.
PointMarkerKind pointMarkerKindFor(VisitStatus status) => switch (status) {
  VisitStatus.pending => PointMarkerKind.pending,
  VisitStatus.current => PointMarkerKind.current,
  VisitStatus.completed => PointMarkerKind.completed,
};

/// Builds a flutter_map [Marker] whose child is laid out at [baseSize] and
/// scaled by the user's marker scale setting ([scale], see
/// `AppSettings.mapMarkerScale`).
Marker scaledMapMarker({
  required LatLng point,
  required Size baseSize,
  required double scale,
  required Widget child,
  Alignment alignment = Alignment.center,
  Key? key,
}) {
  return Marker(
    key: key,
    point: point,
    width: scaledMapMarkerDimension(baseSize.width, scale),
    height: scaledMapMarkerDimension(baseSize.height, scale),
    alignment: alignment,
    child: ScaledMapMarker(
      baseWidth: baseSize.width,
      baseHeight: baseSize.height,
      scale: scale,
      child: child,
    ),
  );
}

/// Marker [Alignment] that puts the local point ([anchorY] from the top of a
/// box [height] tall, horizontally centred) on the marker's coordinate.
Alignment markerAnchorAlignment({
  required double anchorY,
  required double height,
}) => Alignment(0, 1 - 2 * anchorY / height);

/// Keeps marker text readable without breaking fixed marker boxes.
Widget _clampText(BuildContext context, Widget child) =>
    MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, child: child);

List<BoxShadow> _markerShadow(MiriaColors c) => [
  BoxShadow(
    color: c.shadow.withValues(alpha: c.isDark ? 0.45 : 0.22),
    blurRadius: 5,
    offset: const Offset(0, 2),
  ),
];

// ---------------------------------------------------------------------------
// PointMarker
// ---------------------------------------------------------------------------

/// Status marker for a single point (DESIGN §6.8).
///
/// Unselected the marker is a 44×44 box centred on the coordinate; selected
/// it grows 1.2× and shows [label] below. Use [PointMarker.sizeFor] and
/// [PointMarker.alignmentFor] when building the flutter_map [Marker] (or
/// [PointMarker.marker]).
class PointMarker extends StatelessWidget {
  const PointMarker({
    required this.kind,
    this.selected = false,
    this.label,
    this.color,
    this.tooltip,
    this.onTap,
    super.key,
  });

  final PointMarkerKind kind;
  final bool selected;

  /// Point name shown below the marker while [selected].
  final String? label;

  /// Ring / accent colour for pending and importable markers (e.g. a group
  /// colour). Defaults to the primary colour.
  final Color? color;

  /// Hover tooltip. Defaults to the name, then the kind's text.
  final String? tooltip;
  final VoidCallback? onTap;

  static const double _box = 44;
  static const double _labelExtent = 30;
  static const double _labelWidth = 156;

  static Size sizeFor({required bool selected, bool hasLabel = true}) =>
      selected && hasLabel
      ? const Size(_labelWidth, _box + _labelExtent)
      : const Size(_box, _box);

  static Alignment alignmentFor({
    required bool selected,
    bool hasLabel = true,
  }) {
    final size = sizeFor(selected: selected, hasLabel: hasLabel);
    return markerAnchorAlignment(anchorY: _box / 2, height: size.height);
  }

  /// Convenience: a scaled flutter_map [Marker] for this widget.
  static Marker marker({
    required LatLng point,
    required PointMarker child,
    required double scale,
    Key? key,
  }) {
    final hasLabel = (child.label ?? '').trim().isNotEmpty;
    return scaledMapMarker(
      key: key,
      point: point,
      baseSize: sizeFor(selected: child.selected, hasLabel: hasLabel),
      alignment: alignmentFor(selected: child.selected, hasLabel: hasLabel),
      scale: scale,
      child: child,
    );
  }

  String get _defaultTooltip => switch (kind) {
    PointMarkerKind.imported => '已导入点位',
    PointMarkerKind.importable => '可导入点位',
    _ => '巡礼点',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = label?.trim() ?? '';
    final showLabel = selected && name.isNotEmpty;
    final message = tooltip ?? (name.isNotEmpty ? name : _defaultTooltip);
    final reduced = Motion.reduced(context);

    final Widget symbol = switch (kind) {
      PointMarkerKind.current => _CurrentStar(color: c.spot, ring: c.onSpot),
      PointMarkerKind.completed => Opacity(
        opacity: 0.88,
        child: _Disc(
          diameter: 24,
          fill: c.primary,
          ring: kMapMarkerRing,
          ringWidth: 2,
          shadow: _markerShadow(c),
          child: Icon(
            Symbols.check_rounded,
            size: 16,
            weight: 700,
            color: c.onPrimary,
          ),
        ),
      ),
      PointMarkerKind.pending => _Disc(
        diameter: 30,
        fill: c.isDark ? c.surface : c.canvas,
        ring: color ?? c.primary,
        ringWidth: 2.5,
        shadow: _markerShadow(c),
        child: Icon(
          Symbols.place_rounded,
          size: 17,
          fill: 1,
          color: color ?? c.primaryText,
        ),
      ),
      PointMarkerKind.imported => _Disc(
        diameter: 28,
        fill: c.surfaceMuted,
        ring: c.hairlineStrong,
        ringWidth: 1.5,
        shadow: _markerShadow(c),
        child: Icon(
          Symbols.check_rounded,
          size: 16,
          weight: 600,
          color: c.textSecondary,
        ),
      ),
      PointMarkerKind.importable => _Disc(
        diameter: 30,
        fill: c.surface,
        ring: color ?? c.primary,
        ringWidth: 2,
        shadow: _markerShadow(c),
        child: Icon(
          Symbols.location_on_rounded,
          size: 18,
          fill: 1,
          color: color ?? c.primaryText,
        ),
      ),
    };

    final circle = SizedBox(
      width: _box,
      height: _box,
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1.2 : 1,
          duration: reduced ? Duration.zero : Motion.standard,
          curve: Motion.emphasized,
          child: symbol,
        ),
      ),
    );

    return _clampText(
      context,
      Semantics(
        button: onTap != null,
        selected: selected,
        label: message,
        child: Tooltip(
          message: message,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                circle,
                if (showLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: MapNameLabel(text: name, maxWidth: _labelWidth),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small name pill used under selected markers.
class MapNameLabel extends StatelessWidget {
  const MapNameLabel({required this.text, this.maxWidth = 156, super.key});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.pillAll,
          border: Border.all(color: c.hairline),
          boxShadow: Elevations.level1(c),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            locale: MiriaFonts.japanese,
            style: context.text.labelSmall?.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({
    required this.diameter,
    required this.fill,
    required this.ring,
    required this.ringWidth,
    required this.shadow,
    required this.child,
  });

  final double diameter;
  final Color fill;
  final Color ring;
  final double ringWidth;
  final List<BoxShadow> shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// Four-point sunflower star with a slow pulsing halo.
class _CurrentStar extends StatefulWidget {
  const _CurrentStar({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  State<_CurrentStar> createState() => _CurrentStarState();
}

class _CurrentStarState extends State<_CurrentStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 0.35;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: 22 + 22 * t,
                height: 22 + 22 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                ),
              );
            },
          ),
          CustomPaint(
            size: const Size(34, 34),
            painter: _StarPainter(
              fill: widget.color,
              ring: kMapMarkerRing,
              shadow: context.colors.shadow,
              dark: context.colors.isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.fill,
    required this.ring,
    required this.shadow,
    required this.dark,
  });

  final Color fill;
  final Color ring;
  final Color shadow;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 1.5;
    final inner = outer * 0.42;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawShadow(
      path,
      shadow.withValues(alpha: dark ? 0.6 : 0.35),
      2.5,
      false,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.fill != fill || old.ring != ring || old.shadow != shadow;
}

// ---------------------------------------------------------------------------
// ThumbnailMarker
// ---------------------------------------------------------------------------

/// Reference image for a [ThumbnailMarker].
@immutable
class MarkerImage {
  const MarkerImage({this.localPath, this.imageUrl});

  final String? localPath;
  final String? imageUrl;

  bool get isEmpty =>
      (localPath == null || localPath!.isEmpty) &&
      (imageUrl == null || imageUrl!.isEmpty);
}

/// Thumbnail-mode marker: a rounded 12 reference image card with a status
/// colour bar and a pin tail. With [showImage] false it is a small status
/// dot (used for points beyond the thumbnail threshold).
class ThumbnailMarker extends StatelessWidget {
  const ThumbnailMarker({
    required this.kind,
    this.image,
    this.showImage = true,
    this.selected = false,
    this.color,
    this.loadLimiter,
    this.tooltip,
    this.onTap,
    super.key,
  });

  final PointMarkerKind kind;
  final MarkerImage? image;
  final bool showImage;
  final bool selected;

  /// Status colour for pending / importable points (e.g. group colour).
  final Color? color;
  final ImageLoadLimiter? loadLimiter;
  final String? tooltip;
  final VoidCallback? onTap;

  static const Size imageSize = Size(84, 82);
  static const Size dotSize = Size(24, 24);
  static const double _dot = 14;

  static Size sizeFor({required bool showImage}) =>
      showImage ? imageSize : dotSize;

  static Alignment alignmentFor({required bool showImage}) => showImage
      ? markerAnchorAlignment(
          anchorY: imageSize.height - _dot / 2,
          height: imageSize.height,
        )
      : Alignment.center;

  static Marker marker({
    required LatLng point,
    required ThumbnailMarker child,
    required double scale,
    Key? key,
  }) => scaledMapMarker(
    key: key,
    point: point,
    baseSize: sizeFor(showImage: child.showImage),
    alignment: alignmentFor(showImage: child.showImage),
    scale: scale,
    child: child,
  );

  /// Status colour of the bar, tail dot and plain dot.
  static Color statusColor(
    MiriaColors c,
    PointMarkerKind kind, {
    Color? accent,
  }) => switch (kind) {
    PointMarkerKind.current => c.spot,
    PointMarkerKind.completed => c.textTertiary,
    PointMarkerKind.imported => c.textTertiary,
    PointMarkerKind.pending ||
    PointMarkerKind.importable => accent ?? c.primary,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = statusColor(c, kind, accent: color);
    final message =
        tooltip ??
        switch (kind) {
          PointMarkerKind.imported => '已导入点位',
          PointMarkerKind.importable => '可导入点位',
          _ => '巡礼点',
        };

    Widget content;
    if (!showImage) {
      content = SizedBox.fromSize(
        size: dotSize,
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: status,
              shape: BoxShape.circle,
              border: Border.all(color: kMapMarkerRing, width: 2),
              boxShadow: _markerShadow(c),
            ),
          ),
        ),
      );
    } else {
      final reduced = Motion.reduced(context);
      final cardWidth = selected ? 78.0 : 66.0;
      final cardHeight = selected ? 60.0 : 50.0;
      content = SizedBox.fromSize(
        size: imageSize,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: _dot + 4,
              child: CustomPaint(
                size: const Size(16, 10),
                painter: _TailPainter(color: kMapMarkerRing),
              ),
            ),
            Positioned(
              bottom: _dot + 12,
              child: AnimatedContainer(
                duration: reduced ? Duration.zero : Motion.standard,
                curve: Motion.emphasized,
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: kMapMarkerRing,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: selected ? Border.all(color: status, width: 2) : null,
                  boxShadow: _markerShadow(c),
                ),
                padding: EdgeInsets.all(selected ? 1.5 : 2),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ThumbnailImage(
                          image: image,
                          kind: kind,
                          loadLimiter: loadLimiter,
                          accent: status,
                        ),
                      ),
                      Container(height: 4, color: status),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: status,
                  shape: BoxShape.circle,
                  border: Border.all(color: kMapMarkerRing, width: 2),
                  boxShadow: _markerShadow(c),
                ),
              ),
            ),
          ],
        ),
      );
      if (kind == PointMarkerKind.completed ||
          kind == PointMarkerKind.imported) {
        content = Opacity(opacity: 0.85, child: content);
      }
    }

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: message,
      child: Tooltip(
        message: message,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.image,
    required this.kind,
    required this.loadLimiter,
    required this.accent,
  });

  final MarkerImage? image;
  final PointMarkerKind kind;
  final ImageLoadLimiter? loadLimiter;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done =
        kind == PointMarkerKind.completed || kind == PointMarkerKind.imported;
    final placeholder = ColoredBox(
      color: c.isDark ? c.surfaceMuted : c.canvas,
      child: Center(
        child: Icon(
          done ? Symbols.check_rounded : Symbols.image_rounded,
          size: 20,
          color: done ? c.textSecondary : accent,
        ),
      ),
    );
    final image = this.image;
    if (image == null || image.isEmpty) return placeholder;
    return ColoredBox(
      color: c.surfaceMuted,
      child: ReferenceThumbnail(
        localPath: image.localPath,
        imageUrl: image.imageUrl,
        imageSource: AnitabiImageSourceScope.of(context),
        loadLimiter: loadLimiter,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        placeholder: placeholder,
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// ClusterMarker
// ---------------------------------------------------------------------------

/// Primary circle with the number of clustered points ("999+" cap).
///
/// [opensBrowser] is true at maximum zoom, where tapping browses the
/// overlapping points instead of zooming in.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    required this.count,
    this.onTap,
    this.opensBrowser = false,
    super.key,
  });

  final int count;
  final VoidCallback? onTap;
  final bool opensBrowser;

  static const Size size = Size(50, 50);

  static String labelFor(int count) => count > 999 ? '999+' : '$count';

  static Marker marker({
    required LatLng point,
    required ClusterMarker child,
    required double scale,
    Key? key,
  }) => scaledMapMarker(
    key: key,
    point: point,
    baseSize: size,
    scale: scale,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = labelFor(count);
    final actionLabel = opensBrowser ? '点击浏览' : '点击放大';
    return _clampText(
      context,
      Semantics(
        button: true,
        label: '$count 个聚合点位，$actionLabel',
        excludeSemantics: true,
        child: Tooltip(
          message: opensBrowser ? '浏览 $count 个重合点位' : '$count 个点位',
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: InkResponse(
                onTap: onTap,
                radius: 25,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primary,
                    border: Border.all(color: kMapMarkerRing, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.28),
                        spreadRadius: 4,
                      ),
                      ..._markerShadow(c),
                    ],
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: context.text.labelLarge?.copyWith(
                      color: c.onPrimary,
                      fontSize: label.length >= 4 ? 12 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: MiriaFonts.tabular,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnchorMarker
// ---------------------------------------------------------------------------

/// Group key point: a flag in the group's colour.
class AnchorMarker extends StatelessWidget {
  const AnchorMarker({
    required this.color,
    this.name,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final Color color;

  /// Group or key-point name, used as tooltip.
  final String? name;
  final bool selected;
  final VoidCallback? onTap;

  static const Size size = Size(38, 38);

  static Marker marker({
    required LatLng point,
    required AnchorMarker child,
    required double scale,
    Key? key,
  }) => scaledMapMarker(
    key: key,
    point: point,
    baseSize: size,
    scale: scale,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final message = (name ?? '').trim().isEmpty ? '关键点' : name!;
    return Semantics(
      button: onTap != null,
      label: '关键点 $message',
      excludeSemantics: true,
      child: Tooltip(
        message: message,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : c.surface,
                borderRadius: Radii.smAll,
                border: Border.all(
                  color: selected ? kMapMarkerRing : color,
                  width: 2,
                ),
                boxShadow: _markerShadow(c),
              ),
              child: Icon(
                Symbols.flag_rounded,
                size: 19,
                fill: 1,
                color: selected ? kMapMarkerRing : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LocationPuck
// ---------------------------------------------------------------------------

/// Current location: blue dot with a white border and a soft halo. Drawn at
/// 40% opacity when [stale] (location error / no recent fix). With
/// [headingTurns] (unwrapped turns, as `NavigationHeading` provides) a
/// heading cone points the way the phone faces.
class LocationPuck extends StatelessWidget {
  const LocationPuck({
    this.stale = false,
    this.headingTurns,
    this.tooltip,
    super.key,
  });

  final bool stale;
  final double? headingTurns;

  /// Defaults to 「当前位置」.
  final String? tooltip;

  static const Size size = Size(56, 56);

  static Marker marker({
    required LatLng point,
    required LocationPuck child,
    required double scale,
    Key? key,
  }) => scaledMapMarker(
    key: key,
    point: point,
    baseSize: size,
    scale: scale,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.info;
    final turns = headingTurns;
    final reduced = Motion.reduced(context);
    return Tooltip(
      message: tooltip ?? '当前位置',
      child: Semantics(
        label: stale
            ? '上次定位，等待更新'
            : turns == null
            ? '当前位置'
            : '当前位置，手机朝向',
        child: Opacity(
          opacity: stale ? 0.4 : 1,
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (turns != null && !stale)
                  AnimatedRotation(
                    key: const ValueKey('location-puck-heading'),
                    turns: turns,
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: CustomPaint(
                      size: size,
                      painter: _HeadingConePainter(color),
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.18),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: kMapMarkerRing, width: 3),
                    boxShadow: _markerShadow(c),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  const _HeadingConePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = RadialGradient(
      colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi * 0.7,
      math.pi * 0.4,
      true,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_HeadingConePainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Route stops
// ---------------------------------------------------------------------------

/// Numbered waypoint on a route.
class NumberedStopMarker extends StatelessWidget {
  const NumberedStopMarker({
    required this.number,
    this.color,
    this.dimmed = false,
    this.tooltip,
    super.key,
  });

  final int number;

  /// Defaults to the primary colour.
  final Color? color;

  /// Already-passed stops are drawn muted.
  final bool dimmed;
  final String? tooltip;

  static const Size size = Size(28, 28);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = dimmed ? c.textTertiary : (color ?? c.primary);
    final onFill = dimmed ? c.surface : c.onPrimary;
    Widget result = Center(
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: kMapMarkerRing, width: 2),
          boxShadow: _markerShadow(c),
        ),
        child: Text(
          '$number',
          maxLines: 1,
          style: context.text.labelSmall?.copyWith(
            color: onFill,
            fontSize: number >= 100 ? 8 : 11,
            fontWeight: FontWeight.w700,
            height: 1,
            fontFeatures: MiriaFonts.tabular,
          ),
        ),
      ),
    );
    if (tooltip != null) result = Tooltip(message: tooltip, child: result);
    return _clampText(context, Semantics(label: '途经点 $number', child: result));
  }
}

/// Route destination pin.
class DestinationMarker extends StatelessWidget {
  const DestinationMarker({this.tooltip, super.key});

  final String? tooltip;

  static const Size size = Size(36, 36);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip ?? '终点',
      child: Semantics(
        label: '终点',
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.danger,
              shape: BoxShape.circle,
              border: Border.all(color: kMapMarkerRing, width: 2.5),
              boxShadow: _markerShadow(c),
            ),
            child: const Icon(
              Symbols.location_on_rounded,
              size: 16,
              fill: 1,
              color: kMapMarkerRing,
            ),
          ),
        ),
      ),
    );
  }
}
