import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/map/map_colors.dart';
import 'package:miriago/map/map_tile_config.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/plan_group_utils.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

void main() {
  tearDown(() => AppTheme.light());

  test(
    'dark map accents remain readable for every palette and custom black',
    () {
      for (final palette in AppThemePalette.values) {
        AppTheme.dark(palette: palette, customAccentValue: 0xFF000000);
        expect(
          contrast(MapColors.accent, MapColors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(MapColors.accent, MapColors.onAccent),
          greaterThanOrEqualTo(4.5),
        );
        for (var i = 0; i < planGroupMapColors.length; i++) {
          expect(
            contrast(planGroupMapColorAt(i), MapColors.surface),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      AppTheme.light();
      expect(MapColors.accent, AppColors.accent);
      expect(MapColors.accentDark, AppColors.accentDark);
      expect(planGroupMapColorAt(0), planGroupMapColors.first);
    },
  );

  test(
    'base appearance overrides theme without replacing custom providers',
    () {
      const settings = AppSettings();
      expect(resolvedMapLibreStyle(settings, dark: false), openFreeMapStyleUrl);
      expect(
        resolvedMapLibreStyle(settings, dark: true),
        darkMapStyleAsset(OpenFreeMapStyle.liberty),
      );
      expect(
        resolvedMapLibreStyle(
          settings.copyWith(mapAppearance: MapAppearance.light),
          dark: true,
        ),
        openFreeMapStyleUrl,
      );
      expect(
        resolvedMapLibreStyle(
          settings.copyWith(mapAppearance: MapAppearance.dark),
          dark: false,
        ),
        darkMapStyleAsset(OpenFreeMapStyle.liberty),
      );
      expect(
        resolvedMapLibreStyle(
          settings.copyWith(
            openFreeMapStyle: OpenFreeMapStyle.dark,
            mapAppearance: MapAppearance.light,
          ),
          dark: true,
        ),
        readableDarkMapStyleAsset,
      );
      for (final appearance in MapAppearance.values) {
        final custom = settings.copyWith(
          mapAppearance: appearance,
          mapTileProvider: MapTileProvider.customMapLibreStyle,
          customMapLibreStyleUrl: 'https://example.com/style.json',
        );
        expect(
          resolvedMapLibreStyle(custom, dark: true),
          'https://example.com/style.json',
        );
        expect(
          xyzTileUrl(
            custom.copyWith(mapTileProvider: MapTileProvider.openStreetMap),
          ),
          openStreetMapTileUrl,
        );
        expect(
          xyzTileUrl(
            custom.copyWith(
              mapTileProvider: MapTileProvider.customXyz,
              customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
            ),
          ),
          'https://example.com/{z}/{x}/{y}.png',
        );
      }
    },
  );

  test('each style retains its identity across appearance and app themes', () {
    final assets = <String>{};
    for (final style in OpenFreeMapStyle.values) {
      assets.add(darkMapStyleAsset(style));
      for (final appearance in MapAppearance.values) {
        for (final dark in [false, true]) {
          final settings = AppSettings(
            openFreeMapStyle: style,
            mapAppearance: appearance,
          );
          final expectedDark =
              style == OpenFreeMapStyle.dark ||
              appearance == MapAppearance.dark ||
              (appearance == MapAppearance.automatic && dark);
          expect(
            resolvedMapLibreStyle(settings, dark: dark),
            expectedDark
                ? darkMapStyleAsset(style)
                : openFreeMapStyleOption(style).styleUrl,
          );
        }
      }
    }
    expect(assets.length, OpenFreeMapStyle.values.length);
  });

  for (final variant in OpenFreeMapStyle.values) {
    test(
      '${variant.name} dark preserves source layers, geometry and expressions',
      () {
        final source =
            jsonDecode(
                  File(
                    'tool/map_styles/${variant.name}.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dark =
            jsonDecode(File(darkMapStyleAsset(variant)).readAsStringSync())
                as Map<String, dynamic>;
        for (final key in ['version', 'sources', 'sprite', 'glyphs']) {
          expect(dark[key], source[key], reason: key);
        }
        final before = (source['layers'] as List).cast<Map<String, dynamic>>();
        final after = (dark['layers'] as List).cast<Map<String, dynamic>>();
        expect(after.length, before.length);
        for (var i = 0; i < before.length; i++) {
          final a = Map<String, dynamic>.from(before[i])..remove('paint');
          final b = Map<String, dynamic>.from(after[i])..remove('paint');
          expect(b, a, reason: '${variant.name}/${a['id']}');
          final paint = before[i]['paint'] as Map<String, dynamic>? ?? {};
          for (final entry in paint.entries) {
            if (!entry.key.endsWith('-color') &&
                entry.key != 'text-halo-width' &&
                !(entry.key == 'fill-opacity' &&
                    paint.containsKey('fill-pattern'))) {
              expect(
                after[i]['paint'][entry.key],
                entry.value,
                reason: '${a['id']}/${entry.key}',
              );
            }
            if (entry.key.endsWith('-color') && entry.value is List) {
              expect(
                _expressionShape(after[i]['paint'][entry.key]),
                _expressionShape(entry.value),
              );
            }
          }
        }
        Color parse(String value) =>
            Color(int.parse('ff${value.substring(1)}', radix: 16));
        final background = parse(
          after.firstWhere(
                (l) => l['type'] == 'background',
              )['paint']['background-color']
              as String,
        );
        final minor = after.firstWhere(
          (l) => [
            'road_minor',
            'highway-minor',
            'highway_minor',
          ].contains(l['id']),
        );
        expect(
          contrast(background, parse(minor['paint']['line-color'] as String)),
          greaterThan(2.5),
        );
        final label = after.firstWhere(
          (l) => ['label_city', 'place_city'].contains(l['id']),
        );
        expect(
          contrast(background, parse(label['paint']['text-color'] as String)),
          greaterThan(4.5),
        );
        final raster = after.where((l) => l['type'] == 'raster');
        for (final layer in raster) {
          expect(
            layer['paint']['raster-brightness-max'],
            lessThanOrEqualTo(0.2),
          );
        }
      },
    );
  }

  test('light chrome on a dark base keeps the navigation route readable', () {
    AppTheme.light(palette: AppThemePalette.deepBlue);
    final routeColor = configuredMapRouteColor(
      const AppSettings(mapAppearance: MapAppearance.dark),
      dark: false,
    );
    expect(contrast(routeColor, const Color(0xFF202225)), greaterThan(4.5));
    expect(
      configuredMapRouteColor(const AppSettings(), dark: false),
      AppColors.accent,
    );
    final fiordRoute = configuredMapRouteColor(
      const AppSettings(openFreeMapStyle: OpenFreeMapStyle.fiord),
      dark: false,
    );
    expect(contrast(fiordRoute, const Color(0xFF252F32)), greaterThan(4.5));
  });

  test(
    'bundled style has portable sources, distinct streets and readable labels',
    () {
      final style =
          jsonDecode(File(readableDarkMapStyleAsset).readAsStringSync())
              as Map<String, dynamic>;
      expect(style['version'], 8);
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      expect(layers.map((l) => l['id']).toSet().length, layers.length);
      Map<String, dynamic> paint(String id) =>
          layers.singleWhere((l) => l['id'] == id)['paint']
              as Map<String, dynamic>;
      Color color(String value) =>
          Color(int.parse('ff${value.substring(1)}', radix: 16));
      final background = color(
        paint('background')['background-color'] as String,
      );
      expect(
        contrast(
          background,
          color(paint('highway_minor')['line-color'] as String),
        ),
        greaterThan(2.5),
      );
      expect(
        contrast(
          background,
          color(paint('highway_name_other')['text-color'] as String),
        ),
        greaterThan(4.5),
      );
      for (final key in ['sprite', 'glyphs']) {
        expect(style[key], startsWith('https://'));
      }
      expect(
        style['sources']['openmaptiles']['url'],
        'https://tiles.openfreemap.org/planet',
      );
      expect(
        File('assets/maps/LICENSE.txt').readAsStringSync(),
        contains('CartoDB'),
      );
    },
  );
}

Object? _expressionShape(Object? value) {
  if (value is List) return value.map(_expressionShape).toList();
  if (value is String && RegExp(r'^(#|rgba?\(|hsla?\()').hasMatch(value)) {
    return '<color>';
  }
  return value;
}
