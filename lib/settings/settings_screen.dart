import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../camera_reference/camera_zoom_capabilities.dart';
import '../desktop/tauri_bridge.dart';
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
    _loadDesktopLauncherInfo();
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
              _InfoRow(icon: Icons.new_releases_outlined, text: '版本 1.1.0'),
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
                '地图来自 OpenStreetMap；作品搜索使用 Bangumi；巡礼点位与参考图来自 Anitabi。第三方数据、截图和图片版权归原平台、贡献者或权利方所有。',
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
    final mode = info.fallbackUsed
        ? '系统数据目录'
        : info.portable
        ? '便携目录'
        : '应用数据目录';
    return '桌面启动器 可用 / ${info.platform} / $mode';
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
