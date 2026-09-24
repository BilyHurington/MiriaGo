import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/bounded_image_decoder.dart';
import '../widgets/bounded_image.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_back_button.dart';
import '../widgets/confirm_action_dialog.dart';
import 'color_adjustment.dart';
import 'color_grading_parameter_summary.dart';
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
  Object? _referenceError;
  var _resetPending = false;

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
      final sourcePhotoPath = resolveVisitRecordSourcePhotoPath(_record);
      if (sourcePhotoPath == null) {
        throw StateError('Visit record photo is unavailable');
      }
      final capturedBytes = await readBoundedImageSource(sourcePhotoPath);
      await probeBoundedImage(capturedBytes);
      Uint8List? referenceBytes;
      Object? referenceError;
      try {
        referenceBytes = await _loadReferenceBytes();
        if (referenceBytes != null) await probeBoundedImage(referenceBytes);
      } catch (error) {
        // A missing reference disables matching, not edits to saved grading.
        referenceBytes = null;
        referenceError = error;
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _capturedBytes = capturedBytes;
        _referenceBytes = referenceBytes;
        _referenceError = referenceError;
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
      try {
        return await readBoundedImageSource(path);
      } on ImageBudgetException {
        rethrow;
      } catch (_) {
        // Missing local references may still have their original remote source.
      }
    }

    final url = _record.referenceImageUrl ?? widget.fallbackReferenceImageUrl;
    if (url == null || url.isEmpty) {
      return null;
    }

    return readBoundedImageSource(url);
  }

  Future<void> _runAutoMatch() async {
    if (!mounted || _matching || _saving) return;
    try {
      await _runAutoMatchUnchecked();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: error is ImageBudgetException ? error.message : '自动调色失败',
        );
      }
    } finally {
      if (mounted) setState(() => _matching = false);
    }
  }

  Future<void> _runAutoMatchUnchecked() async {
    final captured = _capturedBytes;
    final reference = _referenceBytes;
    final messenger = ScaffoldMessenger.of(context);
    if (captured == null) {
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: '巡礼图读取失败',
      );
      return;
    }
    if (reference == null) {
      final error = _referenceError;
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.warning,
        title: error is ImageBudgetException
            ? error.message
            : error == null
            ? '没有可用于自动调色的参考图'
            : '参考图暂不可用，无法自动匹配色调',
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
        _resetPending = false;
      }
    });

    messenger.showStatusSnack(
      kind: result == null
          ? AppStatusBannerKind.error
          : AppStatusBannerKind.success,
      title: result == null ? '自动调色失败' : '已生成自动调色参数',
    );
  }

  Future<void> _save() async {
    if (!mounted || _saving || _matching) return;
    try {
      await _saveUnchecked();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: error is ImageBudgetException ? error.message : '保存失败，原件未更改',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveUnchecked() async {
    final captured = _capturedBytes;
    final targetParams = _targetParams;
    final messenger = ScaffoldMessenger.of(context);
    if (captured == null || _saving) {
      return;
    }
    if (_resetPending) {
      setState(() => _saving = true);
      final updated = await widget.controller.clearVisitRecordColorGrading(
        record: _record,
      );
      if (!mounted) {
        return;
      }

      setState(() => _saving = false);
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '已还原为原图',
      );
      Navigator.of(context).pop(updated);
      return;
    }
    if (targetParams == null) {
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.warning,
        title: '请先自动匹配色调',
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
      messenger.showStatusSnack(kind: AppStatusBannerKind.error, title: '保存失败');
      return;
    }

    final updated = await widget.controller.updateVisitRecordColorGrading(
      record: _record,
      originalPhotoPath:
          resolveVisitRecordSourcePhotoPath(_record) ?? _record.sourcePhotoPath,
      gradedPhotoPath: path,
      colorGradingMode: _selectedMode.name,
      colorGradingParamsJson: jsonEncode(targetParams.toJson()),
      colorGradingIntensity: _intensity,
    );
    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    messenger.showStatusSnack(
      kind: AppStatusBannerKind.success,
      title: '已保存调色结果',
    );
    Navigator.of(context).pop(updated);
  }

  void _reset() {
    setState(() {
      _targetParams = null;
      _beforeScore = null;
      _afterScore = null;
      _intensity = 1.0;
      _showOriginal = false;
      _resetPending = _record.hasColorGrading;
    });
  }

  Future<void> _confirmReset() async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: '重置调色',
      message: '将清除当前调色，恢复为原图。',
      confirmLabel: '重置',
    );
    if (!confirmed || !mounted) {
      return;
    }
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: appBackButtonIfCanPop(context),
        title: const Text('自动调色'),
        actions: [
          IconButton(
            tooltip: '重置',
            onPressed: _confirmReset,
            icon: const Icon(LucideIcons.rotateCcw),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null || _capturedBytes == null) {
      return BoundedImageError(error: _loadError ?? StateError('照片读取失败'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StackedPreview(
          referenceBytes: _referenceBytes,
          referenceError: _referenceError,
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
              _resetPending = false;
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
              : const Icon(LucideIcons.wandSparkles, size: 18),
          label: Text(_matching ? '匹配中...' : '自动匹配色调'),
        ),
        if (_targetParams != null) ...[
          const SizedBox(height: 12),
          _IntensityControl(
            value: _intensity,
            onChanged: (value) => setState(() => _intensity = value),
          ),
          const SizedBox(height: 12),
          ColorGradingParameterSummary(activeParams: _activeParams),
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
    required this.referenceError,
    required this.capturedBytes,
    required this.activeParams,
    required this.showOriginal,
  });

  final Uint8List? referenceBytes;
  final Object? referenceError;
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
                ? referenceError == null
                      ? const Center(child: Text('没有参考图'))
                      : BoundedImageError(error: referenceError!)
                : BoundedImage(bytes: referenceBytes!),
          ),
          const SizedBox(height: 8),
          _PreviewPane(
            label: showOriginal ? '原图' : '调色后',
            child: showOriginal
                ? BoundedImage(bytes: capturedBytes)
                : _GradedPhotoPreview(
                    capturedBytes: capturedBytes,
                    params: activeParams,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shows the color-matrix preview immediately (exact for the linear
/// adjustments) and, when tone zones or RGB curves are active, swaps in a
/// debounced low-resolution render of the same path used when saving.
class _GradedPhotoPreview extends StatefulWidget {
  const _GradedPhotoPreview({
    required this.capturedBytes,
    required this.params,
  });

  final Uint8List capturedBytes;
  final ColorGradingParams params;

  @override
  State<_GradedPhotoPreview> createState() => _GradedPhotoPreviewState();
}

class _GradedPhotoPreviewState extends State<_GradedPhotoPreview> {
  static const _renderDelay = Duration(milliseconds: 250);

  Future<GradingPreviewSource>? _source;
  Timer? _debounce;
  ui.Image? _rendered;
  ColorGradingParams? _renderedParams;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _scheduleRender();
  }

  @override
  void didUpdateWidget(covariant _GradedPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.capturedBytes, widget.capturedBytes)) {
      _source = null;
      _clearRendered();
      _scheduleRender();
    } else if (oldWidget.params != widget.params) {
      _scheduleRender();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation += 1;
    _clearRendered();
    super.dispose();
  }

  void _clearRendered() {
    _rendered?.dispose();
    _rendered = null;
    _renderedParams = null;
  }

  void _scheduleRender() {
    _debounce?.cancel();
    _generation += 1;
    if (!widget.params.hasNonLinearAdjustments) {
      // The matrix is exact here; drop the stale render to free its memory.
      _clearRendered();
      return;
    }
    final params = widget.params;
    final generation = _generation;
    _debounce = Timer(_renderDelay, () => _render(params, generation));
  }

  Future<void> _render(ColorGradingParams params, int generation) async {
    ui.Image? image;
    try {
      final source = await (_source ??= prepareGradingPreviewSource(
        widget.capturedBytes,
      ));
      if (!mounted || generation != _generation) return;
      image = await renderGradedPreviewImage(source: source, params: params);
    } catch (error) {
      // Keep the matrix approximation if the low-resolution render fails.
      debugPrint('Color grading preview render failed: $error');
      return;
    }
    if (!mounted || generation != _generation) {
      image.dispose();
      return;
    }
    setState(() {
      _rendered?.dispose();
      _rendered = image;
      _renderedParams = params;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rendered = _rendered;
    if (rendered != null && _renderedParams == widget.params) {
      return RawImage(image: rendered, fit: BoxFit.contain);
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(widget.params.toColorMatrix()),
      child: BoundedImage(bytes: widget.capturedBytes),
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
        icon: Icon(showOriginal ? LucideIcons.eye : LucideIcons.eye),
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
                Icon(LucideIcons.wandSparkles, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSavedParams ? '已恢复上次调色参数' : '自动匹配后可保存调色结果',
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
                    _ScoreValue(label: '原图', score: beforeScore!),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    _ScoreValue(label: '当前', score: currentToneScore ?? 0),
                    Icon(
                      LucideIcons.arrowRight,
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
            style: TextStyle(
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
          Text(
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
                : const Icon(LucideIcons.save, size: 18),
            label: Text(saving ? '保存中...' : '保存调色结果'),
          ),
        ],
      ),
    );
  }
}
