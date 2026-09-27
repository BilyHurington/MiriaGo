import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import 'buttons.dart';
import 'route.dart';

/// Empty state: brand route motif, an icon, a title, a message and up to
/// two actions (DESIGN §6.9 "品牌图形 + 一句说明 + 一个主操作").
///
/// ```dart
/// EmptyState(
///   icon: Symbols.photo_library_rounded,
///   title: '还没有巡礼记录',
///   message: '在巡礼页拍摄后，记录会出现在这里。',
///   actionLabel: '去巡礼',
///   onAction: () => context.go(Routes.go),
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Smaller spacing for panels and list placeholders.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Space.x6,
          vertical: compact ? Space.x4 : Space.x8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 132,
                height: compact ? 72 : 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      child: RouteMotif(width: 132, height: compact ? 36 : 44),
                    ),
                    if (icon != null)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: compact ? 40 : 48,
                          height: compact ? 40 : 48,
                          decoration: BoxDecoration(
                            color: c.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.canvas, width: 3),
                          ),
                          child: Icon(
                            icon,
                            size: compact ? 20 : 24,
                            color: c.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? Space.x3 : Space.x4),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: compact ? text.titleMedium : text.titleLarge,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Space.x2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? Space.x4 : Space.x5),
                MiriaButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: Space.x2),
                MiriaButton.ghost(
                  label: secondaryActionLabel!,
                  onPressed: onSecondaryAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with the reason, how to fix it and a retry button.
///
/// ```dart
/// ErrorState(
///   title: '加载失败',
///   detail: '请检查网络后重试；已缓存的参考图仍可离线查看。',
///   onRetry: reload,
/// )
/// ```
class ErrorState extends StatelessWidget {
  const ErrorState({
    this.title = '加载失败',
    this.detail,
    this.onRetry,
    this.retryLabel = '重试',
    this.icon = Symbols.cloud_off_rounded,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Space.x6,
          vertical: compact ? Space.x4 : Space.x8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.dangerContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 26, color: c.danger),
                ),
                const SizedBox(height: Space.x4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: compact ? text.titleMedium : text.titleLarge,
                ),
                if (detail != null) ...[
                  const SizedBox(height: Space.x2),
                  Text(
                    detail!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: Space.x5),
                  MiriaButton.secondary(
                    label: retryLabel,
                    icon: Symbols.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SkeletonShape { box, line, circle }

/// Shimmering placeholder in the shape of the content being loaded
/// (DESIGN §6.6: skeletons, not spinners). All skeletons on screen shimmer
/// in sync; with reduced motion they are static.
///
/// ```dart
/// Row(children: [
///   Skeleton.circle(size: 40),
///   const SizedBox(width: 12),
///   Expanded(child: Column(children: [Skeleton.line(), Skeleton.line(widthFactor: 0.6)])),
/// ])
/// ```
class Skeleton extends StatefulWidget {
  /// Rectangle (images, cards).
  const Skeleton.box({
    this.width,
    this.height = 120,
    this.borderRadius = Radii.mdAll,
    super.key,
  }) : _shape = _SkeletonShape.box,
       widthFactor = null;

  /// Text line; [widthFactor] of the available width.
  const Skeleton.line({
    this.height = 12,
    this.widthFactor = 1,
    this.width,
    super.key,
  }) : _shape = _SkeletonShape.line,
       borderRadius = Radii.pillAll;

  /// Avatar / icon.
  const Skeleton.circle({double size = 40, super.key})
    : _shape = _SkeletonShape.circle,
      width = size,
      height = size,
      widthFactor = null,
      borderRadius = Radii.pillAll;

  final _SkeletonShape _shape;
  final double? width;
  final double height;
  final double? widthFactor;
  final BorderRadius borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  static const _period = 1400;
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !Motion.reduced(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.surfaceMuted;
    final highlight = c.isDark
        ? Color.lerp(c.surfaceMuted, c.textPrimary, 0.08)!
        : Color.lerp(c.surfaceMuted, c.surface, 0.75)!;
    final phase = _ticker.isActive
        ? (DateTime.now().millisecondsSinceEpoch % _period) / _period
        : null;
    final decoration = BoxDecoration(
      borderRadius: widget._shape == _SkeletonShape.circle
          ? null
          : widget.borderRadius,
      shape: widget._shape == _SkeletonShape.circle
          ? BoxShape.circle
          : BoxShape.rectangle,
      color: phase == null ? base : null,
      gradient: phase == null
          ? null
          : LinearGradient(
              begin: Alignment(-1 - 2 + phase * 4, -0.3),
              end: Alignment(1 - 2 + phase * 4, 0.3),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
    );
    Widget box = Container(
      width: widget.width,
      height: widget.height,
      decoration: decoration,
    );
    if (widget._shape == _SkeletonShape.line && widget.width == null) {
      box = FractionallySizedBox(
        widthFactor: widget.widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: box,
      );
    }
    if (widget._shape == _SkeletonShape.line) {
      box = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: box,
      );
    }
    return ExcludeSemantics(child: box);
  }
}

/// Circular progress ring with rounded ends; [value] null spins
/// (indeterminate). Value changes animate. Optional [child] in the centre
/// (e.g. 「12/27」).
///
/// ```dart
/// ProgressRing(value: done / total, size: 44, child: Text('$done'))
/// ```
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    this.value,
    this.size = 36,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.child,
    this.semanticLabel,
    super.key,
  });

  /// 0–1, or null for indeterminate.
  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.primary;
    final track = trackColor ?? c.surfaceMuted;
    final v = value;
    Widget ring;
    if (v == null) {
      ring = CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: fg,
        backgroundColor: track,
        strokeCap: StrokeCap.round,
      );
    } else {
      ring = TweenAnimationBuilder<double>(
        tween: Tween(end: v.clamp(0.0, 1.0)),
        duration: Motion.of(context, Motion.emphasis),
        curve: Motion.emphasized,
        builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: fg,
            track: track,
            strokeWidth: strokeWidth,
          ),
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      value: v == null ? null : '${(v * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ring,
            if (child != null)
              Center(
                child: DefaultTextStyle.merge(
                  style: context.text.labelSmall?.copyWith(
                    fontFeatures: MiriaFonts.tabular,
                  ),
                  child: child!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inset, 0, math.pi * 2, false, paint..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      inset,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
