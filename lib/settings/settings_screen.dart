import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  Widget build(BuildContext context) {
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
                min: 0.1,
                max: 20,
                divisions: 199,
                values: RangeValues(
                  settings.cameraMinZoom.clamp(0.1, settings.cameraMaxZoom),
                  settings.cameraMaxZoom.clamp(settings.cameraMinZoom, 20.0),
                ),
                labels: RangeLabels(
                  '${settings.cameraMinZoom.toStringAsFixed(1)}x',
                  '${settings.cameraMaxZoom.toStringAsFixed(1)}x',
                ),
                onChanged: (values) {
                  onChanged(
                    settings.copyWith(
                      cameraMinZoom: values.start,
                      cameraMaxZoom: values.end,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '拍摄',
            children: [
              SegmentedButton<CameraPhotoAspectRatio>(
                segments: const [
                  ButtonSegment(
                    value: CameraPhotoAspectRatio.landscape16x9,
                    icon: Icon(Icons.crop_16_9, size: 18),
                    label: Text('16:9'),
                  ),
                  ButtonSegment(
                    value: CameraPhotoAspectRatio.standard4x3,
                    icon: Icon(Icons.crop_5_4, size: 18),
                    label: Text('4:3'),
                  ),
                  ButtonSegment(
                    value: CameraPhotoAspectRatio.square1x1,
                    icon: Icon(Icons.crop_square, size: 18),
                    label: Text('1:1'),
                  ),
                ],
                selected: {settings.cameraAspectRatio},
                onSelectionChanged: (selected) {
                  onChanged(
                    settings.copyWith(cameraAspectRatio: selected.single),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SettingsSection(
            title: '作者',
            children: [
              _InfoRow(icon: Icons.person_outline, text: 'BilyHurington'),
              SizedBox(height: 10),
              _InfoRow(
                icon: Icons.mail_outline,
                text: 'bilyhurington@gmail.com',
              ),
              SizedBox(height: 10),
              _InfoRow(
                icon: Icons.code_outlined,
                text: 'github.com/BilyHurington/seichi-junrei-helper',
              ),
            ],
          ),
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
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
