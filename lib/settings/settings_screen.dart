import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../app_version.dart';
import '../camera_reference/camera_zoom_capabilities.dart';
import '../data/pilgrimage_repository.dart';
import '../desktop/tauri_bridge.dart';
import '../map/map_tile_config.dart';
import '../plan/pilgrimage_models.dart';
import '../records/comparison_export_config.dart';
import '../records/comparison_export_config_editor.dart';
import '../records/comparison_export_config_storage_stub.dart'
    if (dart.library.io) '../records/comparison_export_config_storage_io.dart';
import '../widgets/copyable_text.dart';

bool get _showFutureThemeModeSettings => false;
bool get _showFutureNavigationAppSettings => false;
bool get _showFutureCacheCleanupSettings => false;
bool get _shouldShowMobileGallerySettings {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

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
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '恢复初始设置',
            onPressed: _confirmResetSettings,
            icon: const Icon(Icons.restart_alt_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: Icons.palette_outlined,
              title: '外观设置',
              subtitle: '主题色、缩放、显示等',
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
                    icon: Icons.circle,
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
                    icon: Icons.zoom_out_map_outlined,
                    title: '页面缩放',
                    value: '${(settings.uiScale * 100).round()}%',
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
              icon: Icons.photo_camera_outlined,
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
                    icon: Icons.crop_outlined,
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
                    icon: Icons.view_sidebar_outlined,
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
              if (_shouldShowMobileGallerySettings) ...[
                const _SettingsDivider(),
                _SummarySwitchTile(
                  icon: Icons.cloud_upload_outlined,
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
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            header: _SettingsCardHeader(
              icon: Icons.compare_arrows_outlined,
              title: '对比图设置',
              subtitle: '导出样式、自动保存到相册',
              onTap: () => _openComparisonStyleSettings(settings),
            ),
            children: [
              if (_shouldShowMobileGallerySettings) ...[
                _SummarySwitchTile(
                  icon: Icons.photo_library_outlined,
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
              icon: Icons.map_outlined,
              title: '数据源设置',
              subtitle: '地图源、图片源等',
              onTap: () => _pushDetail(
                _MapSettingsPage(
                  settings: settings,
                  onChanged: widget.onChanged,
                  showMapUrlDialog: _showMapUrlDialog,
                ),
              ),
            ),
          ),
          if (_showFutureCacheCleanupSettings) ...[
            const SizedBox(height: 12),
            _SettingsCard(
              header: _SettingsCardHeader(
                icon: Icons.cleaning_services_outlined,
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
                icon: Icons.desktop_windows_outlined,
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
              icon: Icons.info_outline,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('恢复初始设置'),
          content: const Text('所有外观、拍摄和地图设置将恢复为默认值。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('恢复'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    widget.onChanged(const AppSettings());
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
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                helperText: helperText,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              validator: (value) => validator(value ?? ''),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('保存'),
            ),
          ],
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
    AppColors.palette = settings.themePalette;
    AppColors.customAccentValue = settings.customThemeColorValue;

    return Theme(
      data: AppTheme.light(
        palette: settings.themePalette,
        customAccentValue: settings.customThemeColorValue,
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
                  title: '\u4e3b\u9898\u8272',
                  subtitle: '\u5f71\u54cd\u5e94\u7528\u6574\u4f53\u914d\u8272',
                ),
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
                if (_showFutureThemeModeSettings) ...[
                  const SizedBox(height: 22),
                  const Text(
                    '\u4e3b\u9898\u6a21\u5f0f',
                    style: _titleTextStyle,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          icon: Icons.wb_sunny_outlined,
                          label: '\u6d45\u8272\u6a21\u5f0f',
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
                          icon: Icons.dark_mode_outlined,
                          label: '\u6df1\u8272\u6a21\u5f0f',
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
                          icon: Icons.phone_iphone_outlined,
                          label: '\u8ddf\u968f\u7cfb\u7edf',
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
                ],
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
                    const Icon(
                      Icons.fit_screen_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
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
                const Padding(
                  padding: EdgeInsets.only(left: 28, right: 8),
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
                    const Text('Aa', style: _titleTextStyle),
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
          children: [
            const Text(
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
          children: [
            const Text(
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
        if (_shouldShowMobileGallerySettings) ...[
          const SizedBox(height: 12),
          _SettingsSection(
            title: '照片备份',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.textSecondary,
                ),
                title: const Text('保存巡礼照片到相册', style: _titleTextStyle),
                subtitle: const Text(
                  '保存记录时同时备份一张巡礼照片。',
                  style: _secondaryTextStyle,
                ),
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
    final saved = await loadComparisonExportConfig();
    if (!mounted) {
      return;
    }

    final migratedConfig = (saved ?? _config).copyWith(
      showPilgrimName: settings.comparisonShowPilgrimName,
      pilgrimName: settings.comparisonPilgrimName.isEmpty
          ? saved?.pilgrimName
          : settings.comparisonPilgrimName,
    );
    final migratedSettings = migratedConfig.applyToSettings(settings);
    setState(() {
      _settings = migratedSettings;
      _config = migratedConfig;
      ComparisonExportConfig.lastUsed = migratedConfig;
      _pilgrimNameController.text = migratedConfig.pilgrimName;
      _loading = false;
    });
    if (migratedSettings.comparisonPilgrimName !=
            settings.comparisonPilgrimName ||
        migratedSettings.comparisonShowPilgrimName !=
            settings.comparisonShowPilgrimName) {
      await widget.repository.saveAppSettings(migratedSettings);
      widget.onChanged(migratedSettings);
    }
  }

  Future<void> _updateConfig(ComparisonExportConfig config) async {
    final settings = config.applyToSettings(_settings);
    setState(() {
      _config = config;
      _settings = settings;
    });
    ComparisonExportConfig.lastUsed = config;
    widget.onChanged(settings);
    await Future.wait([
      saveComparisonExportConfig(config),
      widget.repository.saveAppSettings(settings),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return _ScaledDetailScaffold(
      title: '对比图设置',
      uiScale: _settings.uiScale,
      fontScale: _settings.fontScale,
      children: [
        _SettingsSection(
          title: '默认配置',
          children: [
            Text(
              comparisonExportConfigSummary(_config),
              style: _secondaryTextStyle,
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 14),
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

class _MapSettingsPage extends StatefulWidget {
  const _MapSettingsPage({
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
  State<_MapSettingsPage> createState() => _MapSettingsPageState();
}

class _MapSettingsPageState extends State<_MapSettingsPage> {
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
                icon: Icons.layers_outlined,
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
                icon: Icons.grid_3x3_outlined,
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
                icon: Icons.data_object_outlined,
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
                icon: Icons.error_outline,
                text: validateMapTileSettings(settings)!,
              ),
            ],
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
              _anitabiImageSourceDescription(settings.anitabiImageSource),
              style: _secondaryTextStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: '地图缩略图',
          children: [
            _NumberStepperSetting(
              icon: Icons.photo_size_select_large_outlined,
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
            const SizedBox(height: 12),
            _NumberStepperSetting(
              icon: Icons.download_for_offline_outlined,
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
            const SizedBox(height: 8),
            const Text('阈值为 0 时不会在地图上显示缩略图。', style: _secondaryTextStyle),
          ],
        ),
        if (_showFutureNavigationAppSettings) ...[
          const SizedBox(height: 12),
          _SettingsSection(
            title: '\u5bfc\u822a\u8f6f\u4ef6 ${settings.navigationApp.label}',
            children: [
              _NavigationAppGrid(
                selectedApp: settings.navigationApp,
                onSelected: (app) {
                  _update(settings.copyWith(navigationApp: app));
                },
              ),
              const SizedBox(height: 10),
              const Text(
                '\u4ec5\u4fdd\u7559\u754c\u9762\u9009\u9879\uff0c\u6682\u4e0d\u63a5\u5165\u5b9e\u9645\u5bfc\u822a\u8df3\u8f6c\u3002',
                style: _secondaryTextStyle,
              ),
            ],
          ),
        ],
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
                  const _InfoRow(icon: Icons.error_outline, text: '计划列表读取失败'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _plansFuture = widget.repository.loadPlans();
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
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
                          icon: const Icon(Icons.select_all_outlined),
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
                          icon: const Icon(Icons.deselect_outlined),
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
                    onPressed: _selectedPlanIds.isEmpty
                        ? null
                        : _showCachePlaceholder,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text(
                      '\u6e05\u9664\u5b8c\u6574\u53c2\u8003\u56fe\u7f13\u5b58',
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

  void _showCachePlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('清除缓存功能尚未接入，仅展示界面。')));
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
              icon: Icons.desktop_windows_outlined,
              text: desktopLauncherStatusText,
            ),
            if (desktopLauncherInfo != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.folder_outlined,
                text: desktopLauncherInfo!.dataDir,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.inventory_2_outlined,
                text: desktopLauncherInfo!.assetsDir,
              ),
            ],
          ],
        ),
      ],
    );
  }
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
                const Expanded(
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
              icon: Icons.new_releases_outlined,
              label: '当前版本',
              value: appVersionLabel ?? '读取中',
            ),
            const _AboutInfoTile(
              icon: Icons.person_outline,
              label: '作者',
              value: 'BilyHurington',
            ),
            const _AboutInfoTile(
              icon: Icons.mail_outline,
              label: '联系邮箱',
              value: 'bilyhurington@gmail.com',
            ),
            const _AboutInfoTile(
              icon: Icons.code_outlined,
              label: '开源仓库',
              value: 'github.com/BilyHurington/MiriaGo',
            ),
            const _AboutInfoTile(
              icon: Icons.balance_outlined,
              label: '开源许可',
              value: 'MIT License',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SettingsSection(
          title: '数据与版权',
          children: [
            Text(
              '地图可使用 OpenFreeMap、OpenStreetMap 或自定义服务；作品搜索使用 Bangumi；巡礼点位与参考图来自 Anitabi。图片源设置只影响访问域名，远端链接会统一保留 Anitabi 默认格式。第三方数据、截图和图片版权归原平台、贡献者或权利方所有。',
              style: _secondaryParagraphTextStyle,
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
      appBar: AppBar(title: Text(title)),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.header, this.children = const []});

  final _SettingsCardHeader header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          header,
          if (children.isNotEmpty) ...[const _SettingsDivider(), ...children],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
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
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
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
    final tiles = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      tiles.add(
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: index == children.length - 1
                  ? null
                  : const Border(right: BorderSide(color: Color(0xFFE8ECF1))),
            ),
            child: children[index],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: tiles),
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
            swatch ?? Icon(icon, color: AppColors.textSecondary, size: 28),
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
                    style: _titleTextStyle,
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
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
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
            style: const TextStyle(
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
              icon: Icons.remove,
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            _NumberStepperIconButton(
              icon: Icons.add,
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
          side: const BorderSide(color: AppColors.border),
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
          icon: Icons.photo_library_outlined,
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
        height: 48,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u8bf7\u8f93\u5165\u6709\u6548\u6bd4\u4f8b'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((width: width, height: height));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('\u81ea\u5b9a\u4e49\u6bd4\u4f8b'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _widthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '\u5bbd'),
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
            child: TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '\u9ad8'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u53d6\u6d88'),
        ),
        FilledButton(onPressed: _submit, child: const Text('\u4fdd\u5b58')),
      ],
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
        height: 48,
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
                  Icon(Icons.check, size: 13, color: AppColors.onAccent),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InlineSectionTitle extends StatelessWidget {
  const _InlineSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _titleTextStyle),
        const SizedBox(width: 10),
        Flexible(child: Text(subtitle, style: _captionTextStyle)),
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
      icon: selected ? Icons.check : null,
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
      icon: Icons.add,
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u8bf7\u8f93\u5165\u989c\u8272\u540d\u79f0'),
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(CustomThemeColor(name: name, value: color.withAlpha(255).toARGB32()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('\u81ea\u5b9a\u4e49\u4e3b\u9898\u8272'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '\u540d\u79f0'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: '\u8272\u53f7',
                hintText: '#0F8B8D',
              ),
              onChanged: (_) => _applyHex(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            _ColorChannelSlider(
              label: 'R',
              value: _color.r.round(),
              onChanged: (value) => _setColor(
                Color.fromARGB(255, value, _color.g.round(), _color.b.round()),
              ),
            ),
            _ColorChannelSlider(
              label: 'G',
              value: _color.g.round(),
              onChanged: (value) => _setColor(
                Color.fromARGB(255, _color.r.round(), value, _color.b.round()),
              ),
            ),
            _ColorChannelSlider(
              label: 'B',
              value: _color.b.round(),
              onChanged: (value) => _setColor(
                Color.fromARGB(255, _color.r.round(), _color.g.round(), value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u53d6\u6d88'),
        ),
        FilledButton(onPressed: _submit, child: const Text('\u6dfb\u52a0')),
      ],
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label, style: _captionTextStyle)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: value.toString(),
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: _captionTextStyle,
          ),
        ),
      ],
    );
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.accent : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
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
          _StepperIconButton(icon: Icons.remove, onTap: onDecrease),
          Container(
            width: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
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
          _StepperIconButton(icon: Icons.add, onTap: onIncrease),
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

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE8ECF1));
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
            const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
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
            icon: Icons.layers_outlined,
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
              selected ? Icons.check : icon,
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
              selected ? Icons.check : _mapProviderIcon(option.provider),
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
              selected ? Icons.check : _navigationAppIcon(app),
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
    MapTileProvider.openFreeMap => Icons.map_outlined,
    MapTileProvider.openStreetMap => Icons.public_outlined,
    MapTileProvider.customXyz => Icons.grid_3x3_outlined,
    MapTileProvider.customMapLibreStyle => Icons.data_object_outlined,
  };
}

IconData _navigationAppIcon(NavigationApp app) {
  return switch (app) {
    NavigationApp.googleMaps => Icons.explore_outlined,
    NavigationApp.amap => Icons.near_me_outlined,
    NavigationApp.appleMaps => Icons.map_outlined,
    NavigationApp.baiduMaps => Icons.assistant_direction_outlined,
    NavigationApp.tencentMaps => Icons.navigation_outlined,
    NavigationApp.browser => Icons.language_outlined,
  };
}

String _navigationAppHint(NavigationApp app) {
  return switch (app) {
    NavigationApp.googleMaps => '\u9ed8\u8ba4\u9009\u9879',
    NavigationApp.amap => '\u56fd\u5185\u5e38\u7528',
    NavigationApp.appleMaps => 'iOS \u539f\u751f',
    NavigationApp.baiduMaps => '\u57ce\u5e02\u5bfc\u822a',
    NavigationApp.tencentMaps => '\u8f7b\u91cf\u5907\u9009',
    NavigationApp.browser => '\u7f51\u9875\u6253\u5f00',
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

String _anitabiImageSourceLabel(AnitabiImageSource source) {
  return switch (source) {
    AnitabiImageSource.auto => '自动选择',
    AnitabiImageSource.official => '官方默认',
    AnitabiImageSource.mirror => '备用源',
  };
}

String _anitabiImageSourceDescription(AnitabiImageSource source) {
  return switch (source) {
    AnitabiImageSource.auto =>
      '优先使用 image.anitabi.cn；如果下载到错误页或被拦截，会尝试 img-tc.anitabi.cn。',
    AnitabiImageSource.official => '固定使用 image.anitabi.cn，保留 Anitabi 官方默认图片源。',
    AnitabiImageSource.mirror => '固定使用 img-tc.anitabi.cn，适合官方默认源经常被拦截时使用。',
  };
}

IconData _anitabiImageSourceIcon(AnitabiImageSource source) {
  return switch (source) {
    AnitabiImageSource.auto => Icons.auto_awesome_outlined,
    AnitabiImageSource.official => Icons.image_outlined,
    AnitabiImageSource.mirror => Icons.swap_horiz_outlined,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
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
            ? Icon(Icons.check, color: AppColors.onAccent, size: 18)
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

const _cardTitleTextStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _titleTextStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

const _secondaryTextStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13,
  letterSpacing: 0,
);

const _captionTextStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

const _secondaryParagraphTextStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13,
  height: 1.45,
  letterSpacing: 0,
);
