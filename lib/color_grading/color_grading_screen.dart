import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/snackbar_helper.dart';
import 'color_adjustment.dart';
import 'color_grading_params.dart';
import 'graded_photo_storage_stub.dart'
    if (dart.library.io) 'graded_photo_storage_io.dart';

enum _PreviewTab { reference, original, adjusted, compare }

class ColorGradingScreen extends StatefulWidget {
  const ColorGradingScreen({
    required this.recordId,
    required this.capturedPath,
    this.referenceImagePath,
    this.referenceImageUrl,
    super.key,
  });

  final String recordId;
  final String capturedPath;
  final String? referenceImagePath;
  final String? referenceImageUrl;

  @override
  State<ColorGradingScreen> createState() => _ColorGradingScreenState();
}

class _ColorGradingScreenState extends State<ColorGradingScreen> {
  var _tab = _PreviewTab.adjusted;
  var _loading = true;
  var _matching = false;
  var _saving = false;
  var _intensity = 1.0;
  Uint8List? _capturedBytes;
  Uint8List? _referenceBytes;
  ColorMatchResult? _matchResult;
  Object? _loadError;

  ColorGradingParams get _activeParams {
    return ColorGradingParams.lerp(
      ColorGradingParams.defaults,
      _matchResult?.targetParams ?? ColorGradingParams.defaults,
      _intensity,
    );
  }

  int? get _currentToneScore {
    final result = _matchResult;
    if (result == null) {
      return null;
    }
    return (result.beforeScore +
            (result.afterScore - result.beforeScore) * _intensity)
        .round()
        .clamp(0, 100);
  }

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final capturedBytes = await File(widget.capturedPath).readAsBytes();
      final referenceBytes = await _loadReferenceBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _capturedBytes = capturedBytes;
        _referenceBytes = referenceBytes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<Uint8List?> _loadReferenceBytes() async {
    final path = widget.referenceImagePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        return file.readAsBytes();
      }
    }

    final url = widget.referenceImageUrl;
    if (url == null || url.isEmpty) {
      return null;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    return null;
  }

  Future<void> _runAutoMatch() async {
    final captured = _capturedBytes;
    final reference = _referenceBytes;
    final messenger = ScaffoldMessenger.of(context);
    if (captured == null) {
      messenger.showReplacingSnackBar(const SnackBar(content: Text('巡礼图读取失败')));
      return;
    }
    if (reference == null) {
      messenger.showReplacingSnackBar(
        const SnackBar(content: Text('没有可用于自动调色的参考图')),
      );
      return;
    }
    if (_matching) {
      return;
    }

    setState(() => _matching = true);
    final result = await autoMatchColorTone(
      capturedBytes: captured,
      referenceBytes: reference,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _matching = false;
      if (result != null) {
        _matchResult = result;
        _intensity = 1.0;
        _tab = _PreviewTab.adjusted;
      }
    });

    messenger.showReplacingSnackBar(
      SnackBar(content: Text(result == null ? '自动调色失败' : '已生成自动调色参数')),
    );
  }

  Future<void> _save() async {
    final captured = _capturedBytes;
    final messenger = ScaffoldMessenger.of(context);
    if (captured == null || _saving) {
      return;
    }
    if (_matchResult == null) {
      messenger.showReplacingSnackBar(
        const SnackBar(content: Text('请先自动匹配色调')),
      );
      return;
    }

    setState(() => _saving = true);
    final bytes = await renderGradedJpeg(
      imageBytes: captured,
      params: _activeParams,
    );
    final path = await saveGradedPhoto(bytes: bytes, recordId: widget.recordId);
    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    messenger.showReplacingSnackBar(
      SnackBar(content: Text(path != null ? '已保存调色副本' : '保存失败')),
    );
  }

  void _reset() {
    setState(() {
      _matchResult = null;
      _intensity = 1.0;
      _tab = _PreviewTab.adjusted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动调色'),
        actions: [TextButton(onPressed: _reset, child: const Text('重置'))],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null || _capturedBytes == null) {
      return const Center(child: Text('照片读取失败'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PreviewTabBar(
          tab: _tab,
          hasReference: _referenceBytes != null,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.42).clamp(300, 430),
          child: _PreviewSurface(
            tab: _tab,
            referenceBytes: _referenceBytes,
            capturedBytes: _capturedBytes!,
            activeParams: _activeParams,
            onOpenReference: _referenceBytes == null
                ? null
                : () => ImageViewerScreen.show(context, bytes: _referenceBytes),
            onOpenCaptured: () =>
                ImageViewerScreen.show(context, filePath: widget.capturedPath),
          ),
        ),
        const SizedBox(height: 12),
        _ScorePanel(
          matchResult: _matchResult,
          currentToneScore: _currentToneScore,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _matching ? null : _runAutoMatch,
          icon: _matching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(_matching ? '匹配中...' : '自动匹配色调'),
        ),
        if (_matchResult != null) ...[
          const SizedBox(height: 12),
          _IntensityControl(
            value: _intensity,
            onChanged: (value) => setState(() => _intensity = value),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_saving ? '保存中...' : '保存调色副本'),
        ),
      ],
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.tab,
    required this.referenceBytes,
    required this.capturedBytes,
    required this.activeParams,
    required this.onOpenReference,
    required this.onOpenCaptured,
  });

  final _PreviewTab tab;
  final Uint8List? referenceBytes;
  final Uint8List capturedBytes;
  final ColorGradingParams activeParams;
  final VoidCallback? onOpenReference;
  final VoidCallback onOpenCaptured;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (tab) {
        _PreviewTab.reference => _referencePreview(),
        _PreviewTab.original => _imageButton(
          onTap: onOpenCaptured,
          child: _capturedImage(),
        ),
        _PreviewTab.adjusted => _imageButton(
          onTap: onOpenCaptured,
          child: _adjustedImage(),
        ),
        _PreviewTab.compare => _comparePreview(),
      },
    );
  }

  Widget _referencePreview() {
    final bytes = referenceBytes;
    if (bytes == null) {
      return const Center(child: Text('没有参考图'));
    }
    return _imageButton(
      onTap: onOpenReference,
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }

  Widget _comparePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final children = [
          Expanded(
            child: _ComparePane(label: '原图', child: _capturedImage()),
          ),
          const SizedBox(width: 1, height: 1),
          Expanded(
            child: _ComparePane(label: '调色后', child: _adjustedImage()),
          ),
        ];
        if (isWide) {
          return Row(children: children);
        }
        return Column(children: children);
      },
    );
  }

  Widget _capturedImage() {
    return Image.memory(capturedBytes, fit: BoxFit.contain);
  }

  Widget _adjustedImage() {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(activeParams.toColorMatrix()),
      child: Image.memory(capturedBytes, fit: BoxFit.contain),
    );
  }

  Widget _imageButton({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Center(child: child),
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: child),
        Positioned(
          left: 8,
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewTabBar extends StatelessWidget {
  const _PreviewTabBar({
    required this.tab,
    required this.hasReference,
    required this.onChanged,
  });

  final _PreviewTab tab;
  final bool hasReference;
  final ValueChanged<_PreviewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TabChip(
          label: '参考',
          selected: tab == _PreviewTab.reference,
          enabled: hasReference,
          onTap: () => onChanged(_PreviewTab.reference),
        ),
        _TabChip(
          label: '原图',
          selected: tab == _PreviewTab.original,
          onTap: () => onChanged(_PreviewTab.original),
        ),
        _TabChip(
          label: '调色后',
          selected: tab == _PreviewTab.adjusted,
          onTap: () => onChanged(_PreviewTab.adjusted),
        ),
        _TabChip(
          label: '对比',
          selected: tab == _PreviewTab.compare,
          onTap: () => onChanged(_PreviewTab.compare),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: enabled ? (_) => onTap() : null,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surface,
      disabledColor: AppColors.surfaceMuted,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.matchResult,
    required this.currentToneScore,
  });

  final ColorMatchResult? matchResult;
  final int? currentToneScore;

  @override
  Widget build(BuildContext context) {
    final result = matchResult;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: result == null
          ? const Row(
              children: [
                Icon(Icons.auto_fix_high_outlined, color: AppColors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '自动匹配后可用强度滑块实时预览',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '色调匹配',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ScoreValue(label: '原图', score: result.beforeScore),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    _ScoreValue(label: '当前', score: currentToneScore ?? 0),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    _ScoreValue(label: '100%', score: result.afterScore),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ScoreValue extends StatelessWidget {
  const _ScoreValue({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: AppColors.accentDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntensityControl extends StatelessWidget {
  const _IntensityControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '调色强度',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
