import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/settings/diagnostics_service.dart';
import '../../../../application/settings/settings_options.dart';
import '../../../../application/settings_store.dart';
import '../../../../data/valhalla_service_config.dart';
import '../../../../map/map_tile_config.dart';
import '../../../../plan/pilgrimage_models.dart';
import '../../../app/toast.dart';
import '../../../components/components.dart';
import '../settings_catalog.dart';
import '../settings_page.dart';
import '../settings_widgets.dart';

/// 数据源设置: map source, Anitabi services and image source, request
/// concurrency, navigation app and walking route service.
class DataSourceSettingsSection extends StatefulWidget {
  const DataSourceSettingsSection({this.diagnostics, super.key});

  /// Overridable for tests.
  final DiagnosticsService? diagnostics;

  @override
  State<DataSourceSettingsSection> createState() =>
      _DataSourceSettingsSectionState();
}

class _DataSourceSettingsSectionState extends State<DataSourceSettingsSection> {
  late final DiagnosticsService _diagnostics =
      widget.diagnostics ?? DiagnosticsService();
  bool _testingValhalla = false;

  Future<void> _testValhalla(String baseUrl) async {
    setState(() => _testingValhalla = true);
    try {
      await _diagnostics.testValhalla(baseUrl);
      if (mounted) {
        context.showToast('路径规划服务连接正常', kind: ToastKind.success);
      }
    } on Object catch (error) {
      if (mounted) {
        context.showToast(
          '路径规划服务连接失败',
          kind: ToastKind.error,
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _testingValhalla = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    final c = context.colors;
    final provider = mapTileProviderOption(settings.mapTileProvider);
    final validation = validateMapTileSettings(settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: '地图源 ${provider.label}',
          children: [
            SettingsBlock(
              child: OptionTileGrid<MapTileProvider>(
                maxColumns: 2,
                minTileWidth: 132,
                maxTileWidth: 400,
                options: [
                  for (final option in mapTileProviderOptions)
                    OptionTileData(
                      key: ValueKey('map-source-${option.provider.name}'),
                      value: option.provider,
                      label: option.label,
                      hint: mapProviderHint(option.provider),
                      icon: _mapProviderIcon(option.provider),
                    ),
                ],
                selected: settings.mapTileProvider,
                onSelected: (value) =>
                    store.patch((s) => s.copyWith(mapTileProvider: value)),
              ),
            ),
            SettingsNote(provider.description),
            if (settings.mapTileProvider == MapTileProvider.openFreeMap) ...[
              SettingsSubheading(
                'OpenFreeMap 样式 ${openFreeMapStyleOption(settings.openFreeMapStyle).label}',
                icon: Symbols.layers_rounded,
              ),
              SettingsBlock(
                child: ChipGroup<OpenFreeMapStyle>.single(
                  semanticLabel: 'OpenFreeMap 样式',
                  options: [
                    for (final option in openFreeMapStyleOptions)
                      ChipOption(value: option.style, label: option.label),
                  ],
                  value: settings.openFreeMapStyle,
                  onSelected: (style) =>
                      store.patch((s) => s.copyWith(openFreeMapStyle: style)),
                ),
              ),
              SettingsNote(
                openFreeMapStyleOption(settings.openFreeMapStyle).description,
              ),
            ],
            if (settings.mapTileProvider == MapTileProvider.customXyz)
              UrlRow(
                key: const ValueKey('custom-xyz-url'),
                icon: Symbols.grid_on_rounded,
                label: settings.customXyzTileUrl.trim().isEmpty
                    ? '未设置自定义 XYZ URL'
                    : settings.customXyzTileUrl.trim(),
                semanticLabel: '编辑自定义 XYZ URL',
                onTap: () async {
                  final value = await showUrlInputDialog(
                    context,
                    title: '自定义 XYZ URL',
                    initialValue: settings.customXyzTileUrl,
                    helperText: 'URL 需要包含 {z}、{x}、{y}。',
                    validator: (value) =>
                        isValidXyzTileUrl(value.trim()) ? null : 'URL 格式无效',
                  );
                  if (value == null) return;
                  await store.patch(
                    (s) => s.copyWith(customXyzTileUrl: value.trim()),
                  );
                },
              ),
            if (settings.mapTileProvider == MapTileProvider.customMapLibreStyle)
              UrlRow(
                key: const ValueKey('custom-maplibre-url'),
                icon: Symbols.data_object_rounded,
                label: settings.customMapLibreStyleUrl.trim().isEmpty
                    ? '未设置 MapLibre style URL'
                    : settings.customMapLibreStyleUrl.trim(),
                semanticLabel: '编辑 MapLibre style URL',
                onTap: () async {
                  final value = await showUrlInputDialog(
                    context,
                    title: 'MapLibre style URL',
                    initialValue: settings.customMapLibreStyleUrl,
                    helperText: 'URL 需要指向可公开读取的 style JSON。',
                    validator: (value) => validateMapTileSettings(
                      settings.copyWith(customMapLibreStyleUrl: value.trim()),
                    ),
                  );
                  if (value == null) return;
                  await store.patch(
                    (s) => s.copyWith(customMapLibreStyleUrl: value.trim()),
                  );
                },
              ),
            if (validation != null)
              SettingsBlock(
                child: InfoBanner(
                  kind: InfoBannerKind.warning,
                  message: validation,
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: 'Anitabi 服务地址',
          children: [
            ListRow(
              key: const ValueKey('anitabi-service-settings-entry'),
              leading: Icon(Symbols.lan_rounded, color: c.textSecondary),
              title: settings.anitabiSiteBaseUrl,
              titleMaxLines: 1,
              subtitle: usesDefaultAnitabiService(settings)
                  ? '使用默认地址，点击管理全部服务'
                  : '已自定义，点击管理全部服务',
              showChevron: true,
              onTap: () =>
                  openSettingsSection(context, SettingsSection.anitabi),
            ),
            const SettingsNote('服务域名变化时可单独调整，不会改写计划中的标准图片链接。'),
            const SettingsDivider(),
            SettingsSubheading(
              'Anitabi 图片源 ${anitabiImageSourceLabel(settings.anitabiImageSource)}',
            ),
            SettingsBlock(
              child: ChipGroup<AnitabiImageSource>.single(
                semanticLabel: 'Anitabi 图片源',
                options: [
                  for (final source in AnitabiImageSource.values)
                    ChipOption(
                      value: source,
                      label: anitabiImageSourceLabel(source),
                      icon: switch (source) {
                        AnitabiImageSource.auto => Symbols.auto_awesome_rounded,
                        AnitabiImageSource.official => Symbols.image_rounded,
                        AnitabiImageSource.mirror => Symbols.swap_horiz_rounded,
                      },
                    ),
                ],
                value: settings.anitabiImageSource,
                onSelected: (source) =>
                    store.patch((s) => s.copyWith(anitabiImageSource: source)),
              ),
            ),
            SettingsNote(anitabiImageSourceDescription(settings)),
            const SettingsDivider(),
            NumberStepperRow(
              icon: Symbols.cloud_download_rounded,
              title: '图片同时请求数',
              subtitle: '缩略图和完整参考图均按此数量并发请求。数值越大速度可能越快，但网络和内存占用也更高。',
              value: settings.mapThumbnailConcurrentLoads,
              min: 1,
              max: 30,
              step: 1,
              format: (v) => '$v 个',
              onChanged: (value) => store.patch(
                (s) => s.copyWith(mapThumbnailConcurrentLoads: value),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '导航地图 ${settings.navigationApp.label}',
          children: [
            SettingsBlock(
              child: OptionTileGrid<NavigationApp>(
                maxColumns: 2,
                minTileWidth: 132,
                maxTileWidth: 400,
                options: [
                  for (final app in NavigationApp.values)
                    OptionTileData(
                      key: ValueKey('navigation-app-${app.name}'),
                      value: app,
                      label: app.label,
                      hint: navigationAppHint(app),
                      icon: switch (app) {
                        NavigationApp.googleMaps => Symbols.explore_rounded,
                        NavigationApp.amap => Symbols.navigation_rounded,
                        NavigationApp.appleMaps => Symbols.map_rounded,
                        NavigationApp.baiduMaps => Symbols.signpost_rounded,
                      },
                    ),
                ],
                selected: settings.navigationApp,
                onSelected: (app) =>
                    store.patch((s) => s.copyWith(navigationApp: app)),
              ),
            ),
            SettingsNote(navigationAppDescription(settings.navigationApp)),
          ],
        ),
        SettingsGroup(
          title: '步行路径规划',
          children: [
            UrlRow(
              key: const ValueKey('valhalla-url'),
              icon: Symbols.route_rounded,
              label: settings.valhallaBaseUrl,
              semanticLabel: '编辑 Valhalla 服务地址',
              onTap: () async {
                final value = await showUrlInputDialog(
                  context,
                  title: 'Valhalla 服务地址',
                  initialValue: settings.valhallaBaseUrl,
                  helperText: '用于应用内步行路线规划。公开服务没有可用性保证。',
                  validator: validateValhallaBaseUrl,
                );
                if (value == null) return;
                await store.patch(
                  (s) => s.copyWith(
                    valhallaBaseUrl: normalizeValhallaBaseUrl(value),
                  ),
                );
              },
            ),
            SettingsBlock(
              child: Row(
                children: [
                  Expanded(
                    child: MiriaButton.secondary(
                      label: '测试连接',
                      shortLabel: '测试',
                      semanticLabel: '测试 Valhalla 连接',
                      icon: Symbols.network_check_rounded,
                      loading: _testingValhalla,
                      expand: true,
                      onPressed: _testingValhalla
                          ? null
                          : () => _testValhalla(settings.valhallaBaseUrl),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: MiriaButton.secondary(
                      label: '恢复默认',
                      shortLabel: '恢复',
                      semanticLabel: '恢复默认 Valhalla 地址',
                      icon: Symbols.history_rounded,
                      expand: true,
                      onPressed:
                          settings.valhallaBaseUrl == defaultValhallaBaseUrl
                          ? null
                          : () => store.patch(
                              (s) => s.copyWith(
                                valhallaBaseUrl: defaultValhallaBaseUrl,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SettingsNote('仅发送路线坐标，不会上传计划、作品或照片信息。'),
          ],
        ),
      ],
    );
  }
}

IconData _mapProviderIcon(MapTileProvider provider) => switch (provider) {
  MapTileProvider.openFreeMap => Symbols.map_rounded,
  MapTileProvider.openStreetMap => Symbols.language_rounded,
  MapTileProvider.customXyz => Symbols.grid_on_rounded,
  MapTileProvider.customMapLibreStyle => Symbols.data_object_rounded,
};
