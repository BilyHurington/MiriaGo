import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'data/local/sqlite_pilgrimage_repository.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';
import 'desktop/desktop_pilgrimage_repository.dart';
import 'desktop/tauri_bridge.dart';
import 'plan/pilgrimage_models.dart';
import 'widgets/copyable_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MiriaGoApp(repository: await _createDefaultRepository()));
}

class MiriaGoApp extends StatefulWidget {
  const MiriaGoApp({this.repository, super.key});

  final PilgrimageRepository? repository;

  @override
  State<MiriaGoApp> createState() => _MiriaGoAppState();
}

class _MiriaGoAppState extends State<MiriaGoApp> with WidgetsBindingObserver {
  AppSettings _themeSettings = const AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (!mounted) {
      return;
    }
    applyAppColorsFromSettings(
      _themeSettings,
      platformBrightness: currentPlatformBrightness(),
    );
    setState(() {});
  }

  void _handleSettingsChanged(AppSettings settings) {
    if (!mounted) {
      return;
    }
    applyAppColorsFromSettings(
      settings,
      platformBrightness: currentPlatformBrightness(),
    );
    setState(() {
      _themeSettings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeFor(
      _themeSettings,
      platformBrightness: currentPlatformBrightness(),
    );

    return MaterialApp(
      title: 'MiriaGo',
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeAnimationDuration: Duration.zero,
      themeAnimationStyle: AnimationStyle.noAnimation,
      navigatorObservers: [copyOverlayNavigatorObserver],
      home: AppShell(
        repository:
            widget.repository ??
            (kIsWeb
                ? SamplePilgrimageRepository()
                : SqlitePilgrimageRepository()),
        onSettingsChanged: _handleSettingsChanged,
      ),
    );
  }
}

Future<PilgrimageRepository> _createDefaultRepository() async {
  if (!kIsWeb) {
    return SqlitePilgrimageRepository();
  }
  if (isTauriLauncherAvailable) {
    return DesktopPilgrimageRepository.create();
  }
  return SamplePilgrimageRepository();
}
