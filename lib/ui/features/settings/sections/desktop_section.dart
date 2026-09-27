import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../application/app_services.dart';
import '../../../../application/settings/settings_options.dart';
import '../../../../desktop/tauri_bridge.dart';
import '../settings_widgets.dart';

/// 桌面端 (web builds): launcher status and data directories.
class DesktopSettingsSection extends StatefulWidget {
  const DesktopSettingsSection({super.key});

  @override
  State<DesktopSettingsSection> createState() => _DesktopSettingsSectionState();
}

class _DesktopSettingsSectionState extends State<DesktopSettingsSection> {
  DesktopLauncherInfo? _info;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _info = context.read<AppServices>().launcherInfo;
    _loaded = _info != null || !isTauriLauncherAvailable;
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final info = await StartupService.loadLauncherInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return SettingsGroup(
      title: '启动器',
      children: [
        InfoLine(
          icon: Symbols.desktop_windows_rounded,
          value: desktopLauncherStatusText(
            loaded: _loaded,
            info: info,
            launcherAvailable: isTauriLauncherAvailable,
          ),
        ),
        if (info != null) ...[
          InfoLine(icon: Symbols.folder_rounded, value: info.dataDir),
          InfoLine(icon: Symbols.inventory_2_rounded, value: info.assetsDir),
        ],
      ],
    );
  }
}
