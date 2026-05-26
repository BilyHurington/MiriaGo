import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../widgets/snackbar_helper.dart';
import 'color_adjustment.dart';
import 'color_grading_params.dart';
import 'graded_photo_storage_stub.dart'
    if (dart.library.io) 'graded_photo_storage_io.dart';

class ColorGradingScreen extends StatefulWidget {
  const ColorGradingScreen({
    required this.record,
    required this.controller,
    this.fallbackReferenceImagePath,
    this.fallbackReferenceImageUrl,
    super.key,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePlanController controller;
  final String? fallbackReferenceImagePath;
  final String? fallbackReferenceImageUrl;

  @override
  State<ColorGradingScreen> createState() => _ColorGradingScreenState();
}

class _ColorGradingScreenState extends State<ColorGradingScreen> {
  var _loading = true;
  var _matching = false;
  var _saving = false;
  var _showOriginal = false;
  var _intensity = 1.0;
  var _selectedMode = ColorMatchMode.standard;
  Uint8List? _capturedBytes;
  Uint8List? _referenceBytes;
  ColorGradingParams? _targetParams;
  int? _beforeScore;
  int? _afterScore;
  Object? _loadError;

  PilgrimageVisitRecord get _record => widget.record;

  ColorGradingParams get _activeParams {
    return ColorGradingParams.lerp(
      ColorGradingParams.defaults,
      _targetParams ?? ColorGradingParams.defaults,
      _intensity,
    );
  }

  int? get _currentToneScore {
    final before = _beforeScore;
    final after = _afterScore;
    if (before == null || after == null) {
      return null;
    }
    return (before + (after - before) * _intensity).round().clamp(0, 100);
  }

  @override
  void initState() {
    super.initState();
    _restoreSavedGrading();
    _loadImages();
  }

  void _restoreSavedGrading() {
    final savedMode = _record.colorGradingMode;
    if (savedMode != null) {
      _selectedMode = ColorMatchMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ColorMatchMode.standard,
      );
    }

    _intensity = (_record.colorGradingIntensity ?? 1).clamp(0.0, 1.0);
    final paramsJson = _record.colorGradingParamsJson;
    if (paramsJson == null || paramsJson.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is Map<String, Object?>) {
        _targetParams = ColorGradingParams.fromJson(decoded);
      }
    } catch (_) {}
  }

  Future<void> _loadImages() async {
    try {
      final capturedBytes = await File(_record.sourcePhotoPath).readAsBytes();
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
    for (final path in [
      _record.referenceImagePath,
      widget.fallbackReferenceImagePath,
    ].whereType<String>()) {
      final file = File(path);
      if (file.existsSync()) {
        return file.readAsBytes();
      }
    }

    final url = _record.referenceImageUrl ?? widget.fallbackReferenceImageUrl;
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
      mode: _selectedMode,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _matching = false;
      if (result != null) {
        _targetParams = result.targetParams;
        _selectedMode = result.mode;
        _beforeScore = result.beforeScore;
        _afterScore = result.afterScore;
        _intensity = 1.0;
      }
    });

    messenger.showReplacingSnackBar(
      SnackBar(content: Text(result == null ? '自动调色失败' : '已生成自动调色参数')),
    );
  }

  Future<void> _save() async {
    final captured = _capturedBytes;
    final targetParams = _targetParams;
    final messenger = ScaffoldMessenger.of(context);
    if (captured == null || _saving) {
      return;
    }
    if (targetParams == null) {
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
    final path = await saveGradedPhoto(bytes: bytes, recordId: _record.id);
    if (path == null) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showReplacingSnackBar(const SnackBar(content: Text('保存失败')));
      return;
    }

    final updated = await widget.controller.updateVisitRecordColorGrading(
      record: _record,
      originalPhotoPath: _record.sourcePhotoPath,
      gradedPhotoPath: path,
      colorGradingMode: _selectedMode.name,
      colorGradingParamsJson: jsonEncode(targetParams.toJson()),
      colorGradingIntensity: _intensity,
    );
    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    messenger.showReplacingSnackBar(const SnackBar(content: Text('已保存调色结果')));
    Navigator.of(context).pop(updated);
  }

  void _reset() {
    setState(() {
      _targetParams = null;
      _beforeScore = null;
      _afterScore = null;
      _intensity = 1.0;
      _showOriginal = false;
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
        _StackedPreview(
          referenceBytes: _referenceBytes,
          capturedBytes: _capturedBytes!,
          activeParams: _activeParams,
          showOriginal: _showOriginal || _targetParams == null,
        ),
        const SizedBox(height: 12),
        _OriginalHoldButton(
          enabled: _targetParams != null,
          showOriginal: _showOriginal,
          onChanged: (showOriginal) {
            setState(() => _showOriginal = showOriginal);
          },
        ),
        const SizedBox(height: 12),
        _ModeSelector(
          selectedMode: _selectedMode,
          onChanged: (mode) {
            setState(() {
              _selectedMode = mode;
              _targetParams = null;
              _beforeScore = null;
              _afterScore = null;
              _intensity = 1.0;
            });
          },
        ),
        const SizedBox(height: 12),
        _ScorePanel(
          hasSavedParams: _targetParams != null,
          beforeScore: _beforeScore,
          currentToneScore: _currentToneScore,
          afterScore: _afterScore,
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
        if (_targetParams != null) ...[
          const SizedBox(height: 12),
          _IntensityControl(
            value: _intensity,
            onChanged: (value) => setState(() => _intensity = value),
          ),
          const SizedBox(height: 12),
          _ParameterSummary(activeParams: _activeParams),
        ],
        const SizedBox(height: 12),
        _SavePanel(saving: _saving, onSave: _save),
      ],
    );
  }
}

class _StackedPreview extends StatelessWidget {
  const _StackedPreview({
    required this.referenceBytes,
    required this.capturedBytes,
    required this.activeParams,
    required this.showOriginal,
  });

  final Uint8List? referenceBytes;
  final Uint8List capturedBytes;
  final ColorGradingParams activeParams;
  final bool showOriginal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _PreviewPane(
            label: '参考图',
            child: referenceBytes == null
                ? const Center(child: Text('没有参考图'))
                : Image.memory(referenceBytes!, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          _PreviewPane(
            label: showOriginal ? '原图' : '调色后',
            child: showOriginal
                ? Image.memory(capturedBytes, fit: BoxFit.contain)
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      activeParams.toColorMatrix(),
                    ),
                    child: Image.memory(capturedBytes, fit: BoxFit.contain),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: Stack(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
          ),
        ),
      ),
    );
  }
}

class _OriginalHoldButton extends StatelessWidget {
  const _OriginalHoldButton({
    required this.enabled,
    required this.showOriginal,
    required this.onChanged,
  });

  final bool enabled;
  final bool showOriginal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled ? (_) => onChanged(true) : null,
      onPointerUp: enabled ? (_) => onChanged(false) : null,
      onPointerCancel: enabled ? (_) => onChanged(false) : null,
      child: OutlinedButton.icon(
        onPressed: enabled ? () {} : null,
        icon: Icon(showOriginal ? Icons.visibility : Icons.visibility_outlined),
        label: Text(showOriginal ? '正在显示原图' : '按住显示原图'),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});

  final ColorMatchMode selectedMode;
  final ValueChanged<ColorMatchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '匹配模式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in ColorMatchMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: selectedMode == mode,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(mode),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: selectedMode == mode
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: selectedMode == mode
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.hasSavedParams,
    required this.beforeScore,
    required this.currentToneScore,
    required this.afterScore,
  });

  final bool hasSavedParams;
  final int? beforeScore;
  final int? currentToneScore;
  final int? afterScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: beforeScore == null || afterScore == null
          ? Row(
              children: [
                Icon(Icons.auto_fix_high_outlined, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSavedParams ? '已恢复上次调色参数' : '自动匹配后可保存调色结果',
                    style: const TextStyle(
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
                    _ScoreValue(label: '原图', score: beforeScore!),
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
                    _ScoreValue(label: '100%', score: afterScore!),
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
            style: TextStyle(
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
                style: TextStyle(
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

class _ParameterSummary extends StatelessWidget {
  const _ParameterSummary({required this.activeParams});

  final ColorGradingParams activeParams;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Expanded(
                child: Text(
                  '调色参数',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showParameterSheet(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('查看'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '显示当前调色强度下实际生效的参数。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _showParameterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _ParameterSheet(activeParams: activeParams),
    );
  }
}

class _ParameterSheet extends StatelessWidget {
  const _ParameterSheet({required this.activeParams});

  final ColorGradingParams activeParams;

  @override
  Widget build(BuildContext context) {
    final items = <_ParameterItem>[
      _ParameterItem('亮度', activeParams.brightness, -0.25, 0.25),
      _ParameterItem('曝光', activeParams.exposure, -1.0, 1.0),
      _ParameterItem('对比度', activeParams.contrast, 0.7, 1.4),
      _ParameterItem('饱和度', activeParams.saturation, 0.5, 1.6),
      _ParameterItem('色温', activeParams.temperature, -1.0, 1.0),
      _ParameterItem('色调', activeParams.tint, -1.0, 1.0),
      _ParameterItem('高光', activeParams.highlights, -1.0, 1.0),
      _ParameterItem('阴影', activeParams.shadows, -1.0, 1.0),
      _ParameterItem('红暗部曲线', activeParams.redShadowCurve, -1.0, 1.0),
      _ParameterItem('红中间调曲线', activeParams.redMidCurve, -1.0, 1.0),
      _ParameterItem('红高光曲线', activeParams.redHighlightCurve, -1.0, 1.0),
      _ParameterItem('绿暗部曲线', activeParams.greenShadowCurve, -1.0, 1.0),
      _ParameterItem('绿中间调曲线', activeParams.greenMidCurve, -1.0, 1.0),
      _ParameterItem('绿高光曲线', activeParams.greenHighlightCurve, -1.0, 1.0),
      _ParameterItem('蓝暗部曲线', activeParams.blueShadowCurve, -1.0, 1.0),
      _ParameterItem('蓝中间调曲线', activeParams.blueMidCurve, -1.0, 1.0),
      _ParameterItem('蓝高光曲线', activeParams.blueHighlightCurve, -1.0, 1.0),
    ];

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: 10)
              : const Divider(height: 18),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Text(
                '调色参数',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              );
            }
            return _ParameterRow(item: items[index - 1]);
          },
        ),
      ),
    );
  }
}

class _ParameterItem {
  const _ParameterItem(this.label, this.value, this.min, this.max);

  final String label;
  final double value;
  final double min;
  final double max;
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.item});

  final _ParameterItem item;

  @override
  Widget build(BuildContext context) {
    final activeT = ((item.value - item.min) / (item.max - item.min))
        .clamp(0.0, 1.0)
        .toDouble();
    final activeText = item.value.toStringAsFixed(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              activeText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: activeT,
            minHeight: 7,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _SavePanel extends StatelessWidget {
  const _SavePanel({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '保存结果',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '保存后记录详情和导出会使用调色后的图片，原图和调色参数会保留。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? '保存中...' : '保存调色结果'),
          ),
        ],
      ),
    );
  }
}
