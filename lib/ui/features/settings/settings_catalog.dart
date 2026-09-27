import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/platform_capabilities.dart';

/// Settings sections. [id] is the route segment (`/settings/<id>`).
enum SettingsSection {
  appearance('appearance', '外观设置', '主题色、深浅色、缩放、显示等', Symbols.palette_rounded),
  camera('camera', '拍摄设置', '照片比例、参考图比例、备份等', Symbols.photo_camera_rounded),
  comparison('comparison', '对比图设置', '导出样式、自动保存到相册', Symbols.compare_rounded),
  map('map', '地图显示', '点位、片区、聚合与缩略图', Symbols.layers_rounded),
  sources('sources', '数据源设置', '地图源、图片源等', Symbols.database_rounded),
  anitabi(
    'anitabi',
    'Anitabi 服务地址',
    '主站、地图数据与图片服务',
    Symbols.lan_rounded,
    parent: sources,
  ),
  storage('storage', '清除缓存', '完整参考图缓存', Symbols.cleaning_services_rounded),
  desktop('desktop', '桌面端', '启动器、数据目录等', Symbols.desktop_windows_rounded),
  about('about', '关于 MiriaGo', '版本信息、开源许可等', Symbols.info_rounded);

  const SettingsSection(
    this.id,
    this.title,
    this.subtitle,
    this.icon, {
    this.parent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Sub pages (Anitabi 服务地址) belong to a top-level category.
  final SettingsSection? parent;

  /// The category highlighted in the list for this section.
  SettingsSection get category => parent ?? this;

  bool isAvailable(PlatformCapabilities capabilities) => switch (this) {
    SettingsSection.storage => capabilities.canCleanReferenceCache,
    SettingsSection.desktop => capabilities.showsDesktopSettings,
    _ => true,
  };

  static SettingsSection? fromId(String? id) {
    if (id == null) return null;
    for (final section in values) {
      if (section.id == id) return section;
    }
    return null;
  }

  /// Top-level categories shown in the list / overview.
  static List<SettingsSection> categories(
    PlatformCapabilities capabilities,
  ) => [
    for (final section in values)
      if (section.parent == null && section.isAvailable(capabilities)) section,
  ];
}
