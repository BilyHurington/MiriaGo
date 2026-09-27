import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/app_services.dart';
import 'desktop/tauri_bridge.dart';
import 'ui/app/app.dart';
import 'ui/devtools/layout_lab.dart';
import 'ui/devtools/preview_seeds.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'MiriaGo Readable Dark / OpenFreeMap / OpenMapTiles',
    ], await rootBundle.loadString('assets/maps/LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('assets/fonts/Inter-LICENSE.txt'));
  });
  _installDesktopErrorLogging();
  final query = kIsWeb && !isTauriLauncherAvailable
      ? Uri.base.queryParameters
      : const <String, String>{};
  final seed = query['seed'];
  if (query.containsKey('lab')) {
    runApp(LayoutLab(seed: seed, route: query['route'] ?? '/go'));
    return;
  }
  runApp(
    MiriaGoBootstrap(
      repositoryLoader: seed == null
          ? StartupService.createDefaultRepository
          : () => PreviewSeeds.build(seed),
    ),
  );
}

void _installDesktopErrorLogging() {
  if (!kIsWeb || !isTauriLauncherAvailable) return;
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      StartupService.writeDesktopError(
        'Flutter framework error',
        details.exception,
        details.stack,
      ),
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      StartupService.writeDesktopError(
        'uncaught Dart error',
        error,
        stackTrace,
      ),
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}
