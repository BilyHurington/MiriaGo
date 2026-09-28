import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/anitabi_remote_state.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/settings/settings_screen.dart';

void main() {
  testWidgets('Anitabi settings show where each address comes from', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final remote = AnitabiRemoteServices.tryParse({
      'schema': 1,
      'version': 2,
      'services': {
        'site': 'https://www.anitabi.cn',
        'staticData': 'https://new.example/d',
        'api': 'https://api.anitabi.cn',
        'officialImage': 'https://image.anitabi.cn',
        'mirrorImage': 'https://img-tc.anitabi.cn',
      },
    });
    var settings = AppSettings(
      anitabiApiBaseUrl: 'https://mine.example',
      anitabiRemoteStateJson: AnitabiRemoteState(lastGood: remote).encode(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsScreen(
          repository: SamplePilgrimageRepository(),
          settings: settings,
          onChanged: (value) => settings = value,
        ),
      ),
    );
    await tester.tap(find.text('数据源设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('anitabi-service-settings-entry')),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('已自定义，点击管理全部服务'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('anitabi-service-settings-entry')),
    );
    await tester.pumpAndSettle();

    String source(String title) => tester
        .widget<Text>(find.byKey(ValueKey('anitabi-service-source-$title')))
        .data!;
    expect(source('主站地址'), '默认');
    expect(source('静态地图数据'), '远程配置');
    expect(source('数据 API'), '自定义');
    expect(find.text('https://new.example/d'), findsOneWidget);
    expect(find.text('https://mine.example'), findsOneWidget);
    expect(find.text('已应用远程配置 v2'), findsOneWidget);
    // Without a running app shell there is nothing to check against.
    expect(
      find.byKey(const ValueKey('anitabi-service-check-now')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('anitabi-service-auto-update')));
    await tester.pumpAndSettle();
    expect(settings.anitabiRemoteState.autoUpdate, isFalse);
    expect(settings.anitabiRemoteState.lastGood!.version, 2);
    expect(tester.takeException(), isNull);
  });
}
