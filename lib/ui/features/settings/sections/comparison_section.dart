import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/platform_capabilities.dart';
import '../../../../application/settings_store.dart';
import '../../../components/components.dart';
import '../../export/comparison_export.dart';
import '../settings_widgets.dart';

/// 对比图设置: the shared export settings editor (owned by the records
/// feature) plus 「自动保存对比图」 on platforms with a gallery.
class ComparisonSettingsSection extends StatelessWidget {
  const ComparisonSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    final capabilities = context.read<PlatformCapabilities>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (capabilities.canSaveToGallery)
          SettingsGroup(
            children: [
              SwitchRow(
                key: const ValueKey('auto-save-comparison-toggle'),
                leading: const Icon(Symbols.photo_library_rounded),
                title: '自动保存对比图',
                subtitle: '保存记录时保存到相册',
                value: settings.autoSaveComparisonToGallery,
                onChanged: (value) => store.patch(
                  (s) => s.copyWith(autoSaveComparisonToGallery: value),
                ),
              ),
            ],
          ),
        const SettingsGroup(
          title: '导出样式',
          children: [
            ComparisonExportSettingsPanel(
              padding: EdgeInsets.fromLTRB(
                Space.x4,
                Space.x1,
                Space.x4,
                Space.x2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
