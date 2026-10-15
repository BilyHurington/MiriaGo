import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('camera guides persist across mobile database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('camera-guides-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/settings.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    var repository = SqlitePilgrimageRepository(database: database);
    expect((await repository.loadAppSettings()).cameraGridEnabled, isFalse);
    await repository.saveAppSettings(
      const AppSettings(mapThumbnailConcurrentLoads: 4),
    );
    await database.customStatement(
      'ALTER TABLE app_settings_entries DROP COLUMN camera_grid_enabled',
    );
    await database.customStatement(
      'ALTER TABLE app_settings_entries DROP COLUMN camera_diagonals_enabled',
    );
    await database.customStatement('PRAGMA user_version = 49');
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    repository = SqlitePilgrimageRepository(database: database);
    final migrated = await repository.loadAppSettings();
    expect(migrated.cameraGridEnabled, isFalse);
    expect(migrated.cameraDiagonalsEnabled, isFalse);
    expect(migrated.mapThumbnailConcurrentLoads, 4);
    await repository.saveAppSettings(
      const AppSettings(
        cameraGridEnabled: true,
        cameraDiagonalsEnabled: true,
        mapThumbnailConcurrentLoads: 4,
      ),
    );
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    repository = SqlitePilgrimageRepository(database: database);
    final restored = await repository.loadAppSettings();
    expect(restored.cameraGridEnabled, isTrue);
    expect(restored.cameraDiagonalsEnabled, isTrue);
    expect(restored.mapThumbnailConcurrentLoads, 4);
  });

  test(
    'desktop snapshots preserve camera guides and default old snapshots',
    () async {
      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      String snapshot(AppSettings settings) => encodeDesktopRepositoryState(
        SamplePilgrimageRepositorySnapshot(
          plans: [plan],
          visitRecords: [],
          settings: settings,
          activePlanId: plan.id,
        ),
      );
      final encoded = snapshot(
        const AppSettings(
          cameraGridEnabled: true,
          cameraDiagonalsEnabled: true,
        ),
      );
      final restored = decodeDesktopRepositoryState(encoded)!.settings;
      expect(restored.cameraGridEnabled, isTrue);
      expect(restored.cameraDiagonalsEnabled, isTrue);
      final legacy = encoded
          .replaceAll('"cameraGridEnabled":true,', '')
          .replaceAll('"cameraDiagonalsEnabled":true,', '');
      final defaults = decodeDesktopRepositoryState(legacy)!.settings;
      expect(defaults.cameraGridEnabled, isFalse);
      expect(defaults.cameraDiagonalsEnabled, isFalse);
    },
  );
}
