import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/settings/settings_options.dart';
import '../../../../application/settings_store.dart';
import '../../../../plan/pilgrimage_models.dart';
import '../../../components/components.dart';
import '../settings_widgets.dart';

/// 地图显示: base map brightness, location, zoom, markers, group areas,
/// clustering and thumbnails.
class MapDisplaySettingsSection extends StatelessWidget {
  const MapDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: '底图明暗',
          children: [
            SettingsBlock(
              child: SegmentedControl<MapAppearance>(
                semanticLabel: '底图明暗',
                options: [
                  for (final appearance in MapAppearance.values)
                    SegmentOption(
                      value: appearance,
                      label: mapAppearanceLabel(appearance),
                      icon: switch (appearance) {
                        MapAppearance.automatic => Symbols.smartphone_rounded,
                        MapAppearance.light => Symbols.light_mode_rounded,
                        MapAppearance.dark => Symbols.dark_mode_rounded,
                      },
                    ),
                ],
                value: settings.mapAppearance,
                onChanged: (appearance) =>
                    store.patch((s) => s.copyWith(mapAppearance: appearance)),
              ),
            ),
            const SettingsNote('适用于 OpenFreeMap；Dark 始终使用深色，其他地图源保留原始样式。'),
          ],
        ),
        SettingsGroup(
          title: '当前位置',
          children: [
            SwitchRow(
              key: const ValueKey('continuous-map-location-switch'),
              leading: const Icon(Symbols.my_location_rounded),
              title: '持续更新当前位置',
              subtitle: '开启定位后持续更新；关闭时仅在点击定位时获取一次。',
              value: settings.continuousMapLocation,
              onChanged: (value) =>
                  store.patch((s) => s.copyWith(continuousMapLocation: value)),
            ),
          ],
        ),
        SettingsGroup(
          title: '地图缩放',
          children: [
            ScaleSliderRow(
              key: const ValueKey('map-max-zoom-slider'),
              icon: Symbols.zoom_in_rounded,
              title: '最大缩放倍率',
              subtitle: '控制所有地图能够放大的最大级别。',
              value: settings.mapMaxZoom.toDouble().clamp(16, 24),
              min: 16,
              max: 24,
              divisions: 8,
              format: (v) => '${v.round()} 级',
              tickLabels: const ['16', '18', '20', '22', '24'],
              onChanged: (value) =>
                  store.patch((s) => applyMapMaxZoom(s, value.round())),
            ),
          ],
        ),
        SettingsGroup(
          title: '地图标记',
          children: [
            SwitchRow(
              key: const ValueKey('hide-completed-points-on-map-toggle'),
              leading: const Icon(Symbols.visibility_off_rounded),
              title: '隐藏已完成点位',
              subtitle: '在地图页不显示已标记完成的点位。关闭后仍可在地图上看到全部点位。',
              value: settings.hideCompletedPointsOnMap,
              onChanged: (value) => store.patch(
                (s) => s.copyWith(hideCompletedPointsOnMap: value),
              ),
            ),
            ScaleSliderRow(
              key: const ValueKey('map-marker-scale'),
              icon: Symbols.location_on_rounded,
              title: '地图标记大小',
              subtitle: '统一调整点位、缩略图、聚合标记、当前位置和片区关键点的大小。',
              value: settings.mapMarkerScale.clamp(0.6, 1.2),
              min: 0.6,
              max: 1.2,
              divisions: 12,
              showStepper: true,
              tickLabels: const ['60%', '80%', '100%', '120%'],
              onChanged: (value) =>
                  store.patch((s) => s.copyWith(mapMarkerScale: value)),
            ),
          ],
        ),
        SettingsGroup(
          title: '片区范围',
          children: [
            NumberStepperRow(
              icon: Symbols.radio_button_checked_rounded,
              title: '片区范围半径',
              subtitle: '每个点位向外扩张的距离，用于生成地图上的片区轮廓。',
              value: settings.mapGroupAreaRadiusMeters,
              min: 25,
              max: 500,
              step: 25,
              format: (v) => '$v m',
              onChanged: (value) => store.patch(
                (s) => s.copyWith(mapGroupAreaRadiusMeters: value),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '地图点位聚合',
          children: [
            SwitchRow(
              key: const ValueKey('map-clustering-toggle'),
              leading: const Icon(Symbols.hub_rounded),
              title: '自动聚合密集点位',
              subtitle: '仅合并地图标记的显示；点位数据、选择和导入功能不受影响。',
              value: settings.mapMarkerClusteringEnabled,
              onChanged: (value) => store.patch(
                (s) => s.copyWith(mapMarkerClusteringEnabled: value),
              ),
            ),
            if (settings.mapMarkerClusteringEnabled) ...[
              NumberStepperRow(
                icon: Symbols.blur_circular_rounded,
                title: '聚合范围',
                subtitle: '屏幕上相距较近的点位会合并为一个带数量的聚合标记。',
                value: settings.mapMarkerClusterRadius,
                min: 32,
                max: 120,
                step: 8,
                format: (v) => '$v px',
                onChanged: (value) => store.patch(
                  (s) => s.copyWith(mapMarkerClusterRadius: value),
                ),
              ),
              NumberStepperRow(
                icon: Symbols.fullscreen_rounded,
                title: '停止聚合级别',
                subtitle: '地图放大超过该级别后显示每个原始点位。',
                value: settings.mapMarkerClusterMaxZoom,
                min: 10,
                max: clusterMaxZoomLimit(settings),
                step: 1,
                format: (v) => '$v 级',
                onChanged: (value) => store.patch(
                  (s) => s.copyWith(mapMarkerClusterMaxZoom: value),
                ),
              ),
            ],
          ],
        ),
        SettingsGroup(
          title: '地图缩略图',
          children: [
            NumberStepperRow(
              icon: Symbols.photo_size_select_actual_rounded,
              title: '缩略图显示阈值',
              subtitle:
                  '视图内点位不超过 ${settings.mapThumbnailVisibleThreshold} 个时显示缩略图；超过时仅显示圆点。',
              value: settings.mapThumbnailVisibleThreshold,
              min: 0,
              max: 200,
              step: 5,
              format: (v) => '$v 个',
              onChanged: (value) => store.patch(
                (s) => s.copyWith(mapThumbnailVisibleThreshold: value),
              ),
            ),
            const SettingsNote('阈值为 0 时不会在地图上显示缩略图。'),
          ],
        ),
      ],
    );
  }
}
