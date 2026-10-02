import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_result.dart';
import 'package:miriago/records/comparison_export_sheet.dart';
import 'package:miriago/settings/app_settings_updater.dart';

class _Repository extends SamplePilgrimageRepository {
  _Repository({super.settings});

  var writes = 0;
  var failLoad = false;
  var failWrite = false;

  @override
  Future<AppSettings> loadAppSettings() async {
    if (failLoad) throw StateError('load');
    return super.loadAppSettings();
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    writes++;
    if (failWrite) throw StateError('write');
    return super.saveAppSettings(settings);
  }
}

void main() {
  tearDown(() {
    AppSettingsUpdater.handler = null;
    AppSettingsUpdater.currentSettings = null;
  });

  test('goes through the shell when it is running', () async {
    final repository = _Repository();
    var shell = const AppSettings(mapThumbnailConcurrentLoads: 9);
    AppSettingsUpdater.handler = (update) async {
      shell = update(shell);
      return true;
    };
    AppSettingsUpdater.currentSettings = () => shell;

    final saved = await AppSettingsUpdater.update(
      repository,
      (settings) => settings.copyWith(nearestAssignDistanceMeters: 321),
    );

    expect(saved, isTrue);
    expect(repository.writes, 0);
    expect(shell.nearestAssignDistanceMeters, 321);
    expect(shell.mapThumbnailConcurrentLoads, 9);
    expect(
      AppSettingsUpdater.latest(
        const AppSettings(),
      ).nearestAssignDistanceMeters,
      321,
    );
  });

  test('without the shell, changes the stored settings', () async {
    final repository = _Repository(
      settings: const AppSettings(mapThumbnailConcurrentLoads: 4),
    );
    expect(
      await AppSettingsUpdater.update(
        repository,
        (settings) => settings.copyWith(nearestAssignDistanceMeters: 123),
        fallbackBase: const AppSettings(mapThumbnailConcurrentLoads: 10),
      ),
      isTrue,
    );
    final stored = await repository.loadAppSettings();
    expect(stored.nearestAssignDistanceMeters, 123);
    expect(stored.mapThumbnailConcurrentLoads, 4);

    repository.failLoad = true;
    expect(
      await AppSettingsUpdater.update(
        repository,
        (settings) => settings.copyWith(nearestAssignDistanceMeters: 7),
      ),
      isFalse,
    );
    expect(
      await AppSettingsUpdater.update(
        repository,
        (settings) => settings.copyWith(nearestAssignDistanceMeters: 8),
        fallbackBase: const AppSettings(mapThumbnailConcurrentLoads: 10),
      ),
      isTrue,
    );

    repository
      ..failLoad = false
      ..failWrite = true;
    expect(
      await AppSettingsUpdater.update(
        repository,
        (settings) => settings.copyWith(nearestAssignDistanceMeters: 9),
      ),
      isFalse,
    );
    expect(
      await AppSettingsUpdater.update(null, (settings) => settings),
      isFalse,
    );
  });

  testWidgets('the export sheet saves the pilgrim name once typing pauses', (
    tester,
  ) async {
    final repository = _Repository(
      settings: const AppSettings(comparisonShowPilgrimName: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ComparisonExportSheet.show(
                context,
                referenceImagePath: null,
                referenceImageUrl: null,
                capturedPath: 'missing.png',
                metadata: const {},
                colorGradingSummary: null,
                repository: repository,
                exporter:
                    ({
                      required referenceImagePath,
                      required referenceImageUrl,
                      required capturedPath,
                      required config,
                      required metadata,
                      required colorGradingSummary,
                    }) async => const ComparisonExportImageResult.canceled(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('comparison-pilgrim-name'));
    await tester.ensureVisible(name);
    await tester.pumpAndSettle();

    await tester.enterText(name, 'M');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(name, 'Miria');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.writes, 0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(repository.writes, 1);
    final stored = await repository.loadAppSettings();
    expect(stored.comparisonPilgrimName, 'Miria');
  });

  testWidgets('closing the export sheet keeps a name still being typed', (
    tester,
  ) async {
    final repository = _Repository(
      settings: const AppSettings(comparisonShowPilgrimName: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ComparisonExportSheet.show(
                context,
                referenceImagePath: null,
                referenceImageUrl: null,
                capturedPath: 'missing.png',
                metadata: const {},
                colorGradingSummary: null,
                repository: repository,
                exporter:
                    ({
                      required referenceImagePath,
                      required referenceImageUrl,
                      required capturedPath,
                      required config,
                      required metadata,
                      required colorGradingSummary,
                    }) async => const ComparisonExportImageResult.canceled(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('comparison-pilgrim-name'));
    await tester.ensureVisible(name);
    await tester.pumpAndSettle();
    await tester.enterText(name, 'Late');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.writes, 0);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
    expect(repository.writes, 1);
    expect((await repository.loadAppSettings()).comparisonPilgrimName, 'Late');
  });
}
