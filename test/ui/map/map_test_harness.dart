import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/ui/design/theme.dart';
import 'package:provider/provider.dart';

/// Stores backed by the sample repository.
class MapTestStores {
  MapTestStores._(this.settings, this.session);

  final SettingsStore settings;
  final PlanSession session;

  static Future<MapTestStores> load() async {
    final repository = SamplePilgrimageRepository();
    final settings = SettingsStore(repository: repository);
    await settings.load();
    final session = PlanSession(repository: repository);
    await session.load();
    return MapTestStores._(settings, session);
  }
}

/// Sets the test window size (logical px) and restores it after the test.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Minimal app around [child]: Miria theme + providers.
Widget mapTestApp({
  required MapTestStores stores,
  required Widget child,
  bool dark = false,
  bool scaffold = true,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsStore>.value(value: stores.settings),
      ChangeNotifierProvider<PlanSession>.value(value: stores.session),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMiriaTheme(dark ? MiriaColors.dark : MiriaColors.light),
      home: scaffold ? Scaffold(body: child) : child,
    ),
  );
}
