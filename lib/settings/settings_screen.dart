import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../app_version.dart';
import '../camera_reference/camera_zoom_capabilities.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_cache_cleanup.dart';
import '../data/valhalla_service_config.dart';
import '../data/anitabi_service_config.dart';
import '../desktop/tauri_bridge.dart';
import '../map/map_tile_config.dart';
import '../map/valhalla_route_client.dart';
import '../plan/pilgrimage_models.dart';
import '../records/comparison_export_config.dart';
import '../records/comparison_export_config_editor.dart';
import '../records/comparison_export_config_storage_stub.dart'
    if (dart.library.io) '../records/comparison_export_config_storage_io.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_scaled_route.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/copyable_text.dart';
import '../widgets/input_dialog.dart';
import '../widgets/responsive_button.dart';
import '../widgets/snackbar_helper.dart';

bool get _showCacheCleanupSettings => isReferenceCacheCleanupSupported;
bool get _showDebugPhotoLocationSettings => false;
bool get _shouldShowMobileGallerySettings {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get _shouldShowPhotoLocationSettings =>
    kDebugMode ||
    _showDebugPhotoLocationSettings ||
    _shouldShowMobileGallerySettings;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.repository,
    required this.onChanged,
    super.key,
  });

  final AppSettings settings;
  final PilgrimageRepository repository;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CameraZoomCapabilities _zoomCapabilities = CameraZoomCapabilities.fallback;
  DesktopLauncherInfo? _desktopLauncherInfo;
  String? _appVersionLabel;
  var _desktopLauncherLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadZoomCapabilities();
    _loadAppVersionLabel();
    if (_shouldShowDesktopSection) {
      _loadDesktopLauncherInfo();
    }
  }

  Future<void> _loadZoomCapabilities() async {
    final capabilities = await CameraZoomCapabilities.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _zoomCapabilities = capabilities;
    });
  }

  Future<void> _loadDesktopLauncherInfo() async {
    final info = await loadDesktopLauncherInfo();
    if (!mounted) {
      return;
    }

    setState(() {
      _desktopLauncherInfo = info;
      _desktopLauncherLoaded = true;
    });
  }

  Future<void> _loadAppVersionLabel() async {
    final label = await loadAppVersionLabel();
    if (!mounted) {
      return;
    }

    setState(() {
      _appVersionLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        key: const ValueKey('settings-app-bar'),
        toolbarHeight: AppTheme.appBarHeight,
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const ValueKey('settings-reset-button'),
            tooltip: '恢复初始设置',
            onPressed: _confirmResetSettings,
            icon: const Icon(LucideIcons.rotateCcw),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsCard(
            key: const ValueKey('settings-appearance-card'),
            header: _SettingsCardHeader(
              icon: LucideIcons.palette,
              title: '外观设置',
              subtitle: '主题色、深浅色、缩放、显示等',
              onTap: () => _pushDetail(
                _AppearanceSettingsPage(
                  settings: settings,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            children: [
              _SummaryGrid(
                children: [
                  _SummaryTile(
                    icon: LucideIcons.circle,
                    title: '主题色',
                    value: settings.themePalette.label,
                    swatch: _ThemeSwatch(
                      palette: settings.themePalette,
                      customColorValue: settings.customThemeColorValue,
                    ),
                    onTap: () => _pushDetail(
                      _AppearanceSettingsPage(
                        settings: settings,
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ),
                  _SummaryTile(
                    icon: LucideIcons.moon,
                    title: '主题模式',
                    value: settings.themeMode.label,
                    onTap: () => _pushDetail(
                      _AppearanceSettingsPage(
                        settings: settings,
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: LucideIcons.camera,
              title: '拍摄设置',
              subtitle: '照片比例、参考图比例、备份等',
              onTap: () => _pushDetail(
                _CameraSettingsPage(
                  settings: settings,
                  onChanged: widget.onChanged,
                  zoomCapabilities: _zoomCapabilities,
                ),
              ),
            ),
            children: [
              _SummaryGrid(
                children: [
                  _SummaryTile(
                    icon: LucideIcons.crop,
                    title: '拍摄图片比例',
                    value: settings.cameraCaptureAspectRatio.label,
                    onTap: () => _pushDetail(
                      _CameraSettingsPage(
                        settings: settings,
                        onChanged: widget.onChanged,
                        zoomCapabilities: _zoomCapabilities,
                      ),
                    ),
                  ),
                  _SummaryTile(
                    icon: LucideIcons.panelRight,
                    title: '相机缩放',
                    value:
                        '${settings.cameraMinZoom.toStringAsFixed(1)}x-${settings.cameraMaxZoom.toStringAsFixed(1)}x',
                    onTap: () => _pushDetail(
                      _CameraSettingsPage(
                        settings: settings,
                        onChanged: widget.onChanged,
                        zoomCapabilities: _zoomCapabilities,
                      ),
                    ),
                  ),
                ],
              ),
              if (_shouldShowMobileGallerySettings)
                _SummarySwitchTile(
                  icon: LucideIcons.cloudUpload,
                  title: '照片备份',
                  subtitle: '保存巡礼照片到相册',
                  value: settings.saveVisitPhotoToGallery,
                  onChanged: (value) {
                    widget.onChanged(
                      settings.copyWith(saveVisitPhotoToGallery: value),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: LucideIcons.arrowLeftRight,
              title: '对比图设置',
              subtitle: '导出样式、自动保存到相册',
              onTap: () => _openComparisonStyleSettings(settings),
            ),
            children: [
              if (_shouldShowMobileGallerySettings) ...[
                _SummarySwitchTile(
                  icon: LucideIcons.images,
                  title: '自动保存对比图',
                  subtitle: '保存记录时保存到相册',
                  value: settings.autoSaveComparisonToGallery,
                  onChanged: (value) {
                    widget.onChanged(
                      settings.copyWith(autoSaveComparisonToGallery: value),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: LucideIcons.map,
              title: '数据源设置',
              subtitle: '地图源、图片源等',
              onTap: () => _pushDetail(
                _DataSourceSettingsPage(
                  settings: settings,
                  onChanged: widget.onChanged,
                  showMapUrlDialog: _showMapUrlDialog,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: LucideIcons.layers,
              title: '地图显示',
              subtitle: '点位、片区、聚合与缩略图',
              onTap: () => _pushDetail(
                _MapDisplaySettingsPage(
                  settings: settings,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ),
          if (_showCacheCleanupSettings) ...[
            const SizedBox(height: 12),
            _SettingsCard(
              header: _SettingsCardHeader(
                icon: LucideIcons.brushCleaning,
                title: '清除缓存',
                subtitle: '完整参考图缓存',
                onTap: () => _pushDetail(
                  _CacheCleanupSettingsPage(repository: widget.repository),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_shouldShowDesktopSection) ...[
            _SettingsCard(
              header: _SettingsCardHeader(
                icon: LucideIcons.monitor,
                title: '桌面端',
                subtitle: '启动器、数据目录等',
                onTap: () => _pushDetail(
                  _DesktopSettingsPage(
                    desktopLauncherInfo: _desktopLauncherInfo,
                    desktopLauncherStatusText: _desktopLauncherStatusText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: LucideIcons.info,
              title: '关于 MiriaGo',
              subtitle: '版本信息、开源许可等',
              onTap: () => _pushDetail(
                _AboutSettingsPage(appVersionLabel: _appVersionLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pushDetail(Widget page) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openComparisonStyleSettings(AppSettings settings) {
    return _pushDetail(
      _ComparisonStyleSettingsPage(
        repository: widget.repository,
        settings: settings,
        onChanged: widget.onChanged,
      ),
    );
  }

  Future<void> _confirmResetSettings() async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: '恢复初始设置',
      message: '所有外观、拍摄和地图设置将恢复为默认值。',
      confirmLabel: '恢复',
      notice: '恢复后仍可重新调整各项设置',
      emphasizedValues: const ['所有外观、拍摄和地图设置'],
    );
    if (!confirmed) {
      return;
    }
    const settings = AppSettings();
    ComparisonExportConfig.lastUsed = const ComparisonExportConfig();
    await widget.repository.saveAppSettings(settings);
    widget.onChanged(settings);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showStatusSnack(kind: AppStatusBannerKind.success, title: '已恢复初始设置');
    }
    await clearComparisonExportConfig();
  }

  String get _desktopLauncherStatusText {
    if (!_desktopLauncherLoaded) {
      return '桌面启动器 检查中';
    }
    final info = _desktopLauncherInfo;
    if (info == null || !isTauriLauncherAvailable) {
      return '桌面启动器 不可用';
    }
    final mode = info.platform == 'macos'
        ? '系统数据目录'
        : info.fallbackUsed
        ? '系统数据目录'
        : info.portable
        ? '便携目录'
        : '应用数据目录';
    return '桌面启动器 可用 / ${info.platform} / $mode';
  }

  bool get _shouldShowDesktopSection => kIsWeb;

  Future<void> _showMapUrlDialog({
    required String title,
    required String initialValue,
    required String helperText,
    required String? Function(String value) validator,
    required ValueChanged<String> onSaved,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AppInputDialog(
          title: title,
          content: Form(
            key: formKey,
            child: AppDialogField(
              label: 'URL 地址',
              child: TextFormField(
                onTapOutside: dismissKeyboardOnTapOutside,
                controller: controller,
                autofocus: true,
                decoration: appDialogInputDecoration(helperText: helperText),
                keyboardType: TextInputType.url,
                validator: (value) => validator(value ?? ''),
              ),
            ),
          ),
          confirmLabel: '保存',
          onConfirm: () {
            if (!formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(controller.text);
          },
        );
      },
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    onSaved(result);
  }
}

class _AppearanceSettingsPage extends StatefulWidget {
  const _AppearanceSettingsPage({
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<_AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<_AppearanceSettingsPage> {
  late AppSettings _settings;
  static const _visibleThemePalettes = [
    AppThemePalette.classicGreen,
    AppThemePalette.deepBlue,
    AppThemePalette.cherryPink,
    AppThemePalette.graphite,
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings settings) {
    applyAppColorsFromSettings(
      settings,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    setState(() {
      _settings = settings;
    });
    widget.onChanged(settings);
  }

  Future<void> _showCustomThemeColorDialog() async {
    final result = await showDialog<CustomThemeColor>(
      context: context,
      builder: (context) => _CustomThemeColorDialog(settings: _settings),
    );
    if (result == null) {
      return;
    }

    final colors = [
      ..._settings.customThemeColors.where(
        (color) => color.name != result.name && color.value != result.value,
      ),
      result,
    ];
    _update(
      _settings.copyWith(
        themePalette: AppThemePalette.aurora,
        customThemeColorName: result.name,
        customThemeColorValue: result.value,
        customThemeColors: colors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final uiScale = settings.uiScale.clamp(0.8, 1.0);
    final fontScale = settings.fontScale.clamp(0.8, 1.2);
    applyAppColorsFromSettings(
      settings,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );

    return Theme(
      data: appThemeFor(
        settings,
        platformBrightness: MediaQuery.platformBrightnessOf(context),
      ),
      child: _ScaledDetailScaffold(
        title: '\u5916\u89c2\u8bbe\u7f6e',
        uiScale: settings.uiScale,
        fontScale: settings.fontScale,
        children: [
          _AppearancePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InlineSectionTitle(
                  title: '主题模式',
                  subtitle: '影响应用整体浅色或深色显示',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        key: const ValueKey('appearance-theme-mode-light'),
                        icon: LucideIcons.sun,
                        label: '浅色',
                        selected: settings.themeMode == AppThemeMode.light,
                        onTap: () {
                          _update(
                            settings.copyWith(themeMode: AppThemeMode.light),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeButton(
                        key: const ValueKey('appearance-theme-mode-dark'),
                        icon: LucideIcons.moon,
                        label: '深色',
                        selected: settings.themeMode == AppThemeMode.dark,
                        onTap: () {
                          _update(
                            settings.copyWith(themeMode: AppThemeMode.dark),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeButton(
                        key: const ValueKey('appearance-theme-mode-system'),
                        icon: LucideIcons.smartphone,
                        label: '跟随系统',
                        selected: settings.themeMode == AppThemeMode.system,
                        onTap: () {
                          _update(
                            settings.copyWith(themeMode: AppThemeMode.system),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _InlineSectionTitle(title: '主题色', subtitle: '影响应用整体配色'),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final palette in _visibleThemePalettes)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: _ThemeColorOption(
                            palette: palette,
                            selected:
                                settings.themePalette == palette &&
                                palette != AppThemePalette.aurora,
                            onTap: () {
                              _update(settings.copyWith(themePalette: palette));
                            },
                          ),
                        ),
                      for (final color in settings.customThemeColors)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: _CustomThemeColorOption(
                            color: color,
                            selected:
                                settings.themePalette ==
                                    AppThemePalette.aurora &&
                                settings.customThemeColorValue == color.value,
                            onTap: () {
                              _update(
                                settings.copyWith(
                                  themePalette: AppThemePalette.aurora,
                                  customThemeColorName: color.name,
                                  customThemeColorValue: color.value,
                                ),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _AddThemeColorOption(
                          selected:
                              settings.themePalette == AppThemePalette.aurora,
                          colorValue: settings.customThemeColorValue,
                          label: settings.customThemeColorName,
                          onTap: _showCustomThemeColorDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AppearancePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.maximize,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '\u9875\u9762\u7f29\u653e',
                        style: _titleTextStyle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(uiScale * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28, right: 8),
                  child: Text(
                    '\u8c03\u6574\u754c\u9762\u6574\u4f53\u5927\u5c0f\uff08\u4e0d\u5f71\u54cd\u53c2\u8003\u56fe\uff09',
                    style: _captionTextStyle,
                  ),
                ),
                const SizedBox(height: 14),
                _PercentScaleControl(
                  value: uiScale,
                  min: 0.8,
                  max: 1.0,
                  divisions: 4,
                  tickLabels: const ['80%', '85%', '90%', '95%', '100%'],
                  showStepper: false,
                  onChanged: (value) {
                    _update(settings.copyWith(uiScale: value));
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Aa', style: _titleTextStyle),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          _FontSizeButton(
                            label: '\u5c0f',
                            selected: fontScale <= 0.9,
                            onTap: () =>
                                _update(settings.copyWith(fontScale: 0.9)),
                          ),
                          const SizedBox(width: 10),
                          _FontSizeButton(
                            label: '\u6807\u51c6',
                            selected: fontScale > 0.9 && fontScale < 1.1,
                            onTap: () =>
                                _update(settings.copyWith(fontScale: 1)),
                          ),
                          const SizedBox(width: 10),
                          _FontSizeButton(
                            label: '\u5927',
                            selected: fontScale >= 1.1 && fontScale < 1.2,
                            onTap: () =>
                                _update(settings.copyWith(fontScale: 1.1)),
                          ),
                          const SizedBox(width: 10),
                          _FontSizeButton(
                            label: '\u7279\u5927',
                            selected: fontScale >= 1.2,
                            onTap: () =>
                                _update(settings.copyWith(fontScale: 1.2)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AppearancePanel(
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                key: const ValueKey('plan-group-progress-toggle'),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  LucideIcons.moveHorizontal,
                  color: AppColors.textSecondary,
                ),
                title: Text('显示片区进度条', style: _titleTextStyle),
                subtitle: Text(
                  '在片区选择弹窗中显示未完成片区的进度背景；完成后仅显示对勾。',
                  style: _secondaryTextStyle,
                ),
                value: settings.showPlanGroupProgress,
                onChanged: (value) {
                  _update(settings.copyWith(showPlanGroupProgress: value));
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          _AppearancePanel(
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                key: const ValueKey(
                  'dismiss-plan-actions-on-outside-tap-toggle',
                ),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  LucideIcons.pointer,
                  color: AppColors.textSecondary,
                ),
                title: Text('点击空白收回计划操作', style: _titleTextStyle),
                subtitle: Text(
                  '展开计划操作后，点击面板外的空白区域自动收回',
                  style: _secondaryTextStyle,
                ),
                value: settings.dismissPlanActionsOnOutsideTap,
                onChanged: (value) {
                  _update(
                    settings.copyWith(dismissPlanActionsOnOutsideTap: value),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraSettingsPage extends StatefulWidget {
  const _CameraSettingsPage({
    required this.settings,
    required this.onChanged,
    required this.zoomCapabilities,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final CameraZoomCapabilities zoomCapabilities;

  @override
  State<_CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends State<_CameraSettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings settings) {
    setState(() {
      _settings = settings;
    });
    widget.onChanged(settings);
  }

  Future<void> _showCustomAspectRatioDialog({
    required bool fallbackRatio,
  }) async {
    final result = await showDialog<({double width, double height})>(
      context: context,
      builder: (context) => _CustomAspectRatioDialog(settings: _settings),
    );
    if (result == null) {
      return;
    }

    final updated = _settings.copyWith(
      customCameraAspectRatioWidth: result.width,
      customCameraAspectRatioHeight: result.height,
      cameraCaptureAspectRatio: fallbackRatio
          ? _settings.cameraCaptureAspectRatio
          : CameraPhotoAspectRatio.custom,
      cameraFallbackAspectRatio: fallbackRatio
          ? CameraPhotoAspectRatio.custom
          : _settings.cameraFallbackAspectRatio,
    );
    _update(updated);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final zoomRangeMin = widget.zoomCapabilities.minZoom;
    final zoomRangeMax = widget.zoomCapabilities.maxZoom.clamp(
      zoomRangeMin,
      cameraZoomUpperLimit,
    );
    final cameraMinZoom = settings.cameraMinZoom.clamp(
      zoomRangeMin,
      zoomRangeMax,
    );
    final cameraMaxZoom = settings.cameraMaxZoom.clamp(
      cameraMinZoom,
      zoomRangeMax,
    );
    final zoomSliderValues = RangeValues(
      cameraZoomSliderValueFromRealZoom(
        minZoom: zoomRangeMin,
        maxZoom: zoomRangeMax,
        realZoom: cameraMinZoom,
      ),
      cameraZoomSliderValueFromRealZoom(
        minZoom: zoomRangeMin,
        maxZoom: zoomRangeMax,
        realZoom: cameraMaxZoom,
      ),
    );

    return _ScaledDetailScaffold(
      title: '拍摄设置',
      uiScale: settings.uiScale,
      fontScale: settings.fontScale,
      children: [
        _SettingsSection(
          title: '\u62cd\u6444\u56fe\u7247\u6bd4\u4f8b',
          titleSpacing: 6,
          children: [
            Text(
              '\u81ea\u52a8\u4f1a\u4f18\u5148\u8ddf\u968f\u53c2\u8003\u56fe\u6bd4\u4f8b\uff1b\u9009\u62e9\u56fa\u5b9a\u6bd4\u4f8b\u540e\u4f1a\u6309\u8be5\u6bd4\u4f8b\u62cd\u6444\u3002',
              style: _secondaryTextStyle,
            ),
            const SizedBox(height: 10),
            _AspectRatioGrid(
              ratios: const [
                CameraPhotoAspectRatio.auto,
                CameraPhotoAspectRatio.landscape16x9,
                CameraPhotoAspectRatio.cinema21x9,
                CameraPhotoAspectRatio.standard4x3,
                CameraPhotoAspectRatio.photo3x2,
                CameraPhotoAspectRatio.square1x1,
                CameraPhotoAspectRatio.portrait9x16,
                CameraPhotoAspectRatio.portrait9x21,
                CameraPhotoAspectRatio.portrait3x4,
                CameraPhotoAspectRatio.portrait2x3,
              ],
              selectedRatio: settings.cameraCaptureAspectRatio,
              onSelected: (ratio) {
                _update(settings.copyWith(cameraCaptureAspectRatio: ratio));
              },
              customSelected:
                  settings.cameraCaptureAspectRatio ==
                  CameraPhotoAspectRatio.custom,
              onCustomSelected: () =>
                  _showCustomAspectRatioDialog(fallbackRatio: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '\u65e0\u53c2\u8003\u56fe\u65f6\u6bd4\u4f8b',
          titleSpacing: 6,
          children: [
            Text(
              '\u62cd\u6444\u56fe\u7247\u6bd4\u4f8b\u4e3a\u81ea\u52a8\u3001\u4e14\u6ca1\u6709\u53c2\u8003\u56fe\u53ef\u5bf9\u9f50\u65f6\u4f7f\u7528\u3002',
              style: _secondaryTextStyle,
            ),
            const SizedBox(height: 10),
            _AspectRatioGrid(
              ratios: const [
                CameraPhotoAspectRatio.native,
                CameraPhotoAspectRatio.landscape16x9,
                CameraPhotoAspectRatio.cinema21x9,
                CameraPhotoAspectRatio.standard4x3,
                CameraPhotoAspectRatio.photo3x2,
                CameraPhotoAspectRatio.square1x1,
                CameraPhotoAspectRatio.portrait9x16,
                CameraPhotoAspectRatio.portrait9x21,
                CameraPhotoAspectRatio.portrait3x4,
                CameraPhotoAspectRatio.portrait2x3,
              ],
              selectedRatio: settings.cameraFallbackAspectRatio,
              onSelected: (ratio) {
                _update(settings.copyWith(cameraFallbackAspectRatio: ratio));
              },
              customSelected:
                  settings.cameraFallbackAspectRatio ==
                  CameraPhotoAspectRatio.custom,
              onCustomSelected: () =>
                  _showCustomAspectRatioDialog(fallbackRatio: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title:
              '\u53c2\u8003\u56fe\u663e\u793a ${(settings.referenceImageScale * 100).round()}%',
          children: [
            _PercentScaleControl(
              value: settings.referenceImageScale.clamp(0.8, 1.0),
              min: 0.8,
              max: 1.0,
              divisions: 4,
              tickLabels: const ['80%', '85%', '90%', '95%', '100%'],
              showStepper: false,
              onChanged: (value) {
                _update(settings.copyWith(referenceImageScale: value));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title:
              '\u76f8\u673a\u7f29\u653e ${cameraMinZoom.toStringAsFixed(1)}x - ${cameraMaxZoom.toStringAsFixed(1)}x',
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 7,
                  pressedElevation: 3,
                ),
                rangeValueIndicatorShape:
                    const PaddleRangeSliderValueIndicatorShape(),
                showValueIndicator: ShowValueIndicator.onlyForDiscrete,
              ),
              child: RangeSlider(
                min: 0,
                max: 1,
                divisions: 200,
                values: zoomSliderValues,
                labels: RangeLabels(
                  '${cameraMinZoom.toStringAsFixed(1)}x',
                  '${cameraMaxZoom.toStringAsFixed(1)}x',
                ),
                onChanged: (values) {
                  final minZoom = realZoomFromCameraSliderValue(
                    minZoom: zoomRangeMin,
                    maxZoom: zoomRangeMax,
                    sliderValue: values.start,
                  ).snapToZoomStep();
                  final maxZoom = realZoomFromCameraSliderValue(
                    minZoom: zoomRangeMin,
                    maxZoom: zoomRangeMax,
                    sliderValue: values.end,
                  ).snapToZoomStep();
                  _update(
                    settings.copyWith(
                      cameraMinZoom: minZoom.clamp(zoomRangeMin, zoomRangeMax),
                      cameraMaxZoom: maxZoom.clamp(minZoom, zoomRangeMax),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_shouldShowPhotoLocationSettings) ...[
          const SizedBox(height: 12),
          _SettingsSection(
            title: '照片定位信息',
            titleSpacing: 6,
            children: [
              _PhotoLocationStrategyDropdown(
                value: settings.photoLocationStrategy,
                settings: settings,
                onChanged: (strategy) {
                  if (strategy != null) {
                    _update(settings.copyWith(photoLocationStrategy: strategy));
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _photoLocationStrategyDescription(
                  settings.photoLocationStrategy,
                ),
                style: _secondaryTextStyle,
              ),
            ],
          ),
        ],
        if (_shouldShowMobileGallerySettings) ...[
          const SizedBox(height: 12),
          _SettingsSection(
            title: '照片备份',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  LucideIcons.cloudUpload,
                  color: AppColors.textSecondary,
                ),
                title: Text('保存巡礼照片到相册', style: _titleTextStyle),
                subtitle: Text('保存记录时同时备份一张巡礼照片。', style: _secondaryTextStyle),
                value: settings.saveVisitPhotoToGallery,
                onChanged: (value) {
                  _update(settings.copyWith(saveVisitPhotoToGallery: value));
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _photoLocationStrategyDescription(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.askOnFirstCapture => '第一次按下快门时选择。定位仅写入照片，不使用点位坐标。',
    PhotoLocationStrategy.disabled => '不申请照片定位权限，也不向照片写入 GPS 信息。',
    PhotoLocationStrategy.useRecentLocation =>
      '拍摄时优先使用设备最近的有效定位；没有可用定位时尝试获取一次。',
    PhotoLocationStrategy.waitOnConfirmation => '拍摄后在确认记录页面获取新定位，完成或失败后再允许保存。',
  };
}

String _photoLocationStrategyBadge(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.askOnFirstCapture => '询问',
    PhotoLocationStrategy.disabled => '关闭',
    PhotoLocationStrategy.useRecentLocation => '最近',
    PhotoLocationStrategy.waitOnConfirmation => '推荐',
  };
}

String _photoLocationStrategyMenuLabel(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.waitOnConfirmation => '确认记录时获取定位',
    _ => strategy.label,
  };
}

class _PhotoLocationStrategyDropdown extends StatelessWidget {
  const _PhotoLocationStrategyDropdown({
    required this.value,
    required this.settings,
    required this.onChanged,
  });

  final PhotoLocationStrategy value;
  final AppSettings settings;
  final ValueChanged<PhotoLocationStrategy?> onChanged;

  static const _strategies = PhotoLocationStrategy.values;
  static const _maxItemsWithoutScrollbar = 7;

  @override
  Widget build(BuildContext context) {
    final omitScrollbarInset = _strategies.length <= _maxItemsWithoutScrollbar;

    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: AppColors.accent.withValues(alpha: 0.075),
        splashColor: Colors.transparent,
      ),
      child: DropdownButtonFormField<PhotoLocationStrategy>(
        key: ValueKey(value),
        initialValue: value,
        decoration: _decoration(),
        isExpanded: true,
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        dropdownColor: AppColors.surface,
        itemHeight: null,
        menuMaxHeight: appScaledOverlayExtent(settings, 360),
        icon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(LucideIcons.chevronDown, size: 20),
        ),
        selectedItemBuilder: (context) => [
          for (final strategy in _strategies)
            _PhotoLocationStrategyDropdownItem(strategy: strategy),
        ],
        items: [
          for (final strategy in _strategies)
            DropdownMenuItem<PhotoLocationStrategy>(
              value: strategy,
              child: SizedBox(
                height: appScaledOverlayExtent(settings, 48),
                child: AppScaledOverlayContent(
                  settings: settings,
                  child: _PhotoLocationStrategyDropdownItem(
                    strategy: strategy,
                    selected: strategy == value,
                    menuItem: true,
                    omitScrollbarInset: omitScrollbarInset,
                  ),
                ),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      hoverColor: AppColors.accent.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }
}

class _PhotoLocationStrategyDropdownItem extends StatefulWidget {
  const _PhotoLocationStrategyDropdownItem({
    required this.strategy,
    this.selected = false,
    this.menuItem = false,
    this.omitScrollbarInset = false,
  });

  final PhotoLocationStrategy strategy;
  final bool selected;
  final bool menuItem;
  final bool omitScrollbarInset;

  @override
  State<_PhotoLocationStrategyDropdownItem> createState() =>
      _PhotoLocationStrategyDropdownItemState();
}

class _PhotoLocationStrategyDropdownItemState
    extends State<_PhotoLocationStrategyDropdownItem> {
  static const _hoverOffset = 12.0;
  static const _menuTrailingInset = 10.0;
  static const _menuBackgroundTrailingInset = 6.0;

  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final strategy = widget.strategy;
    final selected = widget.selected;
    final reserveScrollbarSpace = widget.menuItem && !widget.omitScrollbarInset;

    final item = SizedBox(
      width: double.infinity,
      height: widget.menuItem ? double.infinity : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        transform: Matrix4.translationValues(
          _hovered && !selected ? _hoverOffset : 0,
          0,
          0,
        ),
        transformAlignment: Alignment.centerLeft,
        padding: EdgeInsets.only(
          right: reserveScrollbarSpace ? _menuTrailingInset : 0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.42),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _photoLocationStrategyBadge(strategy),
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, widget.menuItem ? 0 : -1),
                child: Text(
                  _photoLocationStrategyMenuLabel(strategy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.checkCircle, color: AppColors.accent, size: 18),
            ],
          ],
        ),
      ),
    );

    final content = SizedBox(
      width: double.infinity,
      height: widget.menuItem ? double.infinity : null,
      child: Stack(
        clipBehavior: Clip.none,
        fit: widget.menuItem ? StackFit.expand : StackFit.loose,
        children: [
          Positioned(
            left: -8,
            top: 6,
            right: reserveScrollbarSpace ? _menuBackgroundTrailingInset : -8,
            bottom: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(
                  alpha: selected ? 0.1 : (_hovered ? 0.05 : 0),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          item,
        ],
      ),
    );

    return MouseRegion(
      onEnter: widget.menuItem && !selected
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.menuItem && !selected
          ? (_) => setState(() => _hovered = false)
          : null,
      child: content,
    );
  }
}

class _AnitabiServiceSettingsPage extends StatefulWidget {
  const _AnitabiServiceSettingsPage({
    required this.settings,
    required this.onChanged,
    required this.showUrlDialog,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final Future<void> Function({
    required String title,
    required String initialValue,
    required String helperText,
    required String? Function(String value) validator,
    required ValueChanged<String> onSaved,
  })
  showUrlDialog;

  @override
  State<_AnitabiServiceSettingsPage> createState() =>
      _AnitabiServiceSettingsPageState();
}

class _AnitabiServiceSettingsPageState
    extends State<_AnitabiServiceSettingsPage> {
  late AppSettings _settings = widget.settings;
  var _testing = false;
  Map<String, String> _testResults = const {};

  AnitabiServiceConfig get _config => AnitabiServiceConfig(
    siteBaseUrl: _settings.anitabiSiteBaseUrl,
    staticDataBaseUrl: _settings.anitabiStaticDataBaseUrl,
    apiBaseUrl: _settings.anitabiApiBaseUrl,
    officialImageBaseUrl: _settings.anitabiOfficialImageBaseUrl,
    mirrorImageBaseUrl: _settings.anitabiMirrorImageBaseUrl,
  );

  void _update(AppSettings settings) {
    setState(() {
      _settings = settings;
      _testResults = const {};
    });
    widget.onChanged(settings);
  }

  Future<void> _edit({
    required String title,
    required String value,
    required ValueChanged<String> onSaved,
  }) {
    return widget.showUrlDialog(
      title: title,
      initialValue: value,
      helperText: '仅支持公开可访问的 HTTPS 基础地址，不要填写接口路径参数。',
      validator: validateAnitabiBaseUrl,
      onSaved: (value) =>
          onSaved(normalizeAnitabiBaseUrl(value, fallback: value.trim())),
    );
  }

  Future<void> _testConnections() async {
    setState(() {
      _testing = true;
      _testResults = const {};
    });
    final config = _config;
    final probes = <String, Uri>{
      '主站地址': config.siteUri('/'),
      '静态地图数据': config.staticDataUri('g.json'),
      '数据 API': config.apiUri('bangumi/115908/lite'),
      '官方图片服务': Uri.parse(
        config.officialImageUrl(
          Uri.parse(
            'https://image.anitabi.cn/points/115908/qys7fu.jpg?plan=h160',
          ),
        ),
      ),
      '备用图片服务': Uri.parse(
        config.mirrorImageUrl(
          Uri.parse(
            'https://image.anitabi.cn/points/115908/qys7fu.jpg?plan=h160',
          ),
        ),
      ),
    };
    final results = <String, String>{};
    final client = http.Client();
    try {
      for (final entry in probes.entries) {
        results[entry.key] = await _probe(client, entry.value);
        if (mounted) {
          setState(() => _testResults = {...results});
        }
      }
    } finally {
      client.close();
    }
    if (mounted) {
      setState(() => _testing = false);
    }
  }

  Future<String> _probe(http.Client client, Uri uri) async {
    final stopwatch = Stopwatch()..start();
    try {
      final request = http.Request('GET', uri)
        ..headers['range'] = 'bytes=0-2047';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 12));
      await response.stream.timeout(const Duration(seconds: 12)).drain<void>();
      stopwatch.stop();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '失败 · HTTP ${response.statusCode}';
      }
      return '连接成功 · ${stopwatch.elapsedMilliseconds} ms';
    } catch (_) {
      return '连接失败';
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: '恢复默认地址',
      message: '将把全部 Anitabi 服务地址恢复为官方默认值。',
      confirmLabel: '恢复默认',
      notice: '当前自定义地址不会被保留',
      emphasizedValues: const ['全部 Anitabi 服务地址'],
    );
    if (!confirmed || !mounted) {
      return;
    }
    _update(
      _settings.copyWith(
        anitabiSiteBaseUrl: defaultAnitabiSiteBaseUrl,
        anitabiStaticDataBaseUrl: defaultAnitabiStaticDataBaseUrl,
        anitabiApiBaseUrl: defaultAnitabiApiBaseUrl,
        anitabiOfficialImageBaseUrl: defaultAnitabiOfficialImageBaseUrl,
        anitabiMirrorImageBaseUrl: defaultAnitabiMirrorImageBaseUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final services =
        <
          ({
            Key key,
            IconData icon,
            String title,
            String value,
            ValueChanged<String> onSaved,
          })
        >[
          (
            key: const ValueKey('anitabi-site-base-url'),
            icon: LucideIcons.globe,
            title: '主站地址',
            value: settings.anitabiSiteBaseUrl,
            onSaved: (value) =>
                _update(settings.copyWith(anitabiSiteBaseUrl: value)),
          ),
          (
            key: const ValueKey('anitabi-static-data-base-url'),
            icon: LucideIcons.braces,
            title: '静态地图数据',
            value: settings.anitabiStaticDataBaseUrl,
            onSaved: (value) =>
                _update(settings.copyWith(anitabiStaticDataBaseUrl: value)),
          ),
          (
            key: const ValueKey('anitabi-api-base-url'),
            icon: LucideIcons.webhook,
            title: '数据 API',
            value: settings.anitabiApiBaseUrl,
            onSaved: (value) =>
                _update(settings.copyWith(anitabiApiBaseUrl: value)),
          ),
          (
            key: const ValueKey('anitabi-official-image-base-url'),
            icon: LucideIcons.image,
            title: '官方图片服务',
            value: settings.anitabiOfficialImageBaseUrl,
            onSaved: (value) =>
                _update(settings.copyWith(anitabiOfficialImageBaseUrl: value)),
          ),
          (
            key: const ValueKey('anitabi-mirror-image-base-url'),
            icon: LucideIcons.cloud,
            title: '备用图片服务',
            value: settings.anitabiMirrorImageBaseUrl,
            onSaved: (value) =>
                _update(settings.copyWith(anitabiMirrorImageBaseUrl: value)),
          ),
        ];
    return _ScaledDetailScaffold(
      title: 'Anitabi 服务地址',
      uiScale: settings.uiScale,
      fontScale: settings.fontScale,
      children: [
        _SettingsSection(
          title: '服务地址',
          titleSpacing: 4,
          children: [
            for (var index = 0; index < services.length; index += 1) ...[
              if (index > 0)
                Divider(height: 1, thickness: 1, color: AppColors.border),
              _AnitabiServiceRow(
                key: services[index].key,
                icon: services[index].icon,
                title: services[index].title,
                url: services[index].value,
                status: _testResults[services[index].title],
                testing:
                    _testing &&
                    !_testResults.containsKey(services[index].title),
                onTap: () => _edit(
                  title: services[index].title,
                  value: services[index].value,
                  onSaved: services[index].onSaved,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('anitabi-service-test-all'),
                onPressed: _testing ? null : _testConnections,
                icon: _testing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.wifi),
                label: Text(_testing ? '正在测试连接' : '测试全部连接'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('anitabi-service-restore-defaults'),
                onPressed: _testing ? null : _restoreDefaults,
                icon: const Icon(LucideIcons.history),
                label: const Text('恢复默认地址'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonStyleSettingsPage extends StatefulWidget {
  const _ComparisonStyleSettingsPage({
    required this.repository,
    required this.settings,
    required this.onChanged,
  });

  final PilgrimageRepository repository;
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<_ComparisonStyleSettingsPage> createState() =>
      _ComparisonStyleSettingsPageState();
}

class _ComparisonStyleSettingsPageState
    extends State<_ComparisonStyleSettingsPage> {
  var _settings = const AppSettings();
  var _config = ComparisonExportConfig.lastUsed;
  late final TextEditingController _pilgrimNameController;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _config = ComparisonExportConfig.lastUsed.withSettings(_settings);
    _pilgrimNameController = TextEditingController(text: _config.pilgrimName);
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _pilgrimNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }

    final migratedConfig = ComparisonExportConfig.fromSettings(settings);
    setState(() {
      _settings = settings;
      _config = migratedConfig;
      ComparisonExportConfig.lastUsed = migratedConfig;
      _pilgrimNameController.text = migratedConfig.pilgrimName;
      _loading = false;
    });
  }

  Future<void> _updateConfig(ComparisonExportConfig config) async {
    final settings = config.applyToSettings(_settings);
    setState(() {
      _config = config;
      _settings = settings;
    });
    ComparisonExportConfig.lastUsed = config;
    widget.onChanged(settings);
    await widget.repository.saveAppSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return _ScaledDetailScaffold(
      title: '对比图设置',
      uiScale: _settings.uiScale,
      fontScale: _settings.fontScale,
      children: [
        _SettingsSection(
          title: '',
          showTitle: false,
          children: [
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 14),
            ],
            ComparisonExportConfigEditor(
              config: _config,
              pilgrimNameController: _pilgrimNameController,
              onChanged: _updateConfig,
            ),
          ],
        ),
      ],
    );
  }
}

class _DataSourceSettingsPage extends StatefulWidget {
  const _DataSourceSettingsPage({
    required this.settings,
    required this.onChanged,
    required this.showMapUrlDialog,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final Future<void> Function({
    required String title,
    required String initialValue,
    required String helperText,
    required String? Function(String value) validator,
    required ValueChanged<String> onSaved,
  })
  showMapUrlDialog;

  @override
  State<_DataSourceSettingsPage> createState() =>
      _DataSourceSettingsPageState();
}

class _DataSourceSettingsPageState extends State<_DataSourceSettingsPage> {
  late AppSettings _settings;
  var _testingValhalla = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings settings) {
    setState(() {
      _settings = settings;
    });
    widget.onChanged(settings);
  }

  Future<void> _testValhalla() async {
    setState(() => _testingValhalla = true);
    try {
      await ValhallaRouteClient().testConnection(_settings.valhallaBaseUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.success,
          title: '路径规划服务连接正常',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '路径规划服务连接失败',
          subtitle: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _testingValhalla = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return _ScaledDetailScaffold(
      title: '数据源设置',
      uiScale: settings.uiScale,
      fontScale: settings.fontScale,
      children: [
        _SettingsSection(
          title:
              '\u5730\u56fe\u6e90 ${mapTileProviderOption(settings.mapTileProvider).label}',
          children: [
            _MapSourceGrid(
              selectedProvider: settings.mapTileProvider,
              onSelected: (provider) {
                _update(settings.copyWith(mapTileProvider: provider));
              },
            ),
            const SizedBox(height: 10),
            Text(
              mapTileProviderOption(settings.mapTileProvider).description,
              style: _secondaryTextStyle,
            ),
            if (settings.mapTileProvider == MapTileProvider.openFreeMap) ...[
              const SizedBox(height: 12),
              _SettingsSubheading(
                icon: LucideIcons.layers,
                title:
                    'OpenFreeMap 样式 ${openFreeMapStyleOption(settings.openFreeMapStyle).label}',
              ),
              const SizedBox(height: 8),
              _OpenFreeMapStyleGrid(
                selectedStyle: settings.openFreeMapStyle,
                onSelected: (style) {
                  _update(settings.copyWith(openFreeMapStyle: style));
                },
              ),
              const SizedBox(height: 10),
              Text(
                openFreeMapStyleOption(settings.openFreeMapStyle).description,
                style: _secondaryTextStyle,
              ),
            ],
            if (settings.mapTileProvider == MapTileProvider.customXyz) ...[
              const SizedBox(height: 12),
              _MapUrlRow(
                icon: LucideIcons.grid3X3,
                label: settings.customXyzTileUrl.trim().isEmpty
                    ? '未设置自定义 XYZ URL'
                    : settings.customXyzTileUrl.trim(),
                onTap: () => widget.showMapUrlDialog(
                  title: '自定义 XYZ URL',
                  initialValue: settings.customXyzTileUrl,
                  helperText: 'URL 需要包含 {z}、{x}、{y}。',
                  validator: (value) =>
                      isValidXyzTileUrl(value.trim()) ? null : 'URL 格式无效',
                  onSaved: (value) {
                    _update(settings.copyWith(customXyzTileUrl: value.trim()));
                  },
                ),
              ),
            ],
            if (settings.mapTileProvider ==
                MapTileProvider.customMapLibreStyle) ...[
              const SizedBox(height: 12),
              _MapUrlRow(
                icon: LucideIcons.braces,
                label: settings.customMapLibreStyleUrl.trim().isEmpty
                    ? '未设置 MapLibre style URL'
                    : settings.customMapLibreStyleUrl.trim(),
                onTap: () => widget.showMapUrlDialog(
                  title: 'MapLibre style URL',
                  initialValue: settings.customMapLibreStyleUrl,
                  helperText: 'URL 需要指向可公开读取的 style JSON。',
                  validator: (value) {
                    final testSettings = settings.copyWith(
                      customMapLibreStyleUrl: value.trim(),
                    );
                    return validateMapTileSettings(testSettings);
                  },
                  onSaved: (value) {
                    _update(
                      settings.copyWith(customMapLibreStyleUrl: value.trim()),
                    );
                  },
                ),
              ),
            ],
            if (validateMapTileSettings(settings) != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: LucideIcons.circleAlert,
                text: validateMapTileSettings(settings)!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: 'Anitabi 服务地址',
          children: [
            _AnitabiServiceEntryRow(
              key: const ValueKey('anitabi-service-settings-entry'),
              siteUrl: settings.anitabiSiteBaseUrl,
              usingDefaults: _usesDefaultAnitabiService(settings),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _AnitabiServiceSettingsPage(
                    settings: settings,
                    onChanged: _update,
                    showUrlDialog: widget.showMapUrlDialog,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('服务域名变化时可单独调整，不会改写计划中的标准图片链接。', style: _secondaryTextStyle),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title:
              'Anitabi 图片源 ${_anitabiImageSourceLabel(settings.anitabiImageSource)}',
          children: [
            _AnitabiImageSourceGrid(
              selectedSource: settings.anitabiImageSource,
              onSelected: (source) {
                _update(settings.copyWith(anitabiImageSource: source));
              },
            ),
            const SizedBox(height: 10),
            Text(
              _anitabiImageSourceDescription(settings),
              style: _secondaryTextStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '导航地图 ${settings.navigationApp.label}',
          children: [
            _NavigationAppGrid(
              selectedApp: settings.navigationApp,
              onSelected: (app) {
                _update(settings.copyWith(navigationApp: app));
              },
            ),
            const SizedBox(height: 10),
            Text(
              _navigationAppDescription(settings.navigationApp),
              style: _secondaryTextStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '步行路径规划',
          children: [
            _MapUrlRow(
              icon: LucideIcons.route,
              label: settings.valhallaBaseUrl,
              onTap: () => widget.showMapUrlDialog(
                title: 'Valhalla 服务地址',
                initialValue: settings.valhallaBaseUrl,
                helperText: '用于应用内步行路线规划。公开服务没有可用性保证。',
                validator: validateValhallaBaseUrl,
                onSaved: (value) {
                  _update(
                    settings.copyWith(
                      valhallaBaseUrl: normalizeValhallaBaseUrl(value),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ResponsiveTwoButtonRow(
              first: OutlinedButton(
                onPressed: _testingValhalla ? null : _testValhalla,
                child: _testingValhalla
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const ResponsiveButtonContent(
                        icon: LucideIcons.radio,
                        label: '测试连接',
                        shortLabel: '测试',
                        semanticLabel: '测试 Valhalla 连接',
                      ),
              ),
              second: OutlinedButton(
                onPressed: settings.valhallaBaseUrl == defaultValhallaBaseUrl
                    ? null
                    : () => _update(
                        settings.copyWith(
                          valhallaBaseUrl: defaultValhallaBaseUrl,
                        ),
                      ),
                child: const ResponsiveButtonContent(
                  icon: LucideIcons.history,
                  label: '恢复默认',
                  shortLabel: '恢复',
                  semanticLabel: '恢复默认 Valhalla 地址',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('仅发送路线坐标，不会上传计划、作品或照片信息。', style: _secondaryTextStyle),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '图片加载',
          children: [
            _NumberStepperSetting(
              icon: LucideIcons.cloudDownload,
              title: '图片同时请求数',
              subtitle: '用于地图缩略图显示、导入点位时缓存缩略图，以及批量缓存参考图。数值越大速度可能越快，但网络压力也更高。',
              value: settings.mapThumbnailConcurrentLoads,
              min: 1,
              max: 30,
              step: 1,
              valueLabel: '${settings.mapThumbnailConcurrentLoads} 个',
              onChanged: (value) {
                _update(settings.copyWith(mapThumbnailConcurrentLoads: value));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MapDisplaySettingsPage extends StatefulWidget {
  const _MapDisplaySettingsPage({
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<_MapDisplaySettingsPage> createState() =>
      _MapDisplaySettingsPageState();
}

class _MapDisplaySettingsPageState extends State<_MapDisplaySettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings settings) {
    setState(() {
      _settings = settings;
    });
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return _ScaledDetailScaffold(
      title: '地图显示',
      uiScale: settings.uiScale,
      fontScale: settings.fontScale,
      children: [
        _SettingsSection(
          title: '当前位置',
          children: [
            SwitchListTile(
              key: const ValueKey('continuous-map-location-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text('持续更新当前位置', style: _titleTextStyle),
              subtitle: Text(
                '开启定位后持续更新；关闭时仅在点击定位时获取一次。',
                style: _secondaryTextStyle,
              ),
              value: settings.continuousMapLocation,
              onChanged: (value) =>
                  _update(settings.copyWith(continuousMapLocation: value)),
            ),
          ],
        ),
        _SettingsSection(
          title: '地图缩放',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.zoomIn,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('最大缩放倍率', style: _titleTextStyle),
                          ),
                          Text(
                            '${settings.mapMaxZoom} 级',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('控制所有地图能够放大的最大级别。', style: _secondaryTextStyle),
                      Slider(
                        key: const ValueKey('map-max-zoom-slider'),
                        min: 16,
                        max: 24,
                        divisions: 8,
                        value: settings.mapMaxZoom.toDouble().clamp(16, 24),
                        label: '${settings.mapMaxZoom} 级',
                        onChanged: (value) {
                          final mapMaxZoom = value.round();
                          final clusterMaxZoom =
                              settings.mapMarkerClusterMaxZoom > mapMaxZoom
                              ? mapMaxZoom
                              : settings.mapMarkerClusterMaxZoom;
                          _update(
                            settings.copyWith(
                              mapMaxZoom: mapMaxZoom,
                              mapMarkerClusterMaxZoom: clusterMaxZoom,
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('16', style: _captionTextStyle),
                            Text('18', style: _captionTextStyle),
                            Text('20', style: _captionTextStyle),
                            Text('22', style: _captionTextStyle),
                            Text('24', style: _captionTextStyle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '地图标记',
          children: [
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                key: const ValueKey('hide-completed-points-on-map-toggle'),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  LucideIcons.eyeOff,
                  color: AppColors.textSecondary,
                ),
                title: Text('隐藏已完成点位', style: _titleTextStyle),
                subtitle: Text(
                  '在地图页不显示已标记完成的点位。关闭后仍可在地图上看到全部点位。',
                  style: _secondaryTextStyle,
                ),
                value: settings.hideCompletedPointsOnMap,
                onChanged: (value) {
                  _update(settings.copyWith(hideCompletedPointsOnMap: value));
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.mapPin,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('地图标记大小', style: _titleTextStyle),
                      const SizedBox(height: 3),
                      Text(
                        '统一调整点位、缩略图、聚合标记、当前位置和片区关键点的大小。',
                        style: _secondaryTextStyle,
                      ),
                      const SizedBox(height: 8),
                      _PercentScaleControl(
                        value: settings.mapMarkerScale,
                        min: 0.6,
                        max: 1.2,
                        divisions: 12,
                        tickLabels: const ['60%', '80%', '100%', '120%'],
                        onChanged: (value) {
                          _update(settings.copyWith(mapMarkerScale: value));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '片区范围',
          children: [
            _NumberStepperSetting(
              icon: LucideIcons.hand,
              title: '片区范围半径',
              subtitle: '每个点位向外扩张的距离，用于生成地图上的片区轮廓。',
              value: settings.mapGroupAreaRadiusMeters,
              min: 25,
              max: 500,
              step: 25,
              valueLabel: '${settings.mapGroupAreaRadiusMeters} m',
              onChanged: (value) {
                _update(settings.copyWith(mapGroupAreaRadiusMeters: value));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '地图点位聚合',
          children: [
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  LucideIcons.gitBranch,
                  color: AppColors.textSecondary,
                ),
                title: Text('自动聚合密集点位', style: _titleTextStyle),
                subtitle: Text(
                  '仅合并地图标记的显示；点位数据、选择和导入功能不受影响。',
                  style: _secondaryTextStyle,
                ),
                value: settings.mapMarkerClusteringEnabled,
                onChanged: (value) {
                  _update(settings.copyWith(mapMarkerClusteringEnabled: value));
                },
              ),
            ),
            if (settings.mapMarkerClusteringEnabled) ...[
              const SizedBox(height: 8),
              _NumberStepperSetting(
                icon: LucideIcons.circleDashed,
                title: '聚合范围',
                subtitle: '屏幕上相距较近的点位会合并为一个带数量的聚合标记。',
                value: settings.mapMarkerClusterRadius,
                min: 32,
                max: 120,
                step: 8,
                valueLabel: '${settings.mapMarkerClusterRadius} px',
                onChanged: (value) {
                  _update(settings.copyWith(mapMarkerClusterRadius: value));
                },
              ),
              const SizedBox(height: 12),
              _NumberStepperSetting(
                icon: LucideIcons.maximize,
                title: '停止聚合级别',
                subtitle: '地图放大超过该级别后显示每个原始点位。',
                value: settings.mapMarkerClusterMaxZoom,
                min: 10,
                max: settings.mapMaxZoom.clamp(10, 22),
                step: 1,
                valueLabel: '${settings.mapMarkerClusterMaxZoom} 级',
                onChanged: (value) {
                  _update(settings.copyWith(mapMarkerClusterMaxZoom: value));
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '地图缩略图',
          children: [
            _NumberStepperSetting(
              icon: LucideIcons.maximize,
              title: '缩略图显示阈值',
              subtitle:
                  '视图内点位不超过 ${settings.mapThumbnailVisibleThreshold} 个时显示缩略图；超过时仅显示圆点。',
              value: settings.mapThumbnailVisibleThreshold,
              min: 0,
              max: 200,
              step: 5,
              valueLabel: '${settings.mapThumbnailVisibleThreshold} 个',
              onChanged: (value) {
                _update(settings.copyWith(mapThumbnailVisibleThreshold: value));
              },
            ),
            const SizedBox(height: 8),
            Text('阈值为 0 时不会在地图上显示缩略图。', style: _secondaryTextStyle),
          ],
        ),
      ],
    );
  }
}

class _CacheCleanupSettingsPage extends StatefulWidget {
  const _CacheCleanupSettingsPage({required this.repository});

  final PilgrimageRepository repository;

  @override
  State<_CacheCleanupSettingsPage> createState() =>
      _CacheCleanupSettingsPageState();
}

class _CacheCleanupSettingsPageState extends State<_CacheCleanupSettingsPage> {
  final Set<String> _selectedPlanIds = <String>{};
  Future<List<PilgrimagePlan>>? _plansFuture;
  var _busy = false;
  var _completed = 0;
  var _total = 0;

  @override
  void initState() {
    super.initState();
    _plansFuture = widget.repository.loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: '清除缓存',
      children: [
        FutureBuilder<List<PilgrimagePlan>>(
          future: _plansFuture,
          builder: (context, snapshot) {
            final plans = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SettingsSection(
                title: '计划',
                children: [
                  Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError || plans == null) {
              return _SettingsSection(
                title: '计划',
                children: [
                  const _InfoRow(
                    icon: LucideIcons.circleAlert,
                    text: '计划列表读取失败',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _plansFuture = widget.repository.loadPlans();
                      });
                    },
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text('重试'),
                  ),
                ],
              );
            }

            _selectedPlanIds.removeWhere(
              (id) => plans.every((plan) => plan.id != id),
            );

            return Column(
              children: [
                _SettingsSection(
                  title: '选择计划',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '已选择 ${_selectedPlanIds.length} / ${plans.length} 个计划',
                            style: _secondaryTextStyle,
                          ),
                        ),
                        IconButton(
                          tooltip: '全选',
                          onPressed: () {
                            setState(() {
                              _selectedPlanIds
                                ..clear()
                                ..addAll(plans.map((plan) => plan.id));
                            });
                          },
                          icon: const Icon(LucideIcons.scan),
                        ),
                        IconButton(
                          tooltip: '清空',
                          onPressed: _selectedPlanIds.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _selectedPlanIds.clear();
                                  });
                                },
                          icon: const Icon(LucideIcons.square),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...plans.map(
                      (plan) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(plan.name, style: _titleTextStyle),
                        subtitle: Text(
                          '${plan.area} / ${plan.points.length} 个点位',
                          style: _secondaryTextStyle,
                        ),
                        value: _selectedPlanIds.contains(plan.id),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPlanIds.add(plan.id);
                            } else {
                              _selectedPlanIds.remove(plan.id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _FullReferenceCacheSection(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedPlanIds.isEmpty || _busy
                        ? null
                        : () => _confirmAndClean(
                            plans.where(
                              (plan) => _selectedPlanIds.contains(plan.id),
                            ),
                          ),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.brushCleaning),
                    label: Text(
                      _busy && _total > 0
                          ? '正在清理 $_completed / $_total'
                          : '清除下载的参考图缓存',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmAndClean(Iterable<PilgrimagePlan> selected) async {
    setState(() => _busy = true);
    final plans = selected.toList(growable: false);
    late ReferenceCacheScan scan;
    try {
      scan = await scanDownloadedReferenceCaches(plans);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '缓存扫描失败',
          subtitle: error.toString(),
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (scan.fileCount == 0) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '所选计划没有可清理的下载缓存',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除参考图缓存？'),
        content: Text(
          '将删除 ${scan.fileCount} 个下载缓存，约 ${_formatByteSize(scan.byteCount)}。'
          '本地上传图片和计划包导入图片不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _completed = 0;
      _total = scan.paths.length;
    });
    try {
      final result = await cleanupDownloadedReferenceCaches(
        repository: widget.repository,
        plans: plans,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: result.failedFileCount == 0
            ? AppStatusBannerKind.success
            : AppStatusBannerKind.warning,
        title: '已清理 ${result.deletedFileCount} 个缓存文件',
        subtitle: result.failedFileCount == 0
            ? '释放 ${_formatByteSize(result.reclaimedBytes)}'
            : '${result.failedFileCount} 个文件清理失败',
      );
      setState(() {
        _plansFuture = widget.repository.loadPlans();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _completed = 0;
          _total = 0;
        });
      }
    }
  }
}

class _DesktopSettingsPage extends StatelessWidget {
  const _DesktopSettingsPage({
    required this.desktopLauncherInfo,
    required this.desktopLauncherStatusText,
  });

  final DesktopLauncherInfo? desktopLauncherInfo;
  final String desktopLauncherStatusText;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: '桌面端',
      children: [
        _SettingsSection(
          title: '启动器',
          children: [
            _InfoRow(
              icon: LucideIcons.monitor,
              text: desktopLauncherStatusText,
            ),
            if (desktopLauncherInfo != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: LucideIcons.folder,
                text: desktopLauncherInfo!.dataDir,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: LucideIcons.package,
                text: desktopLauncherInfo!.assetsDir,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}

class _AboutSettingsPage extends StatelessWidget {
  const _AboutSettingsPage({required this.appVersionLabel});

  final String? appVersionLabel;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: '关于 MiriaGo',
      children: [
        _SettingsSection(
          title: '应用信息',
          children: [
            Row(
              children: [
                const _AppIconMark(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CopyableText(
                        text: 'MiriaGo',
                        copyLabel: 'MiriaGo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text('动漫圣地巡礼计划与拍摄参考工具', style: _secondaryTextStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AboutInfoTile(
              icon: LucideIcons.badge,
              label: '当前版本',
              value: appVersionLabel ?? '读取中',
            ),
            const _AboutInfoTile(
              icon: LucideIcons.user,
              label: '作者',
              value: 'BilyHurington',
            ),
            const _AboutInfoTile(
              icon: LucideIcons.mail,
              label: '联系邮箱',
              value: 'bilyhurington@gmail.com',
            ),
            const _AboutInfoTile(
              icon: LucideIcons.code,
              label: '开源仓库',
              value: 'github.com/BilyHurington/MiriaGo',
            ),
            const _AboutInfoTile(
              icon: LucideIcons.scale,
              label: '开源许可',
              value: 'MIT License',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SettingsSection(
          title: '数据与版权',
          children: [
            _AboutDataItem(
              icon: LucideIcons.map,
              label: '地图',
              description: '可使用 OpenFreeMap、OpenStreetMap 或自定义地图服务。',
            ),
            _AboutDataItem(
              icon: LucideIcons.search,
              label: '作品',
              description: '作品搜索数据来自 Bangumi。',
            ),
            _AboutDataItem(
              icon: LucideIcons.mapPin,
              label: '巡礼内容',
              description: '巡礼点位与参考图来自 Anitabi。',
            ),
            _AboutDataItem(
              icon: LucideIcons.image,
              label: '图片源',
              description: '图片源设置只影响访问域名，远端链接统一保留 Anitabi 默认格式。',
            ),
            _AboutDataItem(
              icon: LucideIcons.copyright,
              label: '版权归属',
              description: '第三方数据、截图和图片版权归原平台、贡献者或权利方所有。',
              bottomSpacing: 0,
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: appBackButtonIfCanPop(context),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
    );
  }
}

class _ScaledDetailScaffold extends StatelessWidget {
  const _ScaledDetailScaffold({
    required this.title,
    required this.uiScale,
    required this.fontScale,
    required this.children,
  });

  final String title;
  final double uiScale;
  final double fontScale;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: appTextScaler(fontScale)),
      child: AppUiScaleView(
        scale: uiScale,
        child: _DetailScaffold(title: title, children: children),
      ),
    );
  }
}

extension _SettingsAspectRatioLabel on CameraPhotoAspectRatio {
  String get shortLabel {
    return switch (this) {
      CameraPhotoAspectRatio.auto => '\u81ea\u52a8',
      CameraPhotoAspectRatio.native => '\u539f\u751f',
      CameraPhotoAspectRatio.landscape16x9 => '16:9',
      CameraPhotoAspectRatio.cinema21x9 => '21:9',
      CameraPhotoAspectRatio.standard4x3 => '4:3',
      CameraPhotoAspectRatio.photo3x2 => '3:2',
      CameraPhotoAspectRatio.portrait9x16 => '9:16',
      CameraPhotoAspectRatio.portrait9x21 => '9:21',
      CameraPhotoAspectRatio.portrait3x4 => '3:4',
      CameraPhotoAspectRatio.portrait2x3 => '2:3',
      CameraPhotoAspectRatio.square1x1 => '1:1',
      CameraPhotoAspectRatio.custom => '\u81ea\u5b9a\u4e49',
    };
  }

  String get settingHintLabel {
    return switch (this) {
      CameraPhotoAspectRatio.auto => '\u63a8\u8350',
      CameraPhotoAspectRatio.native => '\u539f\u751f',
      CameraPhotoAspectRatio.landscape16x9 => '\u5bbd\u5c4f',
      CameraPhotoAspectRatio.cinema21x9 => '\u7535\u5f71',
      CameraPhotoAspectRatio.standard4x3 => '\u7ecf\u5178',
      CameraPhotoAspectRatio.photo3x2 => '\u76f8\u673a',
      CameraPhotoAspectRatio.portrait9x16 => '\u7ad6\u5c4f',
      CameraPhotoAspectRatio.portrait9x21 => '\u5168\u9762\u5c4f',
      CameraPhotoAspectRatio.portrait3x4 => '\u7ad6\u5e45',
      CameraPhotoAspectRatio.portrait2x3 => '\u7ad6\u5e45',
      CameraPhotoAspectRatio.square1x1 => '\u65b9\u5f62',
      CameraPhotoAspectRatio.custom => '\u81ea\u5b9a',
    };
  }
}

extension _ZoomStepSnap on double {
  double snapToZoomStep() => (this * 10).round() / 10;
}

class _SettingsChrome extends StatelessWidget {
  const _SettingsChrome({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outline),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.header,
    this.children = const [],
    super.key,
  });

  final _SettingsCardHeader header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return _SettingsChrome(
      child: Column(
        children: [
          header,
          for (final child in children) ...[
            ColoredBox(
              color: outline,
              child: const SizedBox(height: 1, width: double.infinity),
            ),
            child,
          ],
        ],
      ),
    );
  }
}

class _SettingsCardHeader extends StatelessWidget {
  const _SettingsCardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _cardTitleTextStyle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: _secondaryTextStyle.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              LucideIcons.chevronRight,
              color: scheme.onSurfaceVariant,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index += 1) ...[
              if (index > 0)
                ColoredBox(color: outline, child: const SizedBox(width: 1)),
              Expanded(child: children[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    this.swatch,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? swatch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            swatch ??
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 28,
                ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySwitchTile extends StatelessWidget {
  const _SummarySwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _cardTitleTextStyle),
                const SizedBox(height: 3),
                Text(subtitle, style: _secondaryTextStyle),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.titleSpacing = 12,
    this.showTitle = true,
  });

  final String title;
  final List<Widget> children;
  final double titleSpacing;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return _SettingsChrome(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: titleSpacing),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _SettingsSubheading extends StatelessWidget {
  const _SettingsSubheading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberStepperSetting extends StatelessWidget {
  const _NumberStepperSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.valueLabel,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String valueLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = value < max;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _titleTextStyle),
              const SizedBox(height: 3),
              Text(subtitle, style: _secondaryTextStyle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NumberStepperIconButton(
              icon: LucideIcons.minus,
              tooltip: '减少',
              onTap: canDecrease
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
            ),
            Container(
              width: 58,
              height: 36,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                valueLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            _NumberStepperIconButton(
              icon: LucideIcons.plus,
              tooltip: '增加',
              onTap: canIncrease
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberStepperIconButton extends StatelessWidget {
  const _NumberStepperIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textSecondary.withValues(
            alpha: 0.5,
          ),
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _AspectRatioGrid extends StatelessWidget {
  const _AspectRatioGrid({
    required this.ratios,
    required this.selectedRatio,
    required this.onSelected,
    this.customSelected = false,
    this.onCustomSelected,
  });

  final List<CameraPhotoAspectRatio> ratios;
  final CameraPhotoAspectRatio selectedRatio;
  final ValueChanged<CameraPhotoAspectRatio> onSelected;
  final bool customSelected;
  final VoidCallback? onCustomSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.0;
        final tileWidth = ((constraints.maxWidth - spacing * 3) / 4).clamp(
          72.0,
          112.0,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            for (final ratio in ratios)
              SizedBox(
                width: tileWidth,
                child: _AspectRatioOption(
                  ratio: ratio,
                  selected: selectedRatio == ratio,
                  onTap: () => onSelected(ratio),
                ),
              ),
            SizedBox(
              width: tileWidth,
              child: _CustomAspectRatioOption(
                selected: customSelected,
                onTap: onCustomSelected,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FullReferenceCacheSection extends StatelessWidget {
  const _FullReferenceCacheSection();

  @override
  Widget build(BuildContext context) {
    return const _SettingsSection(
      title: '\u7f13\u5b58\u5185\u5bb9',
      children: [
        _CacheTargetCard(
          icon: LucideIcons.images,
          title: '\u5b8c\u6574\u53c2\u8003\u56fe\u7f13\u5b58',
          subtitle:
              '\u6e05\u9664\u76f8\u673a\u53c2\u8003\u548c\u5927\u56fe\u67e5\u770b\u4f7f\u7528\u7684\u5b8c\u6574\u53c2\u8003\u56fe\u3002\u7f29\u7565\u56fe\u7f13\u5b58\u4f1a\u4fdd\u7559\uff0c\u4ee5\u4fdd\u6301\u5217\u8868\u548c\u5730\u56fe\u52a0\u8f7d\u901f\u5ea6\u3002',
        ),
      ],
    );
  }
}

class _CacheTargetCard extends StatelessWidget {
  const _CacheTargetCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleTextStyle),
                const SizedBox(height: 4),
                Text(subtitle, style: _secondaryParagraphTextStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomAspectRatioOption extends StatelessWidget {
  const _CustomAspectRatioOption({required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '\u81ea\u5b9a\u4e49',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.onAccent : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomAspectRatioDialog extends StatefulWidget {
  const _CustomAspectRatioDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_CustomAspectRatioDialog> createState() =>
      _CustomAspectRatioDialogState();
}

class _CustomAspectRatioDialogState extends State<_CustomAspectRatioDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: _formatRatioNumber(widget.settings.customCameraAspectRatioWidth),
    );
    _heightController = TextEditingController(
      text: _formatRatioNumber(widget.settings.customCameraAspectRatioHeight),
    );
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _submit() {
    final width = double.tryParse(_widthController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    if (width == null || height == null || width <= 0 || height <= 0) {
      setState(() => _errorText = '请输入有效比例');
      return;
    }
    Navigator.of(context).pop((width: width, height: height));
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '\u81ea\u5b9a\u4e49\u6bd4\u4f8b',
      errorText: _errorText,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppDialogField(
              label: '\u5bbd',
              child: TextField(
                onTapOutside: dismissKeyboardOnTapOutside,
                controller: _widthController,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: appDialogInputDecoration(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              ':',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: AppDialogField(
              label: '\u9ad8',
              child: TextField(
                onTapOutside: dismissKeyboardOnTapOutside,
                controller: _heightController,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: appDialogInputDecoration(),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ],
      ),
      confirmLabel: '\u4fdd\u5b58',
      onConfirm: _submit,
    );
  }
}

String _formatRatioNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _AspectRatioOption extends StatelessWidget {
  const _AspectRatioOption({
    required this.ratio,
    required this.selected,
    required this.onTap,
  });

  final CameraPhotoAspectRatio ratio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(LucideIcons.check, size: 13, color: AppColors.onAccent),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    ratio.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.onAccent
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              ratio.settingHintLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AppColors.onAccent.withValues(alpha: 0.86)
                    : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SettingsChrome(padding: const EdgeInsets.all(14), child: child);
  }
}

class _InlineSectionTitle extends StatelessWidget {
  const _InlineSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _titleTextStyle.copyWith(color: scheme.onSurface)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            subtitle,
            style: _captionTextStyle.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ThemeColorOption extends StatelessWidget {
  const _ThemeColorOption({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeSwatch(palette: palette, selected: selected),
          const SizedBox(height: 8),
          Text(
            palette.label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomThemeColorOption extends StatelessWidget {
  const _CustomThemeColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final CustomThemeColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ThemeColorButton(
      color: Color(color.value),
      label: color.name,
      selected: selected,
      icon: selected ? LucideIcons.check : null,
      onTap: onTap,
    );
  }
}

class _AddThemeColorOption extends StatelessWidget {
  const _AddThemeColorOption({
    required this.selected,
    required this.colorValue,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final int colorValue;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ThemeColorButton(
      color: Color(colorValue),
      label: label.trim().isEmpty ? '\u81ea\u5b9a\u4e49' : label.trim(),
      selected: selected,
      icon: LucideIcons.plus,
      onTap: onTap,
    );
  }
}

class _ThemeColorButton extends StatelessWidget {
  const _ThemeColorButton({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = color.computeLuminance() > 0.55
        ? AppColors.textPrimary
        : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: selected ? 42 : 38,
            height: selected ? 42 : 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: icon == null
                  ? null
                  : Icon(icon, color: foreground, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 58,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomThemeColorDialog extends StatefulWidget {
  const _CustomThemeColorDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_CustomThemeColorDialog> createState() =>
      _CustomThemeColorDialogState();
}

class _CustomThemeColorDialogState extends State<_CustomThemeColorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _hexController;
  late Color _color;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _color = Color(widget.settings.customThemeColorValue);
    _nameController = TextEditingController(
      text: widget.settings.customThemeColorName,
    );
    _hexController = TextEditingController(text: _hexFromColor(_color));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _setColor(Color color, {bool syncHex = true}) {
    setState(() {
      _color = color.withAlpha(255);
      if (syncHex) {
        _hexController.text = _hexFromColor(_color);
      }
    });
  }

  void _applyHex() {
    final color = _colorFromHex(_hexController.text);
    if (color != null) {
      _setColor(color, syncHex: false);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final color = _colorFromHex(_hexController.text) ?? _color;
    if (name.isEmpty) {
      setState(() => _errorText = '请输入颜色名称');
      return;
    }
    Navigator.of(
      context,
    ).pop(CustomThemeColor(name: name, value: color.withAlpha(255).toARGB32()));
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '\u81ea\u5b9a\u4e49\u4e3b\u9898\u8272',
      errorText: _errorText,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _hexFromColor(_color),
              style: TextStyle(
                color: _color.computeLuminance() > 0.5
                    ? AppColors.textPrimary
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppDialogField(
            label: '\u540d\u79f0',
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              controller: _nameController,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              decoration: appDialogInputDecoration(),
            ),
          ),
          const SizedBox(height: 10),
          AppDialogField(
            label: '\u8272\u53f7',
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              key: const ValueKey('custom-theme-color-hex-field'),
              controller: _hexController,
              decoration: appDialogInputDecoration(hintText: '#0F8B8D'),
              onChanged: (_) => _applyHex(),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 14),
          _HsvColorPalette(color: _color, onChanged: _setColor),
        ],
      ),
      confirmLabel: '\u6dfb\u52a0',
      onConfirm: _submit,
    );
  }
}

class _HsvColorPalette extends StatelessWidget {
  const _HsvColorPalette({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final paletteSize = math.min(constraints.maxWidth - 44, 230.0);

        void updateHueSaturation(Offset position) {
          final hue = (position.dx.clamp(0, paletteSize) / paletteSize * 360)
              .clamp(0.0, 359.999);
          final saturation =
              1 - position.dy.clamp(0, paletteSize) / paletteSize;
          onChanged(
            hsv
                .withHue(hue)
                .withSaturation(saturation)
                .toColor()
                .withAlpha(255),
          );
        }

        void updateValue(double y) {
          final value = 1 - y.clamp(0, paletteSize) / paletteSize;
          onChanged(hsv.withValue(value).toColor().withAlpha(255));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              slider: true,
              label: '色相和饱和度',
              value:
                  '色相 ${hsv.hue.round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              increasedValue:
                  '色相 ${((hsv.hue + 5) % 360).round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              decreasedValue:
                  '色相 ${((hsv.hue - 5) % 360).round()} 度，饱和度 ${(hsv.saturation * 100).round()}%',
              onIncrease: () => onChanged(
                hsv.withHue((hsv.hue + 5) % 360).toColor().withAlpha(255),
              ),
              onDecrease: () => onChanged(
                hsv.withHue((hsv.hue - 5) % 360).toColor().withAlpha(255),
              ),
              child: GestureDetector(
                key: const ValueKey('custom-theme-color-palette'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    updateHueSaturation(details.localPosition),
                onPanDown: (details) =>
                    updateHueSaturation(details.localPosition),
                onPanUpdate: (details) =>
                    updateHueSaturation(details.localPosition),
                child: CustomPaint(
                  size: Size.square(paletteSize),
                  painter: _HueSaturationPalettePainter(hsv),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              slider: true,
              label: '明度',
              value: '${(hsv.value * 100).round()}%',
              increasedValue:
                  '${((hsv.value + 0.05).clamp(0.0, 1.0) * 100).round()}%',
              decreasedValue:
                  '${((hsv.value - 0.05).clamp(0.0, 1.0) * 100).round()}%',
              onIncrease: () => onChanged(
                hsv
                    .withValue((hsv.value + 0.05).clamp(0.0, 1.0))
                    .toColor()
                    .withAlpha(255),
              ),
              onDecrease: () => onChanged(
                hsv
                    .withValue((hsv.value - 0.05).clamp(0.0, 1.0))
                    .toColor()
                    .withAlpha(255),
              ),
              child: GestureDetector(
                key: const ValueKey('custom-theme-color-value'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => updateValue(details.localPosition.dy),
                onPanDown: (details) => updateValue(details.localPosition.dy),
                onPanUpdate: (details) => updateValue(details.localPosition.dy),
                child: CustomPaint(
                  size: Size(28, paletteSize),
                  painter: _ColorValuePainter(hsv),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HueSaturationPalettePainter extends CustomPainter {
  const _HueSaturationPalettePainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );

    final selector = Offset(
      hsv.hue / 360 * size.width,
      (1 - hsv.saturation) * size.height,
    );
    canvas.drawCircle(
      selector,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
    canvas.drawCircle(
      selector,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_HueSaturationPalettePainter oldDelegate) {
    return oldDelegate.hsv.hue != hsv.hue ||
        oldDelegate.hsv.saturation != hsv.saturation;
  }
}

class _ColorValuePainter extends CustomPainter {
  const _ColorValuePainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 12.0;
    final rect = Rect.fromLTWH(
      (size.width - barWidth) / 2,
      0,
      barWidth,
      size.height,
    );
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hsv.withValue(1).toColor(), Colors.black],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );

    final selector = Offset(size.width / 2, (1 - hsv.value) * size.height);
    canvas.drawCircle(selector, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      selector,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_ColorValuePainter oldDelegate) {
    return oldDelegate.hsv.hue != hsv.hue ||
        oldDelegate.hsv.saturation != hsv.saturation ||
        oldDelegate.hsv.value != hsv.value;
  }
}

String _hexFromColor(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

Color? _colorFromHex(String source) {
  final normalized = source.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
    return null;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected ? AppColors.accent : scheme.outline;
    final foreground = selected ? AppColors.accent : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
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

class _ScaleStepper extends StatelessWidget {
  const _ScaleStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperIconButton(icon: LucideIcons.minus, onTap: onDecrease),
          Container(
            width: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: AppColors.border),
              ),
            ),
            child: Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          _StepperIconButton(icon: LucideIcons.plus, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _PercentScaleControl extends StatelessWidget {
  const _PercentScaleControl({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.tickLabels,
    required this.onChanged,
    this.showStepper = true,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final List<String> tickLabels;
  final ValueChanged<double> onChanged;
  final bool showStepper;

  double get _step => (max - min) / divisions;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max);
    return Column(
      children: [
        if (showStepper) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _ScaleStepper(
              value: clampedValue,
              onDecrease: () {
                onChanged((clampedValue - _step).clamp(min, max));
              },
              onIncrease: () {
                onChanged((clampedValue + _step).clamp(min, max));
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: clampedValue,
            label: '${(clampedValue * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in tickLabels)
                Text(label, style: _captionTextStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FontSizeButton extends StatelessWidget {
  const _FontSizeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnitabiServiceRow extends StatelessWidget {
  const _AnitabiServiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.url,
    required this.onTap,
    this.status,
    this.testing = false,
  });

  final IconData icon;
  final String title;
  final String url;
  final VoidCallback onTap;
  final String? status;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final compactStatus = status == null
        ? null
        : _compactAnitabiProbeStatus(status!);
    final succeeded = status?.startsWith('连接成功') ?? false;
    final statusColor = succeeded ? AppColors.accent : AppColors.error;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _secondaryTextStyle,
                  ),
                ],
              ),
            ),
            if (testing) ...[
              const SizedBox(width: 8),
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (compactStatus != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: Text(
                  compactStatus,
                  key: ValueKey('anitabi-service-status-$title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            Icon(
              LucideIcons.chevronRight,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

String _compactAnitabiProbeStatus(String result) {
  if (result.startsWith('连接成功')) {
    final match = RegExp(r'(\d+)\s*ms').firstMatch(result);
    if (match != null) {
      return '成功 · ${match.group(1)}ms';
    }
    return '成功';
  }
  return '失败';
}

class _AnitabiServiceEntryRow extends StatelessWidget {
  const _AnitabiServiceEntryRow({
    super.key,
    required this.siteUrl,
    required this.usingDefaults,
    required this.onTap,
  });

  final String siteUrl;
  final bool usingDefaults;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(LucideIcons.network, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    siteUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    usingDefaults ? '使用默认地址，点击管理全部服务' : '已自定义，点击管理全部服务',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _secondaryTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              LucideIcons.chevronRight,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapUrlRow extends StatelessWidget {
  const _MapUrlRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _secondaryTextStyle,
              ),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.edit, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MapSourceGrid extends StatelessWidget {
  const _MapSourceGrid({
    required this.selectedProvider,
    required this.onSelected,
  });

  final MapTileProvider selectedProvider;
  final ValueChanged<MapTileProvider> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final option in mapTileProviderOptions)
              SizedBox(
                width: tileWidth,
                child: _MapSourceOptionCard(
                  option: option,
                  selected: selectedProvider == option.provider,
                  onTap: () => onSelected(option.provider),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpenFreeMapStyleGrid extends StatelessWidget {
  const _OpenFreeMapStyleGrid({
    required this.selectedStyle,
    required this.onSelected,
  });

  final OpenFreeMapStyle selectedStyle;
  final ValueChanged<OpenFreeMapStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CompactOptionWrap(
      children: [
        for (final option in openFreeMapStyleOptions)
          _CompactOptionChip(
            label: option.label,
            selected: selectedStyle == option.style,
            icon: LucideIcons.layers,
            onTap: () => onSelected(option.style),
          ),
      ],
    );
  }
}

class _AnitabiImageSourceGrid extends StatelessWidget {
  const _AnitabiImageSourceGrid({
    required this.selectedSource,
    required this.onSelected,
  });

  final AnitabiImageSource selectedSource;
  final ValueChanged<AnitabiImageSource> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CompactOptionWrap(
      children: [
        for (final source in AnitabiImageSource.values)
          _CompactOptionChip(
            label: _anitabiImageSourceLabel(source),
            selected: selectedSource == source,
            icon: _anitabiImageSourceIcon(source),
            onTap: () => onSelected(source),
          ),
      ],
    );
  }
}

class _CompactOptionWrap extends StatelessWidget {
  const _CompactOptionWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _CompactOptionChip extends StatelessWidget {
  const _CompactOptionChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? LucideIcons.check : icon,
              color: selected ? AppColors.onAccent : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onAccent : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSourceOptionCard extends StatelessWidget {
  const _MapSourceOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MapTileProviderOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.check : _mapProviderIcon(option.provider),
              color: selected ? AppColors.onAccent : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.onAccent
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mapProviderHint(option.provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.onAccent.withValues(alpha: 0.82)
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationAppGrid extends StatelessWidget {
  const _NavigationAppGrid({
    required this.selectedApp,
    required this.onSelected,
  });

  final NavigationApp selectedApp;
  final ValueChanged<NavigationApp> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final app in NavigationApp.values)
              SizedBox(
                width: tileWidth,
                child: _NavigationAppOptionCard(
                  app: app,
                  selected: selectedApp == app,
                  onTap: () => onSelected(app),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NavigationAppOptionCard extends StatelessWidget {
  const _NavigationAppOptionCard({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  final NavigationApp app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.check : _navigationAppIcon(app),
              color: selected ? AppColors.onAccent : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.onAccent
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _navigationAppHint(app),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.onAccent.withValues(alpha: 0.82)
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _mapProviderIcon(MapTileProvider provider) {
  return switch (provider) {
    MapTileProvider.openFreeMap => LucideIcons.map,
    MapTileProvider.openStreetMap => LucideIcons.globe,
    MapTileProvider.customXyz => LucideIcons.grid3X3,
    MapTileProvider.customMapLibreStyle => LucideIcons.braces,
  };
}

IconData _navigationAppIcon(NavigationApp app) {
  return switch (app) {
    NavigationApp.googleMaps => LucideIcons.compass,
    NavigationApp.amap => LucideIcons.navigation,
    NavigationApp.appleMaps => LucideIcons.map,
    NavigationApp.baiduMaps => LucideIcons.signpost,
  };
}

String _navigationAppHint(NavigationApp app) {
  return switch (app) {
    NavigationApp.googleMaps => '\u9ed8\u8ba4\u9009\u9879',
    NavigationApp.amap => '\u56fd\u5185\u5e38\u7528',
    NavigationApp.appleMaps => 'iOS \u539f\u751f',
    NavigationApp.baiduMaps => '\u57ce\u5e02\u5bfc\u822a',
  };
}

String _navigationAppDescription(NavigationApp app) {
  return switch (app) {
    NavigationApp.googleMaps => '导航按钮会通过 Google Maps 官方 Maps URL 打开步行路线。',
    NavigationApp.appleMaps => '导航按钮会通过 Apple Map Links 打开步行路线。',
    NavigationApp.amap => '导航按钮会通过高德 URI API 打开步行路线，并使用 WGS84 坐标。',
    NavigationApp.baiduMaps => '导航按钮会通过百度地图 URI API 打开步行路线，并使用 WGS84 坐标。',
  };
}

String _mapProviderHint(MapTileProvider provider) {
  return switch (provider) {
    MapTileProvider.openFreeMap => '\u63a8\u8350\u9ed8\u8ba4',
    MapTileProvider.openStreetMap => '\u6807\u51c6\u74e6\u7247',
    MapTileProvider.customXyz => '\u74e6\u7247\u6a21\u677f',
    MapTileProvider.customMapLibreStyle => '\u6837\u5f0f URL',
  };
}

bool _usesDefaultAnitabiService(AppSettings settings) {
  return settings.anitabiSiteBaseUrl == defaultAnitabiSiteBaseUrl &&
      settings.anitabiStaticDataBaseUrl == defaultAnitabiStaticDataBaseUrl &&
      settings.anitabiApiBaseUrl == defaultAnitabiApiBaseUrl &&
      settings.anitabiOfficialImageBaseUrl ==
          defaultAnitabiOfficialImageBaseUrl &&
      settings.anitabiMirrorImageBaseUrl == defaultAnitabiMirrorImageBaseUrl;
}

String _anitabiImageSourceLabel(AnitabiImageSource source) {
  return switch (source) {
    AnitabiImageSource.auto => '自动选择',
    AnitabiImageSource.official => '官方默认',
    AnitabiImageSource.mirror => '备用源',
  };
}

String _anitabiImageSourceDescription(AppSettings settings) {
  return switch (settings.anitabiImageSource) {
    AnitabiImageSource.auto =>
      '优先使用 ${settings.anitabiOfficialImageBaseUrl}；失败后尝试 ${settings.anitabiMirrorImageBaseUrl}。',
    AnitabiImageSource.official =>
      '固定使用 ${settings.anitabiOfficialImageBaseUrl}。',
    AnitabiImageSource.mirror => '固定使用 ${settings.anitabiMirrorImageBaseUrl}。',
  };
}

IconData _anitabiImageSourceIcon(AnitabiImageSource source) {
  return switch (source) {
    AnitabiImageSource.auto => LucideIcons.sparkles,
    AnitabiImageSource.official => LucideIcons.image,
    AnitabiImageSource.mirror => LucideIcons.arrowLeftRight,
  };
}

class _AboutInfoTile extends StatelessWidget {
  const _AboutInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _captionTextStyle),
                const SizedBox(height: 2),
                CopyableText(
                  text: value,
                  copyLabel: value,
                  style: const TextStyle(fontSize: 14, letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutDataItem extends StatelessWidget {
  const _AboutDataItem({
    required this.icon,
    required this.label,
    required this.description,
    this.bottomSpacing = 12,
  });

  final IconData icon;
  final String label;
  final String description;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _captionTextStyle),
                const SizedBox(height: 2),
                Text(description, style: _secondaryParagraphTextStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIconMark extends StatelessWidget {
  const _AppIconMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Image.asset('icon.jpg', fit: BoxFit.cover),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.palette,
    this.selected = false,
    this.customColorValue,
  });

  final AppThemePalette palette;
  final bool selected;
  final int? customColorValue;

  @override
  Widget build(BuildContext context) {
    final color = switch (palette) {
      AppThemePalette.classicGreen => AppColors.classicGreen,
      AppThemePalette.deepBlue => AppColors.deepBlue,
      AppThemePalette.cherryPink => AppColors.cherryPink,
      AppThemePalette.twilightPurple => AppColors.twilightPurple,
      AppThemePalette.miriaYellow => AppColors.miriaYellow,
      AppThemePalette.graphite => AppColors.graphite,
      AppThemePalette.aurora => Color(
        customColorValue ?? AppColors.customAccentValue,
      ),
    };
    return Container(
      width: selected ? 42 : 38,
      height: selected ? 42 : 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: selected
            ? Icon(LucideIcons.check, color: AppColors.onAccent, size: 18)
            : null,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: CopyableText(
            text: text,
            copyLabel: text,
            style: const TextStyle(fontSize: 14, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}

TextStyle get _cardTitleTextStyle => TextStyle(
  color: AppColors.textPrimary,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

TextStyle get _titleTextStyle => TextStyle(
  color: AppColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

TextStyle get _secondaryTextStyle =>
    TextStyle(color: AppColors.textSecondary, fontSize: 13, letterSpacing: 0);

TextStyle get _captionTextStyle => TextStyle(
  color: AppColors.textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

TextStyle get _secondaryParagraphTextStyle => TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13,
  height: 1.45,
  letterSpacing: 0,
);
