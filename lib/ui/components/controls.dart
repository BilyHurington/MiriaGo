import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import 'buttons.dart';
import 'pressable.dart';

String _defaultFormat(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Vertical slider for camera rails (zoom, exposure, overlay opacity).
/// Dark-friendly by default ([onDark]); tap anywhere on the track to jump,
/// drag to adjust, ↑/↓ with a keyboard, screen-reader increase/decrease.
///
/// ```dart
/// MiriaVerticalSlider(
///   value: zoom, min: 1, max: 10,
///   semanticLabel: '变焦',
///   format: (v) => '${v.toStringAsFixed(1)}×',
///   onChanged: setZoom,
/// )
/// ```
class MiriaVerticalSlider extends StatefulWidget {
  const MiriaVerticalSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.onChangeStart,
    this.onChangeEnd,
    this.height = 200,
    this.width = 44,
    this.semanticLabel,
    this.format,
    this.onDark = true,
    this.keyboardStep = 0.05,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  /// Hit width (the track itself is 4 px).
  final double width;
  final String? semanticLabel;
  final String Function(double value)? format;

  /// Light-on-dark palette (camera). False uses the regular palette.
  final bool onDark;

  /// Fraction of the range per arrow key / accessibility step.
  final double keyboardStep;

  @override
  State<MiriaVerticalSlider> createState() => _MiriaVerticalSliderState();
}

class _MiriaVerticalSliderState extends State<MiriaVerticalSlider> {
  static const double _thumb = 22;
  bool _dragging = false;
  bool _focused = false;

  double get _range => widget.max - widget.min;
  double get _t =>
      _range == 0 ? 0 : ((widget.value - widget.min) / _range).clamp(0.0, 1.0);

  double _valueAt(double dy) {
    final usable = widget.height - _thumb;
    final t = 1 - ((dy - _thumb / 2) / usable).clamp(0.0, 1.0);
    return widget.min + t * _range;
  }

  void _emit(double v) =>
      widget.onChanged?.call(v.clamp(widget.min, widget.max));

  void _step(int direction) {
    final next = (widget.value + direction * widget.keyboardStep * _range)
        .clamp(widget.min, widget.max);
    widget.onChangeStart?.call(widget.value);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  String _format(double v) => (widget.format ?? _defaultFormat)(v);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onChanged != null;
    final active = widget.onDark ? c.onDarkroom : c.primary;
    final track = widget.onDark
        ? c.onDarkroom.withValues(alpha: 0.28)
        : c.hairlineStrong;
    final thumbFill = widget.onDark ? c.onDarkroom : c.surface;
    final stepValue = widget.keyboardStep * _range;
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: _format(widget.value),
      increasedValue: _format(
        (widget.value + stepValue).clamp(widget.min, widget.max),
      ),
      decreasedValue: _format(
        (widget.value - stepValue).clamp(widget.min, widget.max),
      ),
      onIncrease: enabled ? () => _step(1) : null,
      onDecrease: enabled ? () => _step(-1) : null,
      child: Focus(
        canRequestFocus: enabled,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is KeyUpEvent || !enabled) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _step(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _step(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusRing(
          focused: _focused,
          borderRadius: Radii.pillAll,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled
                ? (d) {
                    widget.onChangeStart?.call(widget.value);
                    _emit(_valueAt(d.localPosition.dy));
                  }
                : null,
            onTapUp: enabled
                ? (_) => widget.onChangeEnd?.call(widget.value)
                : null,
            onVerticalDragStart: enabled
                ? (d) {
                    setState(() => _dragging = true);
                    widget.onChangeStart?.call(widget.value);
                    _emit(_valueAt(d.localPosition.dy));
                  }
                : null,
            onVerticalDragUpdate: enabled
                ? (d) => _emit(_valueAt(d.localPosition.dy))
                : null,
            onVerticalDragEnd: enabled
                ? (_) {
                    setState(() => _dragging = false);
                    widget.onChangeEnd?.call(widget.value);
                  }
                : null,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: CustomPaint(
                painter: _VerticalSliderPainter(
                  t: _t,
                  active: enabled ? active : active.withValues(alpha: 0.4),
                  track: track,
                  thumbFill: thumbFill,
                  thumbBorder: widget.onDark ? null : c.primary,
                  shadow: c.shadow,
                  thumbSize: _dragging ? _thumb + 4 : _thumb,
                  inset: _thumb,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalSliderPainter extends CustomPainter {
  _VerticalSliderPainter({
    required this.t,
    required this.active,
    required this.track,
    required this.thumbFill,
    required this.thumbBorder,
    required this.shadow,
    required this.thumbSize,
    required this.inset,
  });

  final double t;
  final Color active;
  final Color track;
  final Color thumbFill;
  final Color? thumbBorder;
  final Color shadow;
  final double thumbSize;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final top = inset / 2;
    final bottom = size.height - inset / 2;
    final y = bottom - (bottom - top) * t;
    final line = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(x, top), Offset(x, bottom), line..color = track)
      ..drawLine(Offset(x, y), Offset(x, bottom), line..color = active);
    final center = Offset(x, y);
    canvas.drawCircle(
      center.translate(0, 1),
      thumbSize / 2,
      Paint()
        ..color = shadow.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, thumbSize / 2, Paint()..color = thumbFill);
    if (thumbBorder != null) {
      canvas.drawCircle(
        center,
        thumbSize / 2 - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = thumbBorder!,
      );
    }
  }

  @override
  bool shouldRepaint(_VerticalSliderPainter old) =>
      old.t != t ||
      old.active != active ||
      old.track != track ||
      old.thumbFill != thumbFill ||
      old.thumbBorder != thumbBorder ||
      old.thumbSize != thumbSize;
}

/// − value + stepper for small numeric settings.
///
/// ```dart
/// MiriaStepper(
///   value: columns.toDouble(), min: 1, max: 4,
///   semanticLabel: '每行图片数',
///   onChanged: (v) => setState(() => columns = v.round()),
/// )
/// ```
class MiriaStepper extends StatelessWidget {
  const MiriaStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.format,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double step;
  final String Function(double value)? format;
  final String? semanticLabel;

  String _format(double v) => (format ?? _defaultFormat)(v);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final canDec = enabled && value - step >= min - 1e-9;
    final canInc = enabled && value + step <= max + 1e-9;
    void dec() => onChanged!((value - step).clamp(min, max));
    void inc() => onChanged!((value + step).clamp(min, max));
    return Semantics(
      label: semanticLabel,
      value: _format(value),
      increasedValue: canInc ? _format((value + step).clamp(min, max)) : null,
      decreasedValue: canDec ? _format((value - step).clamp(min, max)) : null,
      onIncrease: canInc ? inc : null,
      onDecrease: canDec ? dec : null,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: Radii.pillAll,
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiriaIconButton(
              icon: Symbols.remove_rounded,
              tooltip: '减少',
              compact: true,
              onPressed: canDec ? dec : null,
            ),
            ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: Text(
                  _format(value),
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall?.copyWith(
                    fontFeatures: MiriaFonts.tabular,
                    color: enabled ? c.textPrimary : c.textDisabled,
                  ),
                ),
              ),
            ),
            MiriaIconButton(
              icon: Symbols.add_rounded,
              tooltip: '增加',
              compact: true,
              onPressed: canInc ? inc : null,
            ),
          ],
        ),
      ),
    );
  }
}
