import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../app_theme.dart';
import '../camera_reference/camera_zoom_capabilities.dart';
import '../desktop/tauri_bridge.dart';
import '../map/map_tile_config.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/copyable_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CameraZoomCapabilities _zoomCapabilities = CameraZoomCapabilities.fallback;
  DesktopLauncherInfo? _desktopLauncherInfo;
  var _desktopLauncherLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadZoomCapabilities();
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

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final onChanged = widget.onChanged;
    final zoomRangeMin = _zoomCapabilities.minZoom;
    final zoomRangeMax = _zoomCapabilities.maxZoom.clamp(
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

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsSection(
            title: '显示',
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.palette_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '主题色 ${settings.themePalette.label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemePalette.values
                    .map((palette) {
                      final selected = settings.themePalette == palette;
                      return ChoiceChip(
                        label: Text(palette.label),
                        avatar: _ThemeSwatch(palette: palette),
                        selected: selected,
                        onSelected: (_) {
                          onChanged(settings.copyWith(themePalette: palette));
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.zoom_out_map_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '页面缩放 ${(settings.uiScale * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                min: 0.5,
                max: 2,
                divisions: 30,
                value: settings.uiScale.clamp(0.5, 2.0),
                label: '${(settings.uiScale * 100).round()}%',
                onChanged: (value) {
                  onChanged(settings.copyWith(uiScale: value));
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.zoom_in_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '相机缩放 ${settings.cameraMinZoom.toStringAsFixed(1)}x - ${settings.cameraMaxZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              RangeSlider(
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
                  onChanged(
                    settings.copyWith(
                      cameraMinZoom: minZoom.clamp(zoomRangeMin, zoomRangeMax),
                      cameraMaxZoom: maxZoom.clamp(minZoom, zoomRangeMax),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.photo_size_select_large_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '参考图显示 ${(settings.referenceImageScale * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                min: 0.8,
                max: 1,
                divisions: 20,
                value: settings.referenceImageScale.clamp(0.8, 1.0),
                label: '${(settings.referenceImageScale * 100).round()}%',
                onChanged: (value) {
                  onChanged(settings.copyWith(referenceImageScale: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '拍摄图片比例',
            children: [
              const Text(
                '自动会优先跟随参考图比例；选择固定比例后会按该比例拍摄。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          CameraPhotoAspectRatio.auto,
                          ..._cameraAspectRatioGroup(
                            includePortrait: true,
                            includeSquare: false,
                          ),
                        ]
                        .map((ratio) {
                          final selected =
                              settings.cameraCaptureAspectRatio == ratio;
                          return ChoiceChip(
                            label: Text(ratio.label),
                            selected: selected,
                            onSelected: (_) {
                              onChanged(
                                settings.copyWith(
                                  cameraCaptureAspectRatio: ratio,
                                ),
                              );
                            },
                          );
                        })
                        .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '无参考图时比例',
            children: [
              const Text(
                '拍摄图片比例为自动、且没有参考图可对齐时使用。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          CameraPhotoAspectRatio.native,
                          ..._cameraAspectRatioGroup(
                            includePortrait: true,
                            includeSquare: false,
                          ),
                        ]
                        .map((ratio) {
                          final selected =
                              settings.cameraFallbackAspectRatio == ratio;
                          return ChoiceChip(
                            label: Text(ratio.label),
                            selected: selected,
                            onSelected: (_) {
                              onChanged(
                                settings.copyWith(
                                  cameraFallbackAspectRatio: ratio,
                                ),
                              );
                            },
                          );
                        })
                        .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_shouldShowGalleryBackupOption) ...[
            _SettingsSection(
              title: '照片备份',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    '保存巡礼照片到相册',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  subtitle: const Text(
                    '保存记录时同时备份一张巡礼照片。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                  value: settings.saveVisitPhotoToGallery,
                  onChanged: (value) {
                    onChanged(
                      settings.copyWith(saveVisitPhotoToGallery: value),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _SettingsSection(
            title: '地图',
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '地图源 ${mapTileProviderOption(settings.mapTileProvider).label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mapTileProviderOptions
                    .map((option) {
                      final selected =
                          settings.mapTileProvider == option.provider;
                      return ChoiceChip(
                        label: Text(option.label),
                        selected: selected,
                        onSelected: (_) {
                          onChanged(
                            settings.copyWith(mapTileProvider: option.provider),
                          );
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              Text(
                mapTileProviderOption(settings.mapTileProvider).description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              if (settings.mapTileProvider == MapTileProvider.customXyz) ...[
                const SizedBox(height: 12),
                _MapUrlRow(
                  icon: Icons.grid_3x3_outlined,
                  label: settings.customXyzTileUrl.trim().isEmpty
                      ? '未设置自定义 XYZ URL'
                      : settings.customXyzTileUrl.trim(),
                  onTap: () => _showMapUrlDialog(
                    title: '自定义 XYZ URL',
                    initialValue: settings.customXyzTileUrl,
                    helperText: 'URL 需要包含 {z}、{x}、{y}。',
                    validator: (value) =>
                        isValidXyzTileUrl(value.trim()) ? null : 'URL 格式无效',
                    onSaved: (value) {
                      onChanged(
                        settings.copyWith(customXyzTileUrl: value.trim()),
                      );
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
                  onTap: () => _showMapUrlDialog(
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
                      onChanged(
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
          if (_shouldShowDesktopSection) ...[
            _SettingsSection(
              title: '桌面端',
              children: [
                _InfoRow(
                  icon: Icons.desktop_windows_outlined,
                  text: _desktopLauncherStatusText,
                ),
                if (_desktopLauncherInfo != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    text: _desktopLauncherInfo!.dataDir,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    text: _desktopLauncherInfo!.assetsDir,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          const _SettingsSection(
            title: '关于',
            children: [
              Row(
                children: [
                  _AppIconMark(),
                  SizedBox(width: 12),
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
                        Text(
                          '动漫圣地巡礼计划与拍摄参考工具',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              _InfoRow(icon: Icons.new_releases_outlined, text: '版本 1.1.2'),
              SizedBox(height: 10),
              _InfoRow(icon: Icons.person_outline, text: 'BilyHurington'),
              SizedBox(height: 10),
              _InfoRow(
                icon: Icons.mail_outline,
                text: 'bilyhurington@gmail.com',
              ),
              SizedBox(height: 10),
              _InfoRow(
                icon: Icons.code_outlined,
                text: 'github.com/BilyHurington/MiriaGo',
              ),
              SizedBox(height: 10),
              _InfoRow(icon: Icons.balance_outlined, text: 'MIT License'),
              SizedBox(height: 12),
              Text(
                '地图可使用 OpenFreeMap、OpenStreetMap 或自定义服务；作品搜索使用 Bangumi；巡礼点位与参考图来自 Anitabi。第三方数据、截图和图片版权归原平台、贡献者或权利方所有。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  bool get _shouldShowGalleryBackupOption {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

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

List<CameraPhotoAspectRatio> _cameraAspectRatioGroup({
  required bool includePortrait,
  required bool includeSquare,
}) {
  return [
    CameraPhotoAspectRatio.landscape16x9,
    CameraPhotoAspectRatio.cinema21x9,
    CameraPhotoAspectRatio.standard4x3,
    CameraPhotoAspectRatio.photo3x2,
    if (includePortrait) ...[
      CameraPhotoAspectRatio.portrait9x16,
      CameraPhotoAspectRatio.portrait9x21,
      CameraPhotoAspectRatio.portrait3x4,
      CameraPhotoAspectRatio.portrait2x3,
    ],
    if (includeSquare) CameraPhotoAspectRatio.square1x1,
  ];
}

extension _ZoomStepSnap on double {
  double snapToZoomStep() => (this * 10).round() / 10;
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
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
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

class _AppIconMark extends StatelessWidget {
  const _AppIconMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Icons.explore_outlined, color: AppColors.onAccent, size: 28),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final color = switch (palette) {
      AppThemePalette.miriaYellow => AppColors.miriaYellow,
      AppThemePalette.classicGreen => AppColors.classicGreen,
    };
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
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
