import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../app_theme.dart';
import 'color_adjustment.dart';
import 'color_grading_params.dart';
import 'graded_photo_storage_stub.dart'
    if (dart.library.io) 'graded_photo_storage_io.dart';
import 'tone_curve_widget.dart';

enum _PreviewTab { captured, graded, compare }

class ColorGradingScreen extends StatefulWidget {
  const ColorGradingScreen({
    required this.capturedPath,
    super.key,
  });

  final String capturedPath;

  @override
  State<ColorGradingScreen> createState() => _ColorGradingScreenState();
}

class _ColorGradingScreenState extends State<ColorGradingScreen> {
  var _params = ColorGradingParams();
  var _tab = _PreviewTab.captured;
  Uint8List? _gradedBytes;
  var _grading = false;
  var _saving = false;

  Uint8List? _cachedCapturedBytes;

  @override
  void initState() {
    super.initState();
    _loadCaptured();
  }

  void _loadCaptured() {
    try {
      _cachedCapturedBytes = File(widget.capturedPath).readAsBytesSync();
    } catch (_) {}
  }

  Future<void> _regrade() async {
    final source = _cachedCapturedBytes;
    if (source == null || _grading) return;

    setState(() => _grading = true);
    final result = await applyColorGrading(
      imageBytes: source,
      params: _params,
      maxLongSide: 512,
    );
    if (!mounted) return;
    setState(() {
      _gradedBytes = result;
      _grading = false;
      if (_tab == _PreviewTab.captured) _tab = _PreviewTab.graded;
    });
  }

  Future<void> _save() async {
    final source = _cachedCapturedBytes;
    if (source == null || _saving) return;

    setState(() => _saving = true);
    // Generate full-resolution output
    final result = await applyColorGrading(
      imageBytes: source,
      params: _params,
    );
    final path = await saveGradedPhoto(
      bytes: result,
      recordId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null ? '已保存调色副本' : '保存失败')),
    );
    if (path != null && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onParamChanged(ColorGradingParams params) {
    setState(() => _params = params);
    _gradedBytes = null;
  }

  void _reset() {
    _onParamChanged(ColorGradingParams());
  }

  Widget _previewImage() {
    return switch (_tab) {
      _PreviewTab.captured => _cachedCapturedBytes != null
          ? Image.memory(_cachedCapturedBytes!, fit: BoxFit.contain)
          : const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
      _PreviewTab.graded || _PreviewTab.compare => _gradedBytes != null
          ? Image.memory(_gradedBytes!, fit: BoxFit.contain)
          : const Center(child: Text('请先点击"应用调色"')),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('调色'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('重置'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Fixed preview area
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.32,
            child: Column(
              children: [
                _PreviewTabBar(tab: _tab, onChanged: (t) => setState(() => _tab = t)),
                Expanded(child: _previewImage()),
              ],
            ),
          ),
          const Divider(height: 1),
          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _grading ? null : _regrade,
                icon: _grading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(_grading ? '处理中...' : '应用调色'),
              ),
            ),
          ),
          const Divider(height: 1),
          // Scrollable controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _ParamSlider(
                  label: '曝光',
                  value: _params.exposure,
                  min: -1.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(exposure: v)),
                ),
                _ParamSlider(
                  label: '对比度',
                  value: _params.contrast,
                  min: 0.7,
                  max: 1.4,
                  defaultValue: 1.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(contrast: v)),
                ),
                _ParamSlider(
                  label: 'Gamma',
                  value: _params.gamma,
                  min: 0.7,
                  max: 1.5,
                  defaultValue: 1.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(gamma: v)),
                ),
                _ParamSlider(
                  label: '饱和度',
                  value: _params.saturation,
                  min: 0.5,
                  max: 1.6,
                  defaultValue: 1.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(saturation: v)),
                ),
                _ParamSlider(
                  label: '色温',
                  value: _params.temperature,
                  min: -1.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(temperature: v)),
                ),
                _ParamSlider(
                  label: '色调',
                  value: _params.tint,
                  min: -1.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  onChanged: (v) =>
                      _onParamChanged(_params.copyWith(tint: v)),
                ),
                const SizedBox(height: 8),
                const _SectionLabel('RGB 曲线'),
                const SizedBox(height: 8),
                ToneCurveEditor(
                  curve: _params.toneCurve,
                  onChanged: (c) =>
                      _onParamChanged(_params.copyWith(toneCurve: c)),
                ),
                const SizedBox(height: 16),
                const _SectionLabel('色调映射'),
                const SizedBox(height: 8),
                _HueWheel(
                  onColorSelected: (hsv) {
                    // Map HSV to temperature/tint
                    final temp = (hsv.hue / 180.0 - 1.0).clamp(-1.0, 1.0);
                    final tnt =
                        ((hsv.saturation / 100.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
                    _onParamChanged(_params.copyWith(
                      temperature: temp,
                      tint: tnt,
                    ));
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? '保存中...' : '保存副本'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preview tab bar ────────────────────────────────────────────────────

class _PreviewTabBar extends StatelessWidget {
  const _PreviewTabBar({required this.tab, required this.onChanged});

  final _PreviewTab tab;
  final ValueChanged<_PreviewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _TabChip(
            label: '原图',
            selected: tab == _PreviewTab.captured,
            onTap: () => onChanged(_PreviewTab.captured),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: '调色后',
            selected: tab == _PreviewTab.graded,
            onTap: () => onChanged(_PreviewTab.graded),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: '对比',
            selected: tab == _PreviewTab.compare,
            onTap: () => onChanged(_PreviewTab.compare),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

// ── Parameter slider ───────────────────────────────────────────────────

class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(defaultValue),
            child: SizedBox(
              width: 42,
              child: Text(
                value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: value == defaultValue
                      ? AppColors.textSecondary
                      : AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hue wheel ──────────────────────────────────────────────────────────

class _HueWheel extends StatelessWidget {
  const _HueWheel({required this.onColorSelected});

  final ValueChanged<HSVColor> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: ColorPicker(
          pickerColor: Colors.white,
          onColorChanged: (c) {
            // Not used directly - we only want wheel interaction
          },
          enableAlpha: false,
          displayThumbColor: true,
          paletteType: PaletteType.hsv,
          pickerAreaHeightPercent: 0,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
