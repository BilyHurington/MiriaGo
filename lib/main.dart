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
import 'widgets/copyable_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MiriaGoApp(repository: await _createDefaultRepository()));
}

class MiriaGoApp extends StatelessWidget {
  const MiriaGoApp({this.repository, super.key});

  final PilgrimageRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiriaGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [copyOverlayNavigatorObserver],
      home: AppShell(
        repository:
            repository ??
            (kIsWeb
                ? SamplePilgrimageRepository()
                : SqlitePilgrimageRepository()),
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
