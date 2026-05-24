import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'data/local/sqlite_pilgrimage_repository.dart';
import 'data/pilgrimage_repository.dart';
import 'data/sample_pilgrimage_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SeichiJunreiHelperApp());
}

class SeichiJunreiHelperApp extends StatelessWidget {
  const SeichiJunreiHelperApp({this.repository, super.key});

  final PilgrimageRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '圣地巡礼助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
