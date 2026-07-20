import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/anitabi_image_source_scope.dart';
import '../plan/pilgrimage_models.dart';

MaterialPageRoute<T> appScaledMaterialPageRoute<T>({
  required AppSettings settings,
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<T>(
    builder: (context) => _AppScaledRouteView(
      settings: settings,
      child: Builder(builder: builder),
    ),
  );
}

double appScaledOverlayExtent(AppSettings settings, double extent) {
  return extent * appUiScaler(settings.uiScale);
}

class AppScaledOverlayContent extends StatelessWidget {
  const AppScaledOverlayContent({
    required this.settings,
    required this.child,
    super.key,
  });

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uiScale = appUiScaler(settings.uiScale);
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: appTextScaler(settings.fontScale)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth / uiScale
              : null;
          final expandedHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight / uiScale
              : null;
          return OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: expandedWidth,
            maxWidth: expandedWidth,
            minHeight: expandedHeight,
            maxHeight: expandedHeight,
            child: Transform.scale(
              scale: uiScale,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: expandedWidth,
                height: expandedHeight,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppScaledRouteView extends StatelessWidget {
  const _AppScaledRouteView({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppColors.palette = settings.themePalette;
    AppColors.customAccentValue = settings.customThemeColorValue;

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: appTextScaler(settings.fontScale)),
      child: AnitabiImageSourceScope(
        source: settings.anitabiImageSource,
        child: AppUiScaleView(
          scale: settings.uiScale,
          child: Theme(
            data: AppTheme.light(
              palette: settings.themePalette,
              customAccentValue: settings.customThemeColorValue,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
