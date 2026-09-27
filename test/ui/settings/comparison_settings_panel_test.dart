import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/app/toast.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/features/export/comparison_export.dart';
import 'package:provider/provider.dart';

/// Sample data whose settings can't be read until [failLoad] is cleared.
class _FailingSettingsRepository extends SamplePilgrimageRepository {
  bool failLoad = true;

  @override
  Future<AppSettings> loadAppSettings() {
    if (failLoad) throw StateError('settings unreadable');
    return super.loadAppSettings();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('export settings load failure offers a retry', (tester) async {
    final repository = _FailingSettingsRepository();
    // Not loaded: the panel reads the settings from the repository.
    final store = SettingsStore(repository: repository);
    final toasts = ToastController();
    addTearDown(store.dispose);
    addTearDown(toasts.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsStore>.value(value: store),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
        ],
        child: MaterialApp(
          theme: buildMiriaTheme(MiriaColors.light),
          home: const Scaffold(body: ComparisonExportSettingsPanel()),
        ),
      ),
    );
    await _settle(tester);

    final banner = find.byKey(const ValueKey('comparison-settings-load-error'));
    expect(banner, findsOneWidget);
    expect(find.text('读取导出设置失败，请重试。'), findsOneWidget);
    final editor = tester.widget<ComparisonExportEditor>(
      find.byType(ComparisonExportEditor),
    );
    expect(editor.enabled, isFalse);

    repository.failLoad = false;
    await tester.tap(find.text('重试'));
    await _settle(tester);
    expect(banner, findsNothing);
    expect(
      tester
          .widget<ComparisonExportEditor>(find.byType(ComparisonExportEditor))
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
