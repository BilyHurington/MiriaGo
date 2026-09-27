import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/application/platform_capabilities.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/app/toast.dart';
import 'package:miriago/ui/design/theme.dart';
import 'package:provider/provider.dart';

const webCapabilities = PlatformCapabilities(
  isWeb: true,
  isTauri: false,
  isAndroid: false,
  isIOS: false,
  isDesktopNative: false,
);

const androidCapabilities = PlatformCapabilities(
  isWeb: false,
  isTauri: false,
  isAndroid: true,
  isIOS: false,
  isDesktopNative: false,
);

/// The sample plan without any reference image (no network in tests).
PilgrimagePlan samplePlanWithoutReferences() {
  return samplePilgrimagePlan.copyWith(
    points: [
      for (final point in samplePilgrimagePlan.points)
        point.copyWith(
          referenceImageUrl: null,
          referenceFullImagePath: null,
          referenceThumbnailPath: null,
        ),
    ],
  );
}

/// Providers the feature pages read, on a sample repository.
class FeatureTestStores {
  FeatureTestStores._(this.repository, this.settings, this.session);

  final PilgrimageRepository repository;
  final SettingsStore settings;
  final PlanSession session;
  final ToastController toasts = ToastController();

  static Future<FeatureTestStores> load({
    PilgrimageRepository? repository,
    AppSettings? settings,
  }) async {
    final repo =
        repository ??
        SamplePilgrimageRepository(
          plans: [samplePlanWithoutReferences()],
          settings: settings,
        );
    final store = SettingsStore(repository: repo);
    await store.load();
    final session = PlanSession(repository: repo);
    await session.load();
    return FeatureTestStores._(repo, store, session);
  }
}

/// Sets the window size and text scale for one test.
void setTestWindow(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _providers({
  required FeatureTestStores stores,
  required PlatformCapabilities capabilities,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<PilgrimageRepository>.value(value: stores.repository),
      Provider<PlatformCapabilities>.value(value: capabilities),
      ChangeNotifierProvider<SettingsStore>.value(value: stores.settings),
      ChangeNotifierProvider<PlanSession>.value(value: stores.session),
      ChangeNotifierProvider<ToastController>.value(value: stores.toasts),
    ],
    child: child,
  );
}

/// A [MaterialApp] with the Miria theme, toasts and the app providers.
Widget featureTestApp({
  required FeatureTestStores stores,
  required Widget home,
  PlatformCapabilities capabilities = webCapabilities,
  List<NavigatorObserver> observers = const [],
}) {
  return _providers(
    stores: stores,
    capabilities: capabilities,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMiriaTheme(MiriaColors.light),
      navigatorObservers: observers,
      builder: (context, child) =>
          ToastHost(child: child ?? const SizedBox.shrink()),
      home: home,
    ),
  );
}

/// Same, routed by [router].
Widget featureTestRouterApp({
  required FeatureTestStores stores,
  required GoRouter router,
  PlatformCapabilities capabilities = webCapabilities,
  Widget Function(Widget child)? wrap,
}) {
  final app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: buildMiriaTheme(MiriaColors.light),
    routerConfig: router,
    builder: (context, child) =>
        ToastHost(child: child ?? const SizedBox.shrink()),
  );
  return _providers(
    stores: stores,
    capabilities: capabilities,
    child: wrap == null ? app : wrap(app),
  );
}

/// Toast titles currently shown.
List<String> toastTitles(FeatureTestStores stores) => [
  for (final toast in stores.toasts.toasts) toast.title,
];

/// Cancels the auto-dismiss timers of every toast (no pending timers at the
/// end of a test).
void clearToasts(FeatureTestStores stores) {
  for (final toast in stores.toasts.toasts) {
    stores.toasts.dismiss(toast.id);
  }
}
