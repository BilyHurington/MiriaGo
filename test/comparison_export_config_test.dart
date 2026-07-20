import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_config_editor.dart';

void main() {
  test('serializes comparison export config for global reuse', () {
    const config = ComparisonExportConfig(
      borderWidthPercent: 1.5,
      borderColor: Colors.black,
      outputWidth: ComparisonOutputWidth.w1920,
      showLabels: true,
      showPilgrimName: true,
      pilgrimName: 'BilyHurington',
      showColorGradingParams: true,
      metadataFields: {
        ComparisonMetadataField.pointName,
        ComparisonMetadataField.episodeLabel,
      },
    );

    final restored = ComparisonExportConfig.fromJson(config.toJson());

    expect(restored.borderWidthPercent, 1.5);
    expect(restored.borderColor, Colors.black);
    expect(restored.outputWidth, ComparisonOutputWidth.w1920);
    expect(restored.showLabels, isTrue);
    expect(restored.showPilgrimName, isTrue);
    expect(restored.pilgrimName, 'BilyHurington');
    expect(restored.showColorGradingParams, isTrue);
    expect(restored.metadataFields, {
      ComparisonMetadataField.pointName,
      ComparisonMetadataField.episodeLabel,
    });
  });

  test('applies pilgrim identity to app settings', () {
    const config = ComparisonExportConfig(
      showPilgrimName: true,
      pilgrimName: '巡礼者',
    );

    final settings = config.applyToSettings(const AppSettings());
    final restored = const ComparisonExportConfig().withSettings(settings);

    expect(settings.comparisonShowPilgrimName, isTrue);
    expect(settings.comparisonPilgrimName, '巡礼者');
    expect(restored.showPilgrimName, isTrue);
    expect(restored.pilgrimName, '巡礼者');
  });

  test('summarizes default comparison export config', () {
    const config = ComparisonExportConfig(
      outputWidth: ComparisonOutputWidth.w1920,
      borderWidthPercent: 1,
      showLabels: true,
    );

    expect(comparisonExportConfigSummary(config), '宽度 1920px / 边框 1.0% / 显示标签');
  });

  testWidgets('comparison editor exposes the redesigned interactions', (
    tester,
  ) async {
    var config = const ComparisonExportConfig();
    final pilgrimNameController = TextEditingController();
    addTearDown(pilgrimNameController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return ComparisonExportConfigEditor(
                  config: config,
                  pilgrimNameController: pilgrimNameController,
                  onChanged: (updated) {
                    setState(() => config = updated);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('自动宽度'), findsOneWidget);
    expect(find.text('1080px'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('comparison-pilgrim-name')),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('comparison-output-auto')));
    await tester.pumpAndSettle();
    expect(config.outputWidth, ComparisonOutputWidth.w1920);
    expect(find.text('1080px'), findsOneWidget);
    expect(find.text('自定义'), findsNothing);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('元数据'), findsOneWidget);
    expect(find.text('显示内容'), findsOneWidget);
    expect(find.text('巡礼者信息'), findsNothing);
    expect(find.text('调色参数'), findsNothing);

    final pilgrimSwitch = find.byKey(
      const ValueKey('comparison-show-pilgrim-name'),
    );
    await tester.ensureVisible(pilgrimSwitch);
    await tester.pumpAndSettle();
    await tester.tap(pilgrimSwitch);
    await tester.pumpAndSettle();
    expect(config.showPilgrimName, isTrue);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('comparison-pilgrim-name')),
          )
          .enabled,
      isTrue,
    );

    final episodeChip = find.byKey(
      const ValueKey('comparison-metadata-episodeLabel'),
    );
    await tester.ensureVisible(episodeChip);
    await tester.pumpAndSettle();
    final firstRowTops = ['capturedAt', 'pointName', 'workTitle'].map(
      (name) => tester
          .getTopLeft(find.byKey(ValueKey('comparison-metadata-$name')))
          .dy,
    );
    expect(firstRowTops.toSet(), hasLength(1));
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('comparison-metadata-episodeLabel')),
          )
          .dy,
      greaterThan(firstRowTops.first),
    );
    await tester.tap(episodeChip);
    await tester.pumpAndSettle();
    expect(
      config.metadataFields.contains(ComparisonMetadataField.episodeLabel),
      isTrue,
    );
  });
}
