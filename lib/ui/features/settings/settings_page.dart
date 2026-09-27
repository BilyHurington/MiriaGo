import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/platform_capabilities.dart';
import '../../../application/settings_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import 'sections/about_section.dart';
import 'sections/anitabi_section.dart';
import 'sections/appearance_section.dart';
import 'sections/camera_section.dart';
import 'sections/comparison_section.dart';
import 'sections/desktop_section.dart';
import 'sections/map_section.dart';
import 'sections/sources_section.dart';
import 'sections/storage_section.dart';
import 'settings_catalog.dart';

/// 设置 (DESIGN §8.19).
///
/// * compact / medium: `/settings` shows the grouped overview; a section id
///   (`/settings/<id>` or `?section=<id>`) shows only that section page.
/// * expanded+: category list on the left, the selected section on the
///   right (`/settings?section=<id>`).
class SettingsPage extends StatelessWidget {
  const SettingsPage({this.section, super.key});

  /// Selected section id (see settings routes); null → overview.
  final String? section;

  @override
  Widget build(BuildContext context) {
    final capabilities = context.read<PlatformCapabilities>();
    var selected = SettingsSection.fromId(section);
    if (selected != null && !selected.isAvailable(capabilities)) {
      selected = null;
    }
    if (!context.layout.showsListDetail) {
      if (selected == null) return const _SettingsOverview();
      return SettingsSectionPage(section: selected);
    }
    final current = selected ?? SettingsSection.appearance;
    return MiriaPageScaffold(
      title: '设置',
      automaticallyImplyLeading: false,
      body: ListDetailLayout(
        list: _CategoryList(selected: current.category),
        detail: _SectionDetail(key: ValueKey(current), section: current),
      ),
    );
  }
}

/// Opens [section]: selects it in the two-pane layout, or pushes its page.
void openSettingsSection(BuildContext context, SettingsSection section) {
  if (context.layout.showsListDetail) {
    context.go(
      Uri(
        path: Routes.settings,
        queryParameters: {'section': section.id},
      ).toString(),
    );
  } else {
    context.push(Routes.settingsSection(section.id));
  }
}

/// The content (groups) of one section, without a scroll view.
class SettingsSectionBody extends StatelessWidget {
  const SettingsSectionBody({required this.section, super.key});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      SettingsSection.appearance => const AppearanceSettingsSection(),
      SettingsSection.camera => const CameraSettingsSection(),
      SettingsSection.comparison => const ComparisonSettingsSection(),
      SettingsSection.map => const MapDisplaySettingsSection(),
      SettingsSection.sources => const DataSourceSettingsSection(),
      SettingsSection.anitabi => const AnitabiServiceSettingsSection(),
      SettingsSection.storage => const CacheCleanupSettingsSection(),
      SettingsSection.desktop => const DesktopSettingsSection(),
      SettingsSection.about => const AboutSettingsSection(),
    };
  }
}

/// A single section as its own page (compact).
class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({required this.section, super.key});

  final SettingsSection section;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      final parent = section.parent;
      context.go(
        parent == null ? Routes.settings : Routes.settingsSection(parent.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiriaPageScaffold(
      title: section.title,
      leading: MiriaIconButton(
        icon: Symbols.arrow_back_rounded,
        tooltip: '返回',
        onPressed: () => _back(context),
      ),
      slivers: [
        SliverContentColumn(
          top: Space.x2,
          sliver: SliverToBoxAdapter(
            child: SettingsSectionBody(section: section),
          ),
        ),
      ],
    );
  }
}

class _SectionDetail extends StatelessWidget {
  const _SectionDetail({required this.section, super.key});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final parent = section.parent;
    return CustomScrollView(
      slivers: [
        SliverContentColumn(
          top: Space.x4,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: Row(
                children: [
                  if (parent != null) ...[
                    MiriaIconButton(
                      icon: Symbols.arrow_back_rounded,
                      tooltip: '返回${parent.title}',
                      onPressed: () => openSettingsSection(context, parent),
                    ),
                    const SizedBox(width: Space.x1),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        section.title,
                        style: context.text.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverContentColumn(
          bottom: Space.x6,
          sliver: SliverToBoxAdapter(
            child: SettingsSectionBody(section: section),
          ),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.selected});

  final SettingsSection selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final categories = SettingsSection.categories(
      context.read<PlatformCapabilities>(),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x2,
        vertical: Space.x2,
      ),
      children: [
        for (final section in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListRow(
              key: ValueKey('settings-category-${section.id}'),
              title: section.title,
              subtitle: section.subtitle,
              subtitleMaxLines: 1,
              leading: Icon(
                section.icon,
                fill: section == selected ? 1 : 0,
                color: section == selected ? c.primaryText : c.textSecondary,
              ),
              selected: section == selected,
              borderRadius: Radii.smAll,
              onTap: () => openSettingsSection(context, section),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overview (compact)
// ---------------------------------------------------------------------------

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview();

  @override
  Widget build(BuildContext context) {
    final capabilities = context.read<PlatformCapabilities>();
    final settings = context.watch<SettingsStore>().settings;
    final categories = SettingsSection.categories(capabilities);
    return MiriaPageScaffold(
      title: '设置',
      automaticallyImplyLeading: false,
      slivers: [
        SliverContentColumn(
          top: Space.x2,
          sliver: SliverList.list(
            children: [
              for (final section in categories)
                _OverviewCard(
                  key: ValueKey('settings-${section.id}-card'),
                  section: section,
                  children: _summaries(
                    context,
                    section,
                    settings,
                    capabilities,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _summaries(
    BuildContext context,
    SettingsSection section,
    AppSettings settings,
    PlatformCapabilities capabilities,
  ) {
    final store = context.read<SettingsStore>();
    void open() => openSettingsSection(context, section);
    switch (section) {
      case SettingsSection.appearance:
        return [
          _SummaryPair(
            first: _SummaryTile(
              icon: Symbols.circle_rounded,
              swatch: _PaletteDot(settings: settings),
              title: '主题色',
              value: settings.themePalette == AppThemePalette.aurora
                  ? settings.customThemeColorName
                  : settings.themePalette.label,
              onTap: open,
            ),
            second: _SummaryTile(
              icon: Symbols.dark_mode_rounded,
              title: '主题模式',
              value: settings.themeMode.label,
              onTap: open,
            ),
          ),
        ];
      case SettingsSection.camera:
        return [
          _SummaryPair(
            first: _SummaryTile(
              icon: Symbols.crop_rounded,
              title: '拍摄图片比例',
              value: settings.cameraCaptureAspectRatio.label,
              onTap: open,
            ),
            second: _SummaryTile(
              icon: Symbols.zoom_in_rounded,
              title: '相机缩放',
              value:
                  '${settings.cameraMinZoom.toStringAsFixed(1)}x-${settings.cameraMaxZoom.toStringAsFixed(1)}x',
              onTap: open,
            ),
          ),
          if (capabilities.canSaveToGallery)
            SwitchRow(
              leading: const Icon(Symbols.backup_rounded),
              title: '照片备份',
              subtitle: '保存巡礼照片到相册',
              value: settings.saveVisitPhotoToGallery,
              onChanged: (value) => store.patch(
                (s) => s.copyWith(saveVisitPhotoToGallery: value),
              ),
            ),
        ];
      case SettingsSection.comparison:
        return [
          if (capabilities.canSaveToGallery)
            SwitchRow(
              leading: const Icon(Symbols.photo_library_rounded),
              title: '自动保存对比图',
              subtitle: '保存记录时保存到相册',
              value: settings.autoSaveComparisonToGallery,
              onChanged: (value) => store.patch(
                (s) => s.copyWith(autoSaveComparisonToGallery: value),
              ),
            ),
        ];
      default:
        return const [];
    }
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.section,
    required this.children,
    super.key,
  });

  final SettingsSection section;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: MiriaCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MiriaPressable(
              onTap: () => openSettingsSection(context, section),
              semanticLabel: '${section.title}，${section.subtitle}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.x4,
                    Space.x3,
                    Space.x3,
                    Space.x3,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: Radii.smAll,
                        ),
                        child: Icon(
                          section.icon,
                          color: c.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              section.subtitle,
                              style: text.bodySmall?.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.x2),
                      Icon(
                        Symbols.chevron_right_rounded,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final child in children) ...[
              Divider(height: 1, thickness: 1, color: c.hairline),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPair extends StatelessWidget {
  const _SummaryPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 300 * scale.clamp(1.0, 2.0)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              Divider(height: 1, thickness: 1, color: c.hairline),
              second,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              VerticalDivider(width: 1, thickness: 1, color: c.hairline),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.swatch,
  });

  final IconData icon;
  final Widget? swatch;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaPressable(
      onTap: onTap,
      semanticLabel: '$title：$value',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: Row(
          children: [
            swatch ?? Icon(icon, size: 24, color: c.textSecondary),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: c.primaryText),
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

class _PaletteDot extends StatelessWidget {
  const _PaletteDot({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: c.primary,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairlineStrong),
      ),
    );
  }
}
