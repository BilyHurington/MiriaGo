import 'dart:io';

import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/local/app_database.dart';

void main() {
  test('fresh database opens with the complete schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _expectCompleteSchema(db);
    expect(await db.select(db.plans).get(), isEmpty);
    expect(await db.select(db.visitRecords).get(), isEmpty);
  });

  for (final version in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]) {
    test('schema $version upgrades on open and survives reopening', () async {
      final file = await _legacyFile(version);
      final db = AppDatabase(NativeDatabase(file));
      try {
        await _expectUpgradedData(db, version);
      } finally {
        await db.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      await _expectUpgradedData(reopened, version);
    });
  }

  for (final version in [1, 5, 13]) {
    test(
      'schema $version rolls back after every migration write and retries',
      () async {
        final backup = await _legacyFile(version);
        final legacy = _LegacyDatabase(NativeDatabase(backup), version);
        final before = await _snapshot(legacy);
        await legacy.close();

        final baselineFile = await backup.copy('${backup.path}.baseline');
        final baseline = _MigrationProbe(NativeDatabase(baselineFile));
        await _expectUpgradedData(baseline, version);
        final writes = List<String>.of(baseline.writes);
        await baseline.close();
        expect(writes, isNotEmpty);

        for (var index = 0; index < writes.length; index++) {
          final reason =
              'schema $version, write ${index + 1}: ${writes[index]}';
          final file = await backup.copy('${backup.path}.trial');
          final failing = _MigrationProbe(
            NativeDatabase(file),
            failAfterWrite: index + 1,
          );
          try {
            await expectLater(
              failing.customSelect('SELECT 1').get(),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  'injected migration failure',
                ),
              ),
              reason: reason,
            );
          } finally {
            await failing.close();
          }

          final inspection = _LegacyDatabase(NativeDatabase(file), version);
          try {
            expect(await _snapshot(inspection), before, reason: reason);
          } finally {
            await inspection.close();
          }
          // Drift caches opening failures on the old connection: retry with a
          // new connection, as on the next application launch.
          final retry = AppDatabase(NativeDatabase(file));
          try {
            await _expectUpgradedData(retry, version);
          } finally {
            await retry.close();
          }
        }

        // Restore a closed synthetic backup to a separate file, never user data.
        final restoredFile = await backup.copy('${backup.path}.restored');
        final restored = AppDatabase(NativeDatabase(restoredFile));
        addTearDown(restored.close);
        await _expectUpgradedData(restored, version);
      },
    );
  }

  test('legacy non-atomic partial migrations can be resumed', () async {
    final backup = await _legacyFile(1);
    final baselineFile = await backup.copy('${backup.path}.baseline');
    final baseline = _MigrationProbe(NativeDatabase(baselineFile));
    await _expectUpgradedData(baseline, 1);
    final writes = List<String>.of(baseline.writes);
    await baseline.close();

    final checkpoints = <int>{};
    for (final marker in [
      'is_current',
      'CREATE TABLE IF NOT EXISTS "visit_records"',
      'CREATE TABLE IF NOT EXISTS "app_settings_entries"',
      'reference_thumbnail_path',
      'CREATE TABLE IF NOT EXISTS "plan_groups"',
      'group_order_index',
      'COALESCE(work_title',
      "points.plan_id || '::' || works.id",
      'UPDATE points\n      SET work_id',
      'UPDATE points\n      SET id',
      'DELETE FROM works',
      'SET reference_image_url',
      'map_appearance',
    ]) {
      final index = writes.indexWhere((sql) => sql.contains(marker));
      expect(index, greaterThanOrEqualTo(0), reason: marker);
      checkpoints.add(index + 1);
    }
    for (final checkpoint in checkpoints) {
      final file = await backup.copy('${backup.path}.partial');
      final interrupted = _MigrationProbe(
        NativeDatabase(file),
        failAfterWrite: checkpoint,
        atomic: false,
      );
      try {
        await expectLater(
          interrupted.customSelect('SELECT 1').get(),
          throwsStateError,
        );
      } finally {
        await interrupted.close();
      }
      final inspection = _LegacyDatabase(NativeDatabase(file), 1);
      expect(await _version(inspection), 1);
      expect(await _columns(inspection, 'points'), contains('is_current'));
      await inspection.close();
      final retry = AppDatabase(NativeDatabase(file));
      try {
        await _expectUpgradedData(retry, 1);
      } finally {
        await retry.close();
      }
    }
  });

  test(
    'partial old record table gains missing columns without replacement',
    () async {
      final file = await _legacyFile(3);
      final legacy = _LegacyDatabase(NativeDatabase(file), 3);
      // A v1 migration could have created the then-v3 table and stopped before
      // advancing user_version. It must not skip the later reference columns.
      await legacy.customStatement('PRAGMA user_version = 1');
      await legacy.close();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await _expectUpgradedData(db, 3);
    },
  );

  test(
    'snapshot backfill preserves historical and empty values on replay',
    () async {
      final file = await _legacyFile(13);
      final legacy = _LegacyDatabase(NativeDatabase(file), 13);
      await legacy.customStatement(
        'ALTER TABLE visit_records ADD COLUMN work_title TEXT',
      );
      await legacy.customStatement(
        'ALTER TABLE visit_records ADD COLUMN point_subtitle TEXT',
      );
      await legacy.customStatement('''
      UPDATE visit_records
      SET work_title = 'Historical title', point_subtitle = ''
      WHERE id = 'r'
    ''');
      await legacy.close();

      final interrupted = _VersionAdvanceFailure(NativeDatabase(file));
      try {
        await expectLater(
          interrupted.customSelect('SELECT 1').get(),
          throwsStateError,
        );
      } finally {
        await interrupted.close();
      }
      // onUpgrade committed, but Drift has not yet advanced user_version.
      final db = _LegacyDatabase(NativeDatabase(file), 13);
      expect(await _version(db), 13);
      var record = (await db.select(db.visitRecords).get()).singleWhere(
        (row) => row.id == 'r',
      );
      expect(record.workTitle, 'Historical title');
      expect(record.workSubtitle, 'Work subtitle');
      expect(record.pointName, 'Point name');
      expect(record.pointSubtitle, '');
      await db.customStatement("UPDATE works SET title = 'Renamed work'");
      await db.customStatement("UPDATE points SET name = 'Renamed point'");
      await db.close();

      final replay = AppDatabase(NativeDatabase(file));
      addTearDown(replay.close);
      await _expectCompleteSchema(replay);
      record = (await replay.select(replay.visitRecords).get()).singleWhere(
        (row) => row.id == 'r',
      );
      expect(record.workTitle, 'Historical title');
      expect(record.workSubtitle, 'Work subtitle');
      expect(record.pointName, 'Point name');
      expect(record.pointSubtitle, '');
      expect(await replay.select(replay.works).get(), hasLength(1));
      expect((await replay.select(replay.points).get()).single.id, 'p::q');
    },
  );
}

class _VersionAdvanceFailure extends AppDatabase {
  _VersionAdvanceFailure(super.e);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: super.migration.onUpgrade,
    beforeOpen: (_) async => throw StateError('injected before version update'),
  );
}

class _MigrationProbe extends AppDatabase {
  _MigrationProbe(super.e, {this.failAfterWrite, this.atomic = true});

  final int? failAfterWrite;
  final bool atomic;
  final writes = <String>[];

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    await super.customStatement(statement, args);
    writes.add(statement);
    if (writes.length == failAfterWrite) {
      throw StateError('injected migration failure');
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) {
    // Only used to reproduce already-persisted partial legacy migrations.
    return atomic
        ? super.transaction(action, requireNew: requireNew)
        : action();
  }
}

class _LegacyDatabase extends AppDatabase {
  _LegacyDatabase(super.e, this.version);

  final int version;

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (_) => _seedLegacy(this, version));
}

Future<File> _legacyFile(int version) async {
  final directory = await Directory.systemTemp.createTemp('miriago-d1-');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/legacy.sqlite');
  final db = _LegacyDatabase(NativeDatabase(file), version);
  try {
    expect(await _version(db), version);
  } finally {
    await db.close();
  }
  return file;
}

Future<int> _version(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<List<String>> _columns(AppDatabase db, String table) async =>
    (await db.customSelect('PRAGMA table_info("$table")').get())
        .map((row) => row.read<String>('name'))
        .toList();

Future<void> _expectCompleteSchema(AppDatabase db) async {
  expect(await _version(db), db.schemaVersion);
  for (final table in db.allTables) {
    expect(
      await _columns(db, table.actualTableName),
      unorderedEquals(table.$columns.map((column) => column.$name)),
      reason: table.actualTableName,
    );
  }
  expect(
    (await db.customSelect('PRAGMA integrity_check').getSingle()).data.values,
    ['ok'],
  );
  expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
}

Future<void> _expectUpgradedData(AppDatabase db, int version) async {
  await _expectCompleteSchema(db);
  final plans = await db.select(db.plans).get();
  expect(plans, hasLength(2));
  expect(plans.singleWhere((row) => row.id == 'p').name, 'Existing plan');
  final work = (await db.select(db.works).get()).single;
  expect(work.id, 'p::w');
  expect(work.title, 'Work title');
  final point = (await db.select(db.points).get()).single;
  expect(point.id, 'p::q');
  expect(point.workId, 'p::w');
  expect(point.referenceImageUrl, 'https://image.anitabi.cn/point.jpg');
  final records = await db.select(db.visitRecords).get();
  expect(records, hasLength(version >= 3 ? 3 : 0));
  if (version >= 3) {
    final record = records.singleWhere((row) => row.id == 'r');
    expect(record.workTitle, 'Work title');
    expect(record.workSubtitle, 'Work subtitle');
    expect(record.pointName, 'Point name');
    expect(record.pointSubtitle, 'Point subtitle');
    expect(record.photoPath, '/synthetic/photos/original.jpg');
    expect(record.pointId, 'q');
    expect(record.workId, 'w');
    expect(record.capturedAt.millisecondsSinceEpoch, 123000);
    for (final orphan in records.where((row) => row.id != 'r')) {
      expect(orphan.workTitle, isNull);
      expect(orphan.workSubtitle, isNull);
      expect(orphan.pointName, isNull);
      expect(orphan.pointSubtitle, isNull);
    }
  }
  final settings = await db.select(db.appSettingsEntries).get();
  expect(settings, hasLength(version >= 5 ? 1 : 0));
  if (version >= 5) {
    expect(settings.single.uiScale, 1.25);
    expect(settings.single.cameraAspectRatio, '4:3');
    expect(settings.single.cameraMinZoom, version >= 6 ? 0.8 : 0.6);
    expect(settings.single.mapAppearance, 'automatic');
  }
  final groups = await db.select(db.planGroups).get();
  expect(groups, hasLength(version >= 11 ? 1 : 0));
  if (version >= 11) {
    expect(groups.single.anchorPointId, 'p::q');
    expect(point.groupId, 'g');
  }
}

Future<Map<String, Object?>> _snapshot(AppDatabase db) async {
  final schema = await db
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name",
      )
      .get();
  return {
    'version': await _version(db),
    'schema': schema.map((row) => row.data).toList(),
    for (final table in schema)
      table.read<String>('name'):
          (await db
                  .customSelect(
                    'SELECT * FROM "${table.read<String>('name')}" ORDER BY id',
                  )
                  .get())
              .map((row) => row.data)
              .toList(),
  };
}

// Frozen pre-snapshot schemas, independent of today's generated tables and
// migration callback. All paths below are inert strings, not real assets.
Future<void> _seedLegacy(AppDatabase db, int version) async {
  for (final sql in [
    '''CREATE TABLE plans (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, area TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
    '''CREATE TABLE works (
      id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
      bangumi_id INTEGER, title TEXT NOT NULL, subtitle TEXT NOT NULL,
      city TEXT NOT NULL, source TEXT NOT NULL)''',
    '''CREATE TABLE points (
      id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
      work_id TEXT NOT NULL REFERENCES works(id), name TEXT NOT NULL,
      subtitle TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL,
      episode_label TEXT NOT NULL, reference_label TEXT NOT NULL,
      source TEXT NOT NULL, source_id TEXT, reference_image_url TEXT,
      source_url TEXT, sort_order INTEGER NOT NULL DEFAULT 0)''',
    if (version >= 3)
      '''CREATE TABLE visit_records (
        id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, point_id TEXT NOT NULL,
        work_id TEXT NOT NULL, photo_path TEXT NOT NULL,
        reference_mode TEXT NOT NULL, captured_at INTEGER NOT NULL)''',
    if (version >= 5)
      '''CREATE TABLE app_settings_entries (
        id TEXT PRIMARY KEY, ui_scale REAL NOT NULL DEFAULT 1.0,
        camera_aspect_ratio TEXT NOT NULL DEFAULT 'auto')''',
    if (version >= 11)
      '''CREATE TABLE plan_groups (
        id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
        name TEXT NOT NULL, order_index INTEGER NOT NULL DEFAULT 0,
        order_mode TEXT NOT NULL DEFAULT 'unordered', anchor_name TEXT,
        anchor_latitude REAL, anchor_longitude REAL, anchor_point_id TEXT,
        note TEXT, created_at INTEGER NOT NULL)''',
  ]) {
    await db.customStatement(sql);
  }
  const additions = <(int, String, String)>[
    (2, 'points', 'is_current INTEGER NOT NULL DEFAULT 0'),
    (2, 'points', 'completed_at INTEGER'),
    (4, 'visit_records', 'reference_image_path TEXT'),
    (4, 'visit_records', 'reference_image_url TEXT'),
    (6, 'points', 'reference_thumbnail_path TEXT'),
    (6, 'points', 'reference_full_image_path TEXT'),
    (6, 'app_settings_entries', 'camera_min_zoom REAL NOT NULL DEFAULT 0.6'),
    (6, 'app_settings_entries', 'camera_max_zoom REAL NOT NULL DEFAULT 5.0'),
    (7, 'visit_records', 'original_photo_path TEXT'),
    (7, 'visit_records', 'graded_photo_path TEXT'),
    (7, 'visit_records', 'color_grading_mode TEXT'),
    (7, 'visit_records', 'color_grading_params_json TEXT'),
    (7, 'visit_records', 'color_grading_intensity REAL'),
    (
      8,
      'app_settings_entries',
      "theme_palette TEXT NOT NULL DEFAULT 'classicGreen'",
    ),
    (
      9,
      'app_settings_entries',
      "camera_capture_aspect_ratio TEXT NOT NULL DEFAULT 'auto'",
    ),
    (
      10,
      'app_settings_entries',
      'reference_image_scale REAL NOT NULL DEFAULT 1.0',
    ),
    (11, 'plans', 'current_group_id TEXT'),
    (11, 'points', 'group_id TEXT REFERENCES plan_groups(id)'),
    (11, 'points', 'group_order_index INTEGER'),
    (
      12,
      'app_settings_entries',
      'nearest_assign_distance_meters REAL NOT NULL DEFAULT 350.0',
    ),
    (
      13,
      'app_settings_entries',
      "map_tile_provider TEXT NOT NULL DEFAULT 'openFreeMap'",
    ),
    (
      13,
      'app_settings_entries',
      "custom_xyz_tile_url TEXT NOT NULL DEFAULT ''",
    ),
    (
      13,
      'app_settings_entries',
      "custom_map_libre_style_url TEXT NOT NULL DEFAULT ''",
    ),
  ];
  for (final (introduced, table, column) in additions) {
    if (introduced <= version) {
      await db.customStatement('ALTER TABLE $table ADD COLUMN $column');
    }
  }
  for (final sql in [
    "INSERT INTO plans VALUES ('p', 'Existing plan', 'Tokyo', 1, 1, 2${version >= 11 ? ', NULL' : ''})",
    "INSERT INTO plans VALUES ('other', 'Other plan', 'Kyoto', 0, 2, 2${version >= 11 ? ', NULL' : ''})",
    "INSERT INTO works VALUES ('w', 'p', 123, 'Work title', 'Work subtitle', 'Tokyo', 'manual')",
    '''INSERT INTO points (
      id, plan_id, work_id, name, subtitle, latitude, longitude,
      episode_label, reference_label, source, reference_image_url
    ) VALUES ('q', 'p', 'w', 'Point name', 'Point subtitle', 35, 139,
      'Episode 1', 'Reference', 'manual', 'https://img-tc.anitabi.cn/point.jpg')''',
    if (version >= 3) ...[
      "INSERT INTO visit_records (id, plan_id, point_id, work_id, photo_path, reference_mode, captured_at) VALUES ('r', 'p', 'q', 'w', '/synthetic/photos/original.jpg', 'overlay', 123)",
      "INSERT INTO visit_records (id, plan_id, point_id, work_id, photo_path, reference_mode, captured_at) VALUES ('deleted', 'p', 'deleted-q', 'deleted-w', '/synthetic/deleted.jpg', 'overlay', 124)",
      "INSERT INTO visit_records (id, plan_id, point_id, work_id, photo_path, reference_mode, captured_at) VALUES ('cross-plan', 'other', 'q', 'w', '/synthetic/cross.jpg', 'overlay', 125)",
    ],
    if (version >= 5)
      "INSERT INTO app_settings_entries (id, ui_scale, camera_aspect_ratio) VALUES ('settings', 1.25, '4:3')",
    if (version >= 6) 'UPDATE app_settings_entries SET camera_min_zoom = 0.8',
    if (version >= 11) ...[
      "INSERT INTO plan_groups (id, plan_id, name, anchor_point_id, created_at) VALUES ('g', 'p', 'Group', 'q', 1)",
      "UPDATE points SET group_id = 'g', group_order_index = 0",
      "UPDATE plans SET current_group_id = 'g' WHERE id = 'p'",
    ],
  ]) {
    await db.customStatement(sql);
  }
}
