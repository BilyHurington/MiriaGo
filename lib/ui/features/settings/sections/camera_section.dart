import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/platform_capabilities.dart';
import '../../../../application/settings/settings_options.dart';
import '../../../../application/settings_store.dart';
import '../../../../camera_reference/camera_zoom_capabilities.dart';
import '../../../../plan/pilgrimage_models.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// 拍摄设置: capture/fallback aspect ratios, reference size, zoom range,
/// photo location and gallery backup.
class CameraSettingsSection extends StatefulWidget {
  const CameraSettingsSection({super.key});

  @override
  State<CameraSettingsSection> createState() => _CameraSettingsSectionState();
}

class _CameraSettingsSectionState extends State<CameraSettingsSection> {
  CameraZoomCapabilities _zoom = CameraZoomCapabilities.fallback;

  @override
  void initState() {
    super.initState();
    unawaited(_loadZoomCapabilities());
  }

  Future<void> _loadZoomCapabilities() async {
    final capabilities = await CameraZoomCapabilities.load();
    if (!mounted) return;
    setState(() => _zoom = capabilities);
  }

  Future<void> _editCustomRatio({required bool fallbackRatio}) async {
    final store = context.read<SettingsStore>();
    final result = await showDialog<({double width, double height})>(
      context: context,
      builder: (_) => CustomAspectRatioDialog(
        initialWidth: store.settings.customCameraAspectRatioWidth,
        initialHeight: store.settings.customCameraAspectRatioHeight,
      ),
    );
    if (result == null) return;
    await store.patch(
      (s) => applyCustomAspectRatio(
        s,
        width: result.width,
        height: result.height,
        fallbackRatio: fallbackRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    final capabilities = context.read<PlatformCapabilities>();
    final zoomRange = cameraZoomRange(settings, _zoom);
    final zoomSlider = cameraZoomSliderValues(settings, _zoom);
    final minLabel = '${zoomRange.minZoom.toStringAsFixed(1)}x';
    final maxLabel = '${zoomRange.maxZoom.toStringAsFixed(1)}x';

    List<OptionTileData<CameraPhotoAspectRatio>> tiles(
      List<CameraPhotoAspectRatio> ratios,
    ) => [
      for (final ratio in ratios)
        OptionTileData(
          value: ratio,
          label: ratio.shortLabel,
          hint: ratio.settingHintLabel,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: '拍摄图片比例',
          subtitle: '自动会优先跟随参考图比例；选择固定比例后会按该比例拍摄。',
          children: [
            SettingsBlock(
              child: OptionTileGrid<CameraPhotoAspectRatio>(
                key: const ValueKey('capture-aspect-ratio-grid'),
                options: tiles(captureAspectRatioOptions),
                selected: settings.cameraCaptureAspectRatio,
                onSelected: (ratio) => store.patch(
                  (s) => s.copyWith(cameraCaptureAspectRatio: ratio),
                ),
                trailing: [
                  _customTile(
                    settings,
                    selected:
                        settings.cameraCaptureAspectRatio ==
                        CameraPhotoAspectRatio.custom,
                    fallbackRatio: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '无参考图时比例',
          subtitle: '拍摄图片比例为自动、且没有参考图可对齐时使用。',
          children: [
            SettingsBlock(
              child: OptionTileGrid<CameraPhotoAspectRatio>(
                key: const ValueKey('fallback-aspect-ratio-grid'),
                options: tiles(fallbackAspectRatioOptions),
                selected: settings.cameraFallbackAspectRatio,
                onSelected: (ratio) => store.patch(
                  (s) => s.copyWith(cameraFallbackAspectRatio: ratio),
                ),
                trailing: [
                  _customTile(
                    settings,
                    selected:
                        settings.cameraFallbackAspectRatio ==
                        CameraPhotoAspectRatio.custom,
                    fallbackRatio: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            ScaleSliderRow(
              title: '参考图显示',
              icon: Symbols.photo_size_select_large_rounded,
              value: settings.referenceImageScale.clamp(0.8, 1.0),
              min: 0.8,
              max: 1.0,
              divisions: 4,
              tickLabels: const ['80%', '85%', '90%', '95%', '100%'],
              onChanged: (value) =>
                  store.patch((s) => s.copyWith(referenceImageScale: value)),
            ),
          ],
        ),
        SettingsGroup(
          title: '相机缩放 $minLabel - $maxLabel',
          subtitle:
              '设备支持 ${zoomRange.rangeMin.toStringAsFixed(1)}x - ${zoomRange.rangeMax.toStringAsFixed(1)}x',
          children: [
            SettingsBlock(
              child: Semantics(
                label: '相机缩放范围',
                child: RangeSlider(
                  key: const ValueKey('camera-zoom-range-slider'),
                  min: 0,
                  max: 1,
                  divisions: 200,
                  values: RangeValues(zoomSlider.start, zoomSlider.end),
                  labels: RangeLabels(minLabel, maxLabel),
                  semanticFormatterCallback: (value) =>
                      '${realZoomFromCameraSliderValue(minZoom: zoomRange.rangeMin, maxZoom: zoomRange.rangeMax, sliderValue: value).toStringAsFixed(1)}x',
                  onChanged: (values) {
                    final next = applyCameraZoomSlider(
                      settings,
                      _zoom,
                      start: values.start,
                      end: values.end,
                    );
                    if (next.cameraMinZoom == settings.cameraMinZoom &&
                        next.cameraMaxZoom == settings.cameraMaxZoom) {
                      return;
                    }
                    store.patch(
                      (s) => s.copyWith(
                        cameraMinZoom: next.cameraMinZoom,
                        cameraMaxZoom: next.cameraMaxZoom,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (capabilities.showsPhotoLocationSettings)
          SettingsGroup(
            title: '照片定位信息',
            children: [
              SettingsBlock(
                child: SelectField<PhotoLocationStrategy>(
                  key: const ValueKey('photo-location-strategy'),
                  pickerTitle: '照片定位信息',
                  value: settings.photoLocationStrategy,
                  options: [
                    for (final strategy in PhotoLocationStrategy.values)
                      SelectOption(
                        value: strategy,
                        label: photoLocationStrategyMenuLabel(strategy),
                        subtitle:
                            '${photoLocationStrategyBadge(strategy)} · ${photoLocationStrategyDescription(strategy)}',
                      ),
                  ],
                  onChanged: (strategy) => store.patch(
                    (s) => s.copyWith(photoLocationStrategy: strategy),
                  ),
                ),
              ),
              SettingsBlock(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(
                      label: photoLocationStrategyBadge(
                        settings.photoLocationStrategy,
                      ),
                      tone: MiriaTone.primary,
                    ),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Text(
                        photoLocationStrategyDescription(
                          settings.photoLocationStrategy,
                        ),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (capabilities.canSaveToGallery)
          SettingsGroup(
            title: '照片备份',
            children: [
              SwitchRow(
                leading: const Icon(Symbols.backup_rounded),
                title: '保存巡礼照片到相册',
                subtitle: '保存记录时同时备份一张巡礼照片。',
                value: settings.saveVisitPhotoToGallery,
                onChanged: (value) => store.patch(
                  (s) => s.copyWith(saveVisitPhotoToGallery: value),
                ),
              ),
            ],
          ),
      ],
    );
  }

  OptionTile _customTile(
    AppSettings settings, {
    required bool selected,
    required bool fallbackRatio,
  }) {
    return OptionTile(
      key: ValueKey(
        fallbackRatio ? 'fallback-aspect-custom' : 'capture-aspect-custom',
      ),
      label: '自定义',
      hint: selected
          ? '${formatRatioNumber(settings.customCameraAspectRatioWidth)}:${formatRatioNumber(settings.customCameraAspectRatioHeight)}'
          : null,
      selected: selected,
      onTap: () => _editCustomRatio(fallbackRatio: fallbackRatio),
    );
  }
}

/// 自定义比例 dialog (宽 : 高). Both ratio settings share the values.
class CustomAspectRatioDialog extends StatefulWidget {
  const CustomAspectRatioDialog({
    required this.initialWidth,
    required this.initialHeight,
    super.key,
  });

  final double initialWidth;
  final double initialHeight;

  @override
  State<CustomAspectRatioDialog> createState() =>
      _CustomAspectRatioDialogState();
}

class _CustomAspectRatioDialogState extends State<CustomAspectRatioDialog> {
  late final TextEditingController _width = TextEditingController(
    text: formatRatioNumber(widget.initialWidth),
  );
  late final TextEditingController _height = TextEditingController(
    text: formatRatioNumber(widget.initialHeight),
  );
  String? _error;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _submit() {
    final ratio = parseCustomAspectRatio(_width.text, _height.text);
    if (ratio == null) {
      setState(() => _error = '请输入有效比例');
      return;
    }
    Navigator.of(context).pop(ratio);
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    const keyboard = TextInputType.numberWithOptions(decimal: true);
    final formatters = <TextInputFormatter>[decimalInputFormatter];
    return MiriaDialog(
      title: '自定义比例',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MiriaTextField(
                  key: const ValueKey('custom-ratio-width'),
                  label: '宽',
                  controller: _width,
                  keyboardType: keyboard,
                  inputFormatters: formatters,
                  onChanged: _clearError,
                  autofocus: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x3,
                  vertical: Space.x3,
                ),
                child: Text(':', style: context.text.titleLarge),
              ),
              Expanded(
                child: MiriaTextField(
                  key: const ValueKey('custom-ratio-height'),
                  label: '高',
                  controller: _height,
                  keyboardType: keyboard,
                  inputFormatters: formatters,
                  onChanged: _clearError,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.danger,
              ),
            ),
          ],
        ],
      ),
      actions: DialogActionRow(
        confirmLabel: '保存',
        onConfirm: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
