import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import 'pressable.dart' show showsKeyboardFocus;
import 'rows.dart' show kMiriaSliderPadding;
import 'selection.dart';

/// How [PhotoCompare] arranges the two images.
enum PhotoCompareMode {
  /// 上下: reference above, photo below.
  stacked('上下', Symbols.splitscreen_rounded),

  /// 并排: side by side.
  sideBySide('并排', Symbols.vertical_split_rounded),

  /// 滑动对比: one frame, draggable divider.
  slider('滑动对比', Symbols.compare_rounded),

  /// 叠影: photo over the reference with adjustable opacity.
  overlay('叠影', Symbols.layers_rounded);

  const PhotoCompareMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Reference image vs pilgrimage photo (DESIGN §6.7, §7).
///
/// Four modes: [PhotoCompareMode.stacked] 上下, [PhotoCompareMode.sideBySide]
/// 并排, [PhotoCompareMode.slider] 滑动对比 (draggable divider, ←/→ keys) and
/// [PhotoCompareMode.overlay] 叠影 (opacity slider). Without an explicit
/// mode it picks side by side when the box is wide (≥ 560) and the
/// reference is landscape, stacked otherwise; the built-in mode selector
/// lets the user switch.
///
/// Images keep their aspect ratio in stacked / side-by-side modes. The
/// `.images` constructor resolves ratios from the providers; with widgets
/// pass [referenceAspectRatio] / [photoAspectRatio] and give the widgets
/// `fit: BoxFit.cover`.
///
/// ```dart
/// PhotoCompare.images(
///   reference: referenceProvider,
///   photo: FileImage(file),
///   onTapPhoto: () => openImageViewer(...),
/// )
/// ```
class PhotoCompare extends StatefulWidget {
  const PhotoCompare({
    required Widget this.reference,
    required Widget this.photo,
    this.referenceAspectRatio = 16 / 9,
    this.photoAspectRatio,
    this.mode,
    this.onModeChanged,
    this.showModeSelector = true,
    this.referenceLabel = '参考图',
    this.photoLabel = '巡礼图',
    this.onTapReference,
    this.onTapPhoto,
    this.initialOverlayOpacity = 0.5,
    this.borderRadius = Radii.mdAll,
    this.showLabels = true,
    super.key,
  }) : referenceImage = null,
       photoImage = null;

  /// Builds `Image` widgets from providers and resolves their aspect ratios.
  const PhotoCompare.images({
    required ImageProvider reference,
    required ImageProvider photo,
    this.referenceAspectRatio = 16 / 9,
    this.photoAspectRatio,
    this.mode,
    this.onModeChanged,
    this.showModeSelector = true,
    this.referenceLabel = '参考图',
    this.photoLabel = '巡礼图',
    this.onTapReference,
    this.onTapPhoto,
    this.initialOverlayOpacity = 0.5,
    this.borderRadius = Radii.mdAll,
    this.showLabels = true,
    super.key,
  }) : referenceImage = reference,
       photoImage = photo,
       reference = null,
       photo = null;

  final Widget? reference;
  final Widget? photo;
  final ImageProvider? referenceImage;
  final ImageProvider? photoImage;

  /// Width / height of the reference (fallback until resolved).
  final double referenceAspectRatio;

  /// Width / height of the photo; defaults to the reference ratio.
  final double? photoAspectRatio;

  /// Controlled mode; null lets the component choose / remember.
  final PhotoCompareMode? mode;
  final ValueChanged<PhotoCompareMode>? onModeChanged;
  final bool showModeSelector;
  final String referenceLabel;
  final String photoLabel;
  final VoidCallback? onTapReference;
  final VoidCallback? onTapPhoto;
  final double initialOverlayOpacity;
  final BorderRadius borderRadius;

  /// Corner labels 「参考图」「巡礼图」.
  final bool showLabels;

  /// The automatic mode for a box of [width].
  static PhotoCompareMode autoMode(double width, double referenceAspect) =>
      width >= 560 && referenceAspect >= 1
      ? PhotoCompareMode.sideBySide
      : PhotoCompareMode.stacked;

  @override
  State<PhotoCompare> createState() => _PhotoCompareState();
}

class _PhotoCompareState extends State<PhotoCompare> {
  PhotoCompareMode? _chosen;
  double _split = 0.5;
  late double _opacity = widget.initialOverlayOpacity;
  double? _refAspect;
  double? _photoAspect;
  final List<(ImageStream, ImageStreamListener)> _streams = [];
  bool _sliderFocused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referenceImage != widget.referenceImage ||
        oldWidget.photoImage != widget.photoImage) {
      _refAspect = null;
      _photoAspect = null;
      _resolve();
    }
  }

  void _resolve() {
    _stopListening();
    final config = createLocalImageConfiguration(context);
    void listen(ImageProvider? provider, void Function(double) set) {
      if (provider == null) return;
      final stream = provider.resolve(config);
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        final ratio = info.image.width / info.image.height;
        if (mounted && ratio.isFinite && ratio > 0) setState(() => set(ratio));
      }, onError: (_, _) {});
      stream.addListener(listener);
      _streams.add((stream, listener));
    }

    listen(widget.referenceImage, (r) => _refAspect = r);
    listen(widget.photoImage, (r) => _photoAspect = r);
  }

  void _stopListening() {
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    _streams.clear();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  double get _refRatio => _refAspect ?? widget.referenceAspectRatio;
  double get _photoRatio =>
      _photoAspect ?? widget.photoAspectRatio ?? _refRatio;

  Widget _image(bool reference) {
    final provider = reference ? widget.referenceImage : widget.photoImage;
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => _ImageError(),
      );
    }
    return (reference ? widget.reference : widget.photo)!;
  }

  void _setMode(PhotoCompareMode mode) {
    setState(() => _chosen = mode);
    widget.onModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode =
            widget.mode ??
            _chosen ??
            PhotoCompare.autoMode(constraints.maxWidth, _refRatio);
        final body = switch (mode) {
          PhotoCompareMode.stacked => _buildPair(vertical: true),
          PhotoCompareMode.sideBySide => _buildPair(vertical: false),
          PhotoCompareMode.slider => _buildSlider(context),
          PhotoCompareMode.overlay => _buildOverlay(context),
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showModeSelector) ...[
              SegmentedControl<PhotoCompareMode>(
                semanticLabel: '对比方式',
                options: [
                  for (final m in PhotoCompareMode.values)
                    SegmentOption(value: m, label: m.label, icon: m.icon),
                ],
                value: mode,
                onChanged: _setMode,
              ),
              const SizedBox(height: Space.x3),
            ],
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.standard),
              child: KeyedSubtree(key: ValueKey(mode), child: body),
            ),
          ],
        );
      },
    );
  }

  Widget _panel({required bool reference, required double aspect}) {
    final label = reference ? widget.referenceLabel : widget.photoLabel;
    final onTap = reference ? widget.onTapReference : widget.onTapPhoto;
    return Semantics(
      image: true,
      label: label,
      button: onTap != null,
      child: _Frame(
        borderRadius: widget.borderRadius,
        aspectRatio: aspect,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(reference),
            if (widget.showLabels)
              Positioned(left: 8, top: 8, child: _CornerLabel(label)),
          ],
        ),
      ),
    );
  }

  Widget _buildPair({required bool vertical}) {
    final ref = _panel(reference: true, aspect: _refRatio);
    final photo = _panel(reference: false, aspect: _photoRatio);
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ref,
          const SizedBox(height: Space.x2),
          photo,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: ref),
        const SizedBox(width: Space.x2),
        Expanded(child: photo),
      ],
    );
  }

  Widget _buildSlider(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(double dx) =>
            setState(() => _split = (dx / width).clamp(0.0, 1.0));
        return Semantics(
          slider: true,
          label: '滑动对比',
          value: '${(_split * 100).round()}%',
          increasedValue: '${((_split + 0.05).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue: '${((_split - 0.05).clamp(0.0, 1.0) * 100).round()}%',
          onIncrease: () =>
              setState(() => _split = (_split + 0.05).clamp(0.0, 1.0)),
          onDecrease: () =>
              setState(() => _split = (_split - 0.05).clamp(0.0, 1.0)),
          child: Focus(
            onFocusChange: (v) => setState(() => _sliderFocused = v),
            onKeyEvent: (node, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;
              final delta = switch (event.logicalKey) {
                LogicalKeyboardKey.arrowLeft => -0.05,
                LogicalKeyboardKey.arrowRight => 0.05,
                _ => null,
              };
              if (delta == null) return KeyEventResult.ignored;
              setState(() => _split = (_split + delta).clamp(0.0, 1.0));
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => update(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
              onTapUp: (d) {
                final onRef = d.localPosition.dx < _split * width;
                (onRef ? widget.onTapReference : widget.onTapPhoto)?.call();
              },
              child: _Frame(
                borderRadius: widget.borderRadius,
                aspectRatio: _refRatio,
                focused: _sliderFocused,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _image(true),
                    ClipRect(
                      clipper: _SplitClipper(_split),
                      child: _image(false),
                    ),
                    if (widget.showLabels) ...[
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _CornerLabel(widget.referenceLabel),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _CornerLabel(widget.photoLabel),
                      ),
                    ],
                    Positioned(
                      left: _split * width - 22,
                      top: 0,
                      bottom: 0,
                      width: 44,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 2,
                              color: c.onDarkroom.withValues(alpha: 0.95),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.onDarkroom,
                                shape: BoxShape.circle,
                                boxShadow: Elevations.level2(c),
                              ),
                              child: Icon(
                                Symbols.code_rounded,
                                size: 20,
                                color: c.darkroom,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: '${widget.referenceLabel}与${widget.photoLabel}叠影',
          child: _Frame(
            borderRadius: widget.borderRadius,
            aspectRatio: _refRatio,
            onTap: widget.onTapPhoto,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(true),
                Opacity(opacity: _opacity, child: _image(false)),
                if (widget.showLabels)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _CornerLabel(
                      '${widget.photoLabel} ${(_opacity * 100).round()}%',
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Icon(Symbols.opacity_rounded, size: 20, color: c.textSecondary),
            Expanded(
              child: Slider(
                padding: kMiriaSliderPadding,
                value: _opacity,
                semanticFormatterCallback: (v) => '叠影透明度 ${(v * 100).round()}%',
                onChanged: (v) => setState(() => _opacity = v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.borderRadius,
    required this.aspectRatio,
    required this.child,
    this.onTap,
    this.focused = false,
  });

  final BorderRadius borderRadius;
  final double aspectRatio;
  final Widget child;
  final VoidCallback? onTap;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = focused && showsKeyboardFocus;
    Widget frame = AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(color: c.surfaceMuted, child: child),
      ),
    );
    if (onTap != null) {
      frame = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: frame),
      );
    }
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: ring ? c.primary : c.hairline,
          width: ring ? 2 : 1,
        ),
      ),
      child: frame,
    );
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  _SplitClipper(this.split);
  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_SplitClipper old) => old.split != split;
}

class _CornerLabel extends StatelessWidget {
  const _CornerLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.darkroom.withValues(alpha: 0.55),
          borderRadius: Radii.pillAll,
        ),
        child: Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: c.onDarkroom,
            fontFeatures: MiriaFonts.tabular,
          ),
        ),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(
          Symbols.broken_image_rounded,
          size: 28,
          color: c.textTertiary,
        ),
      ),
    );
  }
}
