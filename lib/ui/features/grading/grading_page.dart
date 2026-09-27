import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/records/color_grading_service.dart';
import '../../../application/records/record_details.dart';
import '../../../color_grading/color_adjustment.dart';
import '../../../color_grading/color_grading_params.dart';
import '../../../data/bounded_image_decoder.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../../widgets/bounded_image.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// 自动调色 (`/records/:recordId/grading`, DESIGN §8.17).
class GradingPage extends StatelessWidget {
  const GradingPage({required this.recordId, super.key});
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '自动调色',
        body: Center(child: ProgressRing(semanticLabel: '加载中')),
      );
    }
    final controller = session.controller;
    final record = controller.visitRecords
        .where((candidate) => candidate.id == recordId)
        .firstOrNull;
    if (record == null) {
      return MiriaPageScaffold(
        title: '自动调色',
        body: EmptyState(
          icon: Symbols.hide_image_rounded,
          title: '找不到这条记录',
          message: '记录可能已被删除。',
          actionLabel: '返回记录',
          onAction: () => context.go(Routes.records),
        ),
      );
    }
    return _GradingEditor(
      key: ValueKey('grading-$recordId'),
      record: record,
      controller: controller,
    );
  }
}

class _GradingEditor extends StatefulWidget {
  const _GradingEditor({
    required this.record,
    required this.controller,
    super.key,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePlanController controller;

  @override
  State<_GradingEditor> createState() => _GradingEditorState();
}

class _GradingEditorState extends State<_GradingEditor> {
  late final ColorGradingService _service;

  @override
  void initState() {
    super.initState();
    const details = RecordDetails();
    final point = widget.controller.pointById(widget.record.pointId);
    final controller = widget.controller;
    _service = ColorGradingService(
      record: widget.record,
      fallbackReferenceImagePath: details.referenceImagePath(
        widget.record,
        point,
      ),
      fallbackReferenceImageUrl: details.referenceImageUrl(
        widget.record,
        point,
      ),
      writer: GradingRecordWriter(
        repository: controller.repository,
        update: controller.updateVisitRecordColorGrading,
        clear: controller.clearVisitRecordColorGrading,
      ),
    )..addListener(_changed);
    unawaited(_service.load());
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    _service.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _toast(GradingNotice? notice) {
    if (notice == null || !mounted) return;
    context.showToast(
      notice.title,
      kind: switch (notice.kind) {
        GradingNoticeKind.success => ToastKind.success,
        GradingNoticeKind.warning => ToastKind.warning,
        GradingNoticeKind.error => ToastKind.error,
      },
    );
  }

  Future<void> _autoMatch() async {
    _toast(await _service.runAutoMatch());
  }

  Future<void> _save() async {
    final result = await _service.save();
    if (!mounted) return;
    _toast(result.notice);
    if (result.pop && context.canPop()) {
      context.pop(result.popWith);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '重置调色',
      message: '将清除当前调色，恢复为原图。',
      confirmLabel: '重置',
    );
    if (!confirmed || !mounted) return;
    _service.reset();
  }

  void _showParameters() {
    showAdaptiveSheet<void>(
      context,
      title: '调色参数',
      builder: (context) =>
          _ParameterList(items: gradingParameterItems(_service.activeParams)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _service;
    Widget body;
    if (s.loading) {
      body = const Center(child: ProgressRing(semanticLabel: '正在读取照片'));
    } else if (s.loadError != null || s.capturedBytes == null) {
      final error = s.loadError;
      body = ErrorState(
        icon: Symbols.broken_image_rounded,
        title: error is ImageBudgetException ? error.message : '图片暂不可用',
      );
    } else {
      body = EditorLayout(
        preview: _Preview(service: s),
        controls: _Controls(
          service: s,
          onAutoMatch: _autoMatch,
          onSave: _save,
          onShowParameters: _showParameters,
        ),
      );
    }
    return PopScope(
      canPop: !s.saving,
      child: MiriaPageScaffold(
        title: '自动调色',
        actions: [
          MiriaIconButton(
            key: const ValueKey('grading-reset'),
            icon: Symbols.restart_alt_rounded,
            tooltip: '重置',
            onPressed: s.saving ? null : _confirmReset,
          ),
        ],
        body: body,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.service});

  final ColorGradingService service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final captured = s.capturedBytes!;
    final showOriginal = s.previewShowsOriginal;
    final result = _PreviewPane(
      key: const ValueKey('grading-result'),
      label: showOriginal ? '原图' : '调色后',
      child: Listener(
        onPointerDown: s.hasParams ? (_) => s.setShowOriginal(true) : null,
        onPointerUp: s.hasParams ? (_) => s.setShowOriginal(false) : null,
        onPointerCancel: s.hasParams ? (_) => s.setShowOriginal(false) : null,
        child: showOriginal
            ? BoundedImage(bytes: captured)
            : _GradedPhotoPreview(
                capturedBytes: captured,
                params: s.activeParams,
              ),
      ),
    );
    final referenceBytes = s.referenceBytes;
    final referenceError = s.referenceError;
    final reference = _PreviewPane(
      key: const ValueKey('grading-reference'),
      label: '参考图',
      child: referenceBytes != null
          ? BoundedImage(bytes: referenceBytes)
          : referenceError != null
          ? BoundedImageError(error: referenceError)
          : Center(child: Text('没有参考图', style: context.text.bodySmall)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Space.x3;
        final padding = EdgeInsets.all(
          constraints.maxWidth < 480 ? Space.x2 : Space.x4,
        );
        final wide = constraints.maxWidth >= 560;
        if (!wide) {
          // Small reference inset over a large result.
          return Padding(
            padding: padding,
            child: Stack(
              fit: StackFit.expand,
              children: [
                result,
                Positioned(
                  right: Space.x2,
                  bottom: Space.x2,
                  width: constraints.maxWidth * 0.34,
                  height: constraints.maxWidth * 0.34 * 9 / 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: Radii.smAll,
                      boxShadow: Elevations.level2(context.colors),
                    ),
                    child: reference,
                  ),
                ),
              ],
            ),
          );
        }
        final landscape = constraints.maxWidth > constraints.maxHeight * 1.6;
        return Padding(
          padding: padding,
          child: Flex(
            direction: landscape ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: reference),
              SizedBox(width: gap, height: gap),
              Expanded(flex: 3, child: result),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: Radii.smAll,
      child: ColoredBox(
        color: c.surfaceSunken,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: child),
            Positioned(
              left: Space.x2,
              top: Space.x2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.scrim,
                    borderRadius: Radii.xsAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x2,
                      vertical: 2,
                    ),
                    child: Text(
                      label,
                      style: context.text.labelSmall?.copyWith(
                        color: c.onDarkroom,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour-matrix preview immediately; when tone zones or RGB curves are
/// active, a debounced (250 ms) low-resolution render of the save path.
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.service,
    required this.onAutoMatch,
    required this.onSave,
    required this.onShowParameters,
  });

  final ColorGradingService service;
  final VoidCallback onAutoMatch;
  final VoidCallback onSave;
  final VoidCallback onShowParameters;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final c = context.colors;
    final text = context.text;
    return SafeArea(
      top: false,
      child: ListView(
        key: const ValueKey('grading-controls'),
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x4,
          Space.x4,
          Space.x6,
        ),
        children: [
          _HoldOriginalButton(service: s),
          const SizedBox(height: Space.x4),
          Text('匹配模式', style: text.titleSmall),
          const SizedBox(height: Space.x2),
          SegmentedControl<ColorMatchMode>(
            semanticLabel: '匹配模式',
            collapseToIcons: false,
            options: [
              for (final mode in ColorMatchMode.values)
                SegmentOption(value: mode, label: mode.label),
            ],
            value: s.selectedMode,
            onChanged: s.matching || s.saving ? null : s.selectMode,
          ),
          const SizedBox(height: Space.x3),
          _ScorePanel(service: s),
          const SizedBox(height: Space.x3),
          MiriaButton(
            key: const ValueKey('grading-auto-match'),
            label: s.matching ? '匹配中...' : '自动匹配色调',
            icon: Symbols.auto_fix_high_rounded,
            loading: s.matching,
            expand: true,
            onPressed: s.matching || s.saving ? null : onAutoMatch,
          ),
          if (s.hasParams) ...[
            const SizedBox(height: Space.x3),
            MiriaCard(
              padding: EdgeInsets.zero,
              child: SliderRow(
                key: const ValueKey('grading-intensity'),
                title: '调色强度',
                value: s.intensity,
                divisions: 100,
                format: (value) => '${(value * 100).round()}%',
                onChanged: s.saving ? null : s.setIntensity,
              ),
            ),
            const SizedBox(height: Space.x3),
            MiriaCard(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                Space.x3,
                Space.x2,
                Space.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('调色参数', style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text('显示当前调色强度下实际生效的参数。', style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  MiriaButton.ghost(
                    key: const ValueKey('grading-parameters'),
                    label: '查看',
                    icon: Symbols.tune_rounded,
                    size: MiriaButtonSize.sm,
                    onPressed: onShowParameters,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.x3),
          MiriaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('保存结果', style: text.titleSmall),
                const SizedBox(height: Space.x1),
                Text(
                  '保存后记录详情和导出会使用调色后的图片，原图和调色参数会保留。',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.x3),
                MiriaButton(
                  key: const ValueKey('grading-save'),
                  label: s.saving ? '保存中...' : '保存调色结果',
                  icon: Symbols.save_rounded,
                  loading: s.saving,
                  expand: true,
                  onPressed: s.saving || s.matching ? null : onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldOriginalButton extends StatelessWidget {
  const _HoldOriginalButton({required this.service});

  final ColorGradingService service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final enabled = s.hasParams;
    return Listener(
      onPointerDown: enabled ? (_) => s.setShowOriginal(true) : null,
      onPointerUp: enabled ? (_) => s.setShowOriginal(false) : null,
      onPointerCancel: enabled ? (_) => s.setShowOriginal(false) : null,
      child: MiriaButton.secondary(
        key: const ValueKey('grading-hold-original'),
        label: s.showOriginal ? '正在显示原图' : '按住显示原图',
        icon: Symbols.visibility_rounded,
        expand: true,
        onPressed: enabled ? () {} : null,
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.service});

  final ColorGradingService service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final c = context.colors;
    final text = context.text;
    final before = s.beforeScore;
    final after = s.afterScore;
    if (before == null || after == null) {
      return MiriaCard(
        key: const ValueKey('grading-score'),
        child: Row(
          children: [
            Icon(Symbols.auto_fix_high_rounded, color: c.primaryText),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(
                s.hasParams ? '已恢复上次调色参数' : '自动匹配后可保存调色结果',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    Widget value(String label, int score) => Expanded(
      child: Column(
        children: [
          Text(
            '$score',
            style: text.numeric(
              text.headlineSmall!.copyWith(color: c.primaryText),
            ),
          ),
          Text(label, style: text.caption),
        ],
      ),
    );
    final arrow = Icon(
      Symbols.arrow_forward_rounded,
      size: 18,
      color: c.textTertiary,
    );
    return MiriaCard(
      key: const ValueKey('grading-score'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('色调匹配', style: text.titleSmall),
          const SizedBox(height: Space.x2),
          Row(
            children: [
              value('原图', before),
              arrow,
              value('当前', s.currentToneScore ?? 0),
              arrow,
              value('100%', after),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParameterList extends StatelessWidget {
  const _ParameterList({required this.items});

  final List<GradingParameterItem> items;

  String _range(GradingParameterItem item) {
    String f(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 1 : 2);
    return '${f(item.min)} ~ ${f(item.max)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: Space.x5, color: c.hairline),
          Semantics(
            label: items[i].label,
            value: items[i].value.toStringAsFixed(3),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(items[i].label, style: text.titleSmall),
                      ),
                      Text(
                        items[i].value.toStringAsFixed(3),
                        style: text.numeric(
                          text.labelLarge!.copyWith(color: c.primaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x2),
                  ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: LinearProgressIndicator(
                      value: items[i].fraction,
                      minHeight: 6,
                      color: c.primary,
                      backgroundColor: c.surfaceMuted,
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text('范围 ${_range(items[i])}', style: text.caption),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
