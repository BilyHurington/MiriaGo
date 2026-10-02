import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';

/// The reference and the photo in one frame, split by a divider that can be
/// dragged (or moved with the arrow keys) to compare them. The reference is
/// on the left, the photo on the right. Both images should fill the frame
/// the same way (e.g. [BoxFit.cover]) so they line up.
class PhotoCompareSlider extends StatefulWidget {
  const PhotoCompareSlider({
    required this.reference,
    required this.photo,
    this.aspectRatio = 16 / 9,
    this.initialSplit = 0.5,
    this.onTapReference,
    this.onTapPhoto,
    super.key,
  });

  final Widget reference;
  final Widget photo;
  final double aspectRatio;

  /// Where the divider starts, from 0 (all photo) to 1 (all reference).
  final double initialSplit;
  final VoidCallback? onTapReference;
  final VoidCallback? onTapPhoto;

  @override
  State<PhotoCompareSlider> createState() => _PhotoCompareSliderState();
}

class _PhotoCompareSliderState extends State<PhotoCompareSlider> {
  static const _viewReferenceAction = CustomSemanticsAction(label: '查看参考图');
  static const _viewPhotoAction = CustomSemanticsAction(label: '查看巡礼图');
  static const _keyboardStep = 0.05;
  static const _handleHitWidth = 44.0;

  /// The handle never sits closer than this to the frame's edge, where it
  /// would be cut off and hard to grab back.
  static const _edgeInset = 24.0;

  late double _split = widget.initialSplit.clamp(0.0, 1.0);

  /// Smallest split for the current width (see [_edgeInset]).
  var _minSplit = 0.0;
  var _focused = false;

  void _moveTo(double split) {
    final next = split.clamp(_minSplit, 1 - _minSplit);
    if (next != _split) {
      setState(() => _split = next);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveTo(_split - _keyboardStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveTo(_split + _keyboardStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final minSplit = width <= _edgeInset * 2 ? 0.5 : _edgeInset / width;
            _minSplit = minSplit;
            final split = _split.clamp(minSplit, 1 - minSplit);
            final dividerX = width * split;
            String percentOf(double value) =>
                '${(value.clamp(minSplit, 1 - minSplit) * 100).round()}%';
            return Semantics(
              key: const ValueKey('photo-compare-slider'),
              slider: true,
              label: '滑动对比，左侧参考图，右侧巡礼图',
              value: percentOf(split),
              increasedValue: percentOf(split + _keyboardStep),
              decreasedValue: percentOf(split - _keyboardStep),
              onIncrease: () => _moveTo(_split + _keyboardStep),
              onDecrease: () => _moveTo(_split - _keyboardStep),
              // Tapping each side opens that image; offer both to screen
              // readers, whose tap lands on one fixed side.
              customSemanticsActions: {
                if (widget.onTapReference != null)
                  _viewReferenceAction: widget.onTapReference!,
                if (widget.onTapPhoto != null)
                  _viewPhotoAction: widget.onTapPhoto!,
              },
              child: Focus(
                onKeyEvent: _handleKey,
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) =>
                      _moveTo(details.localPosition.dx / width),
                  onHorizontalDragUpdate: (details) =>
                      _moveTo(details.localPosition.dx / width),
                  onTapUp: (details) => details.localPosition.dx < dividerX
                      ? widget.onTapReference?.call()
                      : widget.onTapPhoto?.call(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: AppColors.surfaceMuted),
                      widget.reference,
                      ClipRect(
                        clipper: _SplitClipper(split),
                        child: widget.photo,
                      ),
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: _CornerLabel('参考图'),
                      ),
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: _CornerLabel('巡礼图'),
                      ),
                      Positioned(
                        left: dividerX - _handleHitWidth / 2,
                        width: _handleHitWidth,
                        top: 0,
                        bottom: 0,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: _DividerHandle(),
                        ),
                      ),
                      if (_focused)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Keeps the part of the photo right of the divider.
class _SplitClipper extends CustomClipper<Rect> {
  const _SplitClipper(this.split);

  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_SplitClipper oldClipper) => oldClipper.split != split;
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 2, color: Colors.white.withValues(alpha: 0.95)),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.chevronsLeftRight,
            size: 18,
            color: Color(0xFF1F2328),
          ),
        ),
      ],
    );
  }
}

class _CornerLabel extends StatelessWidget {
  const _CornerLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
