import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/records/comparison_export_service.dart';
import '../../../application/records/record_details.dart';
import '../../../application/settings_store.dart';
import '../../../data/anitabi_image_source_scope.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../records/comparison_export_config.dart';
import '../../../records/comparison_export_renderer.dart';
import '../../../records/comparison_exporter_stub.dart'
    if (dart.library.io) '../../../records/comparison_exporter_io.dart'
    if (dart.library.js_interop) '../../../records/comparison_exporter_web.dart';
import '../../../widgets/bounded_image.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../viewer/image_viewer.dart';

/// Persistence hooks bound to the settings store, so the comparison fields
/// are patched onto the latest settings and nothing else is overwritten.
ComparisonExportService _serviceFor(
  BuildContext context, {
  ComparisonImageExporter? exporter,
}) {
  final store = context.read<SettingsStore>();
  return ComparisonExportService(
    loadConfig: () async {
      final settings = store.isLoaded
          ? store.settings
          : await store.repository.loadAppSettings();
      return ComparisonExportConfig.fromSettings(settings);
    },
    saveConfig: (config) => store.patch(config.applyToSettings),
    exporter: exporter,
  );
}

/// Opens the 「导出对比图」 adaptive panel for [record].
/// OWNER: feature agent E (records).
Future<void> showComparisonExport(
  BuildContext context, {
  required PilgrimageVisitRecord record,
}) async {
  final session = context.read<PlanSession>();
  if (!session.isReady) return;
  final controller = session.controller;
  final point = controller.pointById(record.pointId);
  final capturedPath = RecordDetails.displayPhotoPath(record);
  if (capturedPath == null) {
    context.showToast('巡礼图不可用，无法导出对比图片。', kind: ToastKind.warning);
    return;
  }
  if (controller.repository == null) {
    context.showToast('当前平台暂不支持保存导出偏好。', kind: ToastKind.warning);
    return;
  }
  const details = RecordDetails();
  final request = ComparisonExportRequest(
    referenceImagePath: details.referenceImagePath(record, point),
    referenceImageUrl: details.referenceImageUrl(record, point),
    capturedPath: capturedPath,
    metadata: RecordDetails.comparisonMetadata(record, point),
    colorGradingSummary: RecordDetails.colorGradingSummary(record),
  );
  final service = _serviceFor(context, exporter: exportComparisonImage);
  final outcome = await showAdaptivePanel<ComparisonExportOutcome>(
    context,
    title: '导出对比图',
    dismissible: false,
    actions: [
      ListenableBuilder(
        listenable: service,
        builder: (actionContext, _) => MiriaIconButton(
          key: const ValueKey('comparison-export-close'),
          icon: Symbols.close_rounded,
          tooltip: '关闭',
          onPressed: service.busy
              ? null
              : () => Navigator.of(actionContext).pop(),
        ),
      ),
    ],
    builder: (panelContext) =>
        ComparisonExportPanel(service: service, request: request),
  );
  // Listeners detach while the route animates out; nothing notifies after.
  service.dispose();
  if (outcome == null || !context.mounted) return;
  switch (outcome.kind) {
    case ComparisonExportOutcomeKind.downloaded:
      context.showToast(
        ComparisonExportService.downloadedMessage,
        kind: ToastKind.success,
      );
    case ComparisonExportOutcomeKind.localFile:
      await openImageViewer(
        context,
        images: [ViewerImage(path: outcome.path, label: '对比图')],
      );
    case ComparisonExportOutcomeKind.none:
    case ComparisonExportOutcomeKind.failed:
      break;
  }
}

/// Body of the export panel: settings (and a live preview on wide
/// windows) plus 取消 / 导出对比图. Pops with the outcome on success.
class ComparisonExportPanel extends StatefulWidget {
  const ComparisonExportPanel({
    required this.service,
    required this.request,
    super.key,
  });

  final ComparisonExportService service;
  final ComparisonExportRequest request;

  @override
  State<ComparisonExportPanel> createState() => _ComparisonExportPanelState();
}

class _ComparisonExportPanelState extends State<ComparisonExportPanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.service.config.pilgrimName,
  );

  ComparisonExportService get _service => widget.service;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    unawaited(_load());
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final error = await _service.load();
    if (!mounted) return;
    if (error != null) {
      _toastError(error);
      return;
    }
    _name.text = _service.config.pilgrimName;
  }

  void _toastError(String message) {
    if (!mounted || _service.exiting) return;
    context.showToast(message, kind: ToastKind.error);
  }

  Future<void> _update(ComparisonExportConfig config) async {
    final error = await _service.update(config);
    if (error != null) _toastError(error);
  }

  Future<void> _export() async {
    final outcome = await _service.export(widget.request);
    if (!mounted) return;
    switch (outcome.kind) {
      case ComparisonExportOutcomeKind.failed:
        _toastError(outcome.message!);
      case ComparisonExportOutcomeKind.localFile:
      case ComparisonExportOutcomeKind.downloaded:
        Navigator.of(context).pop(outcome);
      case ComparisonExportOutcomeKind.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _service;
    final c = context.colors;
    final editor = ComparisonExportEditor(
      config: s.config,
      pilgrimNameController: _name,
      enabled: !s.locked,
      loading: s.loading,
      onChanged: _update,
    );
    final footer = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x3,
          Space.x4,
          Space.x3,
        ),
        child: Row(
          children: [
            Expanded(
              child: MiriaButton.secondary(
                key: const ValueKey('comparison-export-cancel'),
                label: '取消',
                expand: true,
                onPressed: s.busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              flex: 2,
              child: MiriaButton(
                key: const ValueKey('comparison-export-confirm'),
                label: '导出对比图',
                shortLabel: '导出',
                icon: Symbols.download_rounded,
                semanticLabel: '导出对比图',
                expand: true,
                loading: s.exporting || s.exiting,
                onPressed: s.busy ? null : _export,
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // System back closes the panel while idle (old behaviour); the
        // panel is never dismissible by dragging or tapping outside.
        if (!didPop && !_service.busy) Navigator.of(context).pop();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final settings = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('comparison-export-scroll'),
                  padding: const EdgeInsets.fromLTRB(
                    Space.x4,
                    Space.x4,
                    Space.x4,
                    Space.x5,
                  ),
                  child: editor,
                ),
              ),
              footer,
            ],
          );
          if (!wide) return settings;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: c.surfaceMuted,
                  child: _LivePreview(
                    request: widget.request,
                    config: s.config,
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: c.hairline),
              SizedBox(width: 400, child: settings),
            ],
          );
        },
      ),
    );
  }
}

/// Self-contained comparison export settings editor (loads and saves the
/// settings itself). Embedded by the 对比图设置 page. Scrolls itself when
/// given a bounded height; otherwise sizes to its content.
/// OWNER: feature agent E (records).
class ComparisonExportSettingsPanel extends StatefulWidget {
  const ComparisonExportSettingsPanel({this.padding, super.key});

  /// Padding around the editor (defaults to none).
  final EdgeInsetsGeometry? padding;

  @override
  State<ComparisonExportSettingsPanel> createState() =>
      _ComparisonExportSettingsPanelState();
}

class _ComparisonExportSettingsPanelState
    extends State<ComparisonExportSettingsPanel> {
  late final ComparisonExportService _service = _serviceFor(context);
  late final TextEditingController _name = TextEditingController(
    text: _service.config.pilgrimName,
  );

  /// 「读取导出设置失败，请重试。」 while the saved settings couldn't be read
  /// (the editor stays locked until a retry succeeds).
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    unawaited(_load());
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    _service.dispose();
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (_loadError != null) setState(() => _loadError = null);
    final error = await _service.load();
    if (!mounted) return;
    if (error != null) {
      setState(() => _loadError = error);
      return;
    }
    _name.text = _service.config.pilgrimName;
  }

  Future<void> _update(ComparisonExportConfig config) async {
    final error = await _service.update(config);
    if (error != null && mounted) {
      context.showToast(error, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadError = _loadError;
    final editor = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loadError != null) ...[
            InfoBanner(
              key: const ValueKey('comparison-settings-load-error'),
              kind: InfoBannerKind.error,
              message: loadError,
              actionLabel: '重试',
              onAction: () => unawaited(_load()),
            ),
            const SizedBox(height: Space.x3),
          ],
          ComparisonExportEditor(
            key: const ValueKey('comparison-settings-editor'),
            config: _service.config,
            pilgrimNameController: _name,
            enabled: !_service.locked,
            loading: _service.loading,
            onChanged: _update,
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SingleChildScrollView(child: editor)
          : editor,
    );
  }
}

/// All options of the old `ComparisonExportConfigEditor`.
class ComparisonExportEditor extends StatelessWidget {
  const ComparisonExportEditor({
    required this.config,
    required this.pilgrimNameController,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
    super.key,
  });

  final ComparisonExportConfig config;
  final TextEditingController pilgrimNameController;
  final ValueChanged<ComparisonExportConfig> onChanged;
  final bool enabled;
  final bool loading;

  static IconData metadataIcon(ComparisonMetadataField field) =>
      switch (field) {
        ComparisonMetadataField.capturedAt => Symbols.schedule_rounded,
        ComparisonMetadataField.pointName => Symbols.location_on_rounded,
        ComparisonMetadataField.workTitle => Symbols.movie_rounded,
        ComparisonMetadataField.episodeLabel => Symbols.landscape_rounded,
        ComparisonMetadataField.coordinates => Symbols.my_location_rounded,
        ComparisonMetadataField.anitabiId => Symbols.tag_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final change = enabled ? onChanged : null;
    final automaticOutput = config.outputWidth == ComparisonOutputWidth.auto;
    const rowPadding = EdgeInsets.symmetric(vertical: Space.x2);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(bottom: Space.x2),
      child: Semantics(
        header: true,
        child: Text(title, style: text.titleMedium),
      ),
    );
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x3),
      child: Divider(height: 1, color: c.hairline),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          LinearProgressIndicator(
            minHeight: 2,
            color: c.primary,
            backgroundColor: c.primaryContainer,
          ),
          const SizedBox(height: Space.x3),
        ],
        section('外观'),
        SliderRow(
          key: const ValueKey('comparison-border-width'),
          padding: rowPadding,
          title: '边框宽度',
          value: config.borderWidthPercent,
          min: 0,
          max: 3,
          divisions: 30,
          format: ComparisonExportService.borderWidthLabel,
          onChanged: change == null
              ? null
              : (value) => change(config.copyWith(borderWidthPercent: value)),
        ),
        const SizedBox(height: Space.x2),
        Text('边框颜色', style: text.bodyLarge),
        const SizedBox(height: Space.x2),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            for (
              var i = 0;
              i < ComparisonExportService.borderColorLabels.length;
              i++
            )
              _ColorOption(
                key: ValueKey('comparison-border-color-$i'),
                color: ComparisonExportService.borderColorOptions[i],
                label: ComparisonExportService.borderColorLabels[i],
                selected:
                    config.borderColor.toARGB32() ==
                    ComparisonExportService.borderColorOptions[i].toARGB32(),
                onTap: change == null
                    ? null
                    : () => change(
                        config.copyWith(
                          borderColor:
                              ComparisonExportService.borderColorOptions[i],
                        ),
                      ),
              ),
          ],
        ),
        divider(),
        SwitchRow(
          key: const ValueKey('comparison-output-auto'),
          padding: rowPadding,
          title: '自动输出宽度',
          subtitle: '根据图片尺寸自动确定输出宽度',
          value: automaticOutput,
          onChanged: change == null
              ? null
              : (useAutomatic) => change(
                  config.copyWith(
                    outputWidth: useAutomatic
                        ? ComparisonOutputWidth.auto
                        : ComparisonOutputWidth.w1920,
                  ),
                ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.standard),
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: automaticOutput
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.x2),
                  child: SegmentedControl<ComparisonOutputWidth>(
                    key: const ValueKey('comparison-output-width'),
                    semanticLabel: '输出宽度',
                    collapseToIcons: false,
                    options: [
                      for (final width
                          in ComparisonExportService.fixedOutputWidths)
                        SegmentOption(value: width, label: width.label),
                    ],
                    value: config.outputWidth,
                    onChanged: change == null
                        ? null
                        : (width) =>
                              change(config.copyWith(outputWidth: width)),
                  ),
                ),
        ),
        divider(),
        SwitchRow(
          key: const ValueKey('comparison-show-labels'),
          padding: rowPadding,
          title: '显示标签',
          subtitle: '在参考图上显示“参考”字样，在你拍的巡礼图上显示“巡礼”字样',
          value: config.showLabels,
          onChanged: change == null
              ? null
              : (value) => change(config.copyWith(showLabels: value)),
        ),
        divider(),
        SelectField<ComparisonImageEncoding>(
          key: const ValueKey('comparison-encoding'),
          label: '图片格式与质量',
          options: [
            for (final encoding in ComparisonImageEncoding.values)
              SelectOption(value: encoding, label: encoding.label),
          ],
          value: config.imageEncoding,
          onChanged: change == null
              ? null
              : (value) => change(config.copyWith(imageEncoding: value)),
        ),
        const SizedBox(height: Space.x6),
        section('元数据'),
        SwitchRow(
          key: const ValueKey('comparison-show-pilgrim-name'),
          padding: rowPadding,
          title: '显示巡礼者名字',
          subtitle: '在图片上显示巡礼者名字',
          value: config.showPilgrimName,
          onChanged: change == null
              ? null
              : (value) => change(config.copyWith(showPilgrimName: value)),
        ),
        const SizedBox(height: Space.x2),
        AnimatedOpacity(
          duration: Motion.of(context, Motion.standard),
          opacity: config.showPilgrimName ? 1 : 0.45,
          child: MiriaTextField(
            key: const ValueKey('comparison-pilgrim-name'),
            controller: pilgrimNameController,
            hint: '请输入巡礼者名字',
            enabled: enabled && config.showPilgrimName,
            textInputAction: TextInputAction.done,
            onChanged: change == null
                ? null
                : (value) => change(config.copyWith(pilgrimName: value)),
          ),
        ),
        divider(),
        SwitchRow(
          key: const ValueKey('comparison-show-grading'),
          padding: rowPadding,
          title: '显示调色参数',
          subtitle: '在图片底部显示调色相关参数',
          value: config.showColorGradingParams,
          onChanged: change == null
              ? null
              : (value) =>
                    change(config.copyWith(showColorGradingParams: value)),
        ),
        divider(),
        section('显示内容'),
        ChipGroup<ComparisonMetadataField>(
          key: const ValueKey('comparison-metadata-fields'),
          semanticLabel: '显示内容',
          options: [
            for (final field in ComparisonExportService.metadataFieldOrder)
              ChipOption(
                value: field,
                label: field.label,
                icon: metadataIcon(field),
              ),
          ],
          selected: config.metadataFields,
          onChanged: change == null
              ? null
              : (fields) => change(config.copyWith(metadataFields: fields)),
        ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaPressable(
      onTap: onTap,
      enabled: onTap != null,
      selected: selected,
      borderRadius: Radii.smAll,
      semanticLabel: '边框颜色：$label',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minWidth: 76, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surface,
          borderRadius: Radii.smAll,
          border: Border.all(
            color: selected ? c.primary : c.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User-chosen export colours (exception to "token colours only").
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: c.hairlineStrong),
              ),
              child: selected
                  ? Icon(
                      Symbols.check_rounded,
                      size: 14,
                      color: color.computeLuminance() > 0.55
                          ? c.textPrimary
                          : c.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: Space.x2),
            Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: selected ? c.onPrimaryContainer : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P2: debounced low-resolution render of the comparison with the current
/// settings (same renderer as the export).
class _LivePreview extends StatefulWidget {
  const _LivePreview({required this.request, required this.config});

  final ComparisonExportRequest request;
  final ComparisonExportConfig config;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  static const _delay = Duration(milliseconds: 400);

  Future<(Uint8List?, Uint8List)>? _sources;
  Timer? _debounce;
  Uint8List? _image;
  bool _failed = false;
  int _generation = 0;

  AnitabiImageSource _imageSource = AnitabiImageSource.auto;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _imageSource = AnitabiImageSourceScope.of(context);
    if (_sources == null && _debounce == null) _schedule();
  }

  @override
  void didUpdateWidget(covariant _LivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  Future<(Uint8List?, Uint8List)> _loadSources() async {
    final source = _imageSource;
    final request = widget.request;
    Uint8List? reference;
    for (final path in [
      request.referenceImagePath,
      request.referenceImageUrl,
    ].whereType<String>()) {
      try {
        reference = await readBoundedImageSource(path, source: source);
        break;
      } catch (_) {}
    }
    final captured = await readBoundedImageSource(request.capturedPath);
    return (reference, captured);
  }

  void _schedule() {
    _debounce?.cancel();
    final generation = ++_generation;
    _debounce = Timer(_delay, () => _render(generation));
  }

  Future<void> _render(int generation) async {
    try {
      final (reference, captured) = await (_sources ??= _loadSources());
      if (!mounted || generation != _generation) return;
      final encoded = await const ComparisonExportRenderer().renderEncoded(
        referenceBytes: reference,
        capturedBytes: captured,
        config: widget.config.copyWith(
          outputWidth: ComparisonOutputWidth.w1080,
          imageEncoding: ComparisonImageEncoding.jpegRecommended,
        ),
        metadata: widget.request.metadata,
        colorGradingSummary: widget.request.colorGradingSummary,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _image = encoded.bytes;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = _image;
    Widget child;
    if (image != null) {
      child = Image.memory(
        image,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: '对比图预览',
      );
    } else if (_failed) {
      child = const EmptyState(
        compact: true,
        icon: Symbols.broken_image_rounded,
        title: '预览不可用',
        message: '仍可以直接导出对比图。',
      );
    } else {
      child = const Center(child: ProgressRing(semanticLabel: '正在生成预览'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x4, 0),
          child: Text(
            '预览',
            style: context.text.labelLarge?.copyWith(color: c.textSecondary),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.standard),
              child: KeyedSubtree(
                key: ValueKey(
                  image == null ? (_failed ? 'failed' : 'wait') : 'image',
                ),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
