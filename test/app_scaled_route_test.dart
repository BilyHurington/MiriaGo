import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/app_scaled_route.dart';

void main() {
  testWidgets('scaled route applies app UI, font, and theme settings', (
    tester,
  ) async {
    const settings = AppSettings(
      uiScale: 0.8,
      fontScale: 1.2,
      themePalette: AppThemePalette.deepBlue,
    );
    late double scaledFontSize;
    late Color primaryColor;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => appScaledMaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            scaledFontSize = MediaQuery.textScalerOf(context).scale(16);
            primaryColor = Theme.of(context).colorScheme.primary;
            return const Scaffold(body: Text('缩放页面'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaleView = tester.widget<AppUiScaleView>(
      find.byType(AppUiScaleView),
    );
    expect(scaleView.scale, settings.uiScale);
    expect(scaledFontSize, greaterThan(16));
    expect(primaryColor, AppColors.deepBlue);
  });

  testWidgets('scaled overlay content matches page UI and font scale', (
    tester,
  ) async {
    const settings = AppSettings(uiScale: 0.8, fontScale: 1.2);
    const overlayWidth = 240.0;
    const baseHeight = 48.0;
    const contentKey = ValueKey('overlay-content');
    late double scaledFontSize;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: overlayWidth,
            height: appScaledOverlayExtent(settings, baseHeight),
            child: AppScaledOverlayContent(
              settings: settings,
              child: Builder(
                builder: (context) {
                  scaledFontSize = MediaQuery.textScalerOf(context).scale(16);
                  return const SizedBox.expand(key: contentKey);
                },
              ),
            ),
          ),
        ),
      ),
    );

    final effectiveUiScale = appUiScaler(settings.uiScale);
    final contentSize = tester.getSize(find.byKey(contentKey));
    expect(contentSize.width, closeTo(overlayWidth / effectiveUiScale, 0.01));
    expect(contentSize.height, closeTo(baseHeight, 0.01));
    expect(scaledFontSize, greaterThan(16));
  });
}
