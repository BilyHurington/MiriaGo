import 'package:drift/drift.dart';

import '../anitabi_service_config.dart';

part 'app_database.g.dart';

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get area => text()();
  TextColumn get memo => text().withDefault(const Constant(''))();
  TextColumn get currentGroupId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlanGroups extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(Plans, #id)();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  TextColumn get orderMode => text().withDefault(const Constant('unordered'))();
  TextColumn get anchorName => text().nullable()();
  RealColumn get anchorLatitude => real().nullable()();
  RealColumn get anchorLongitude => real().nullable()();
  TextColumn get anchorPointId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Works extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(Plans, #id)();
  IntColumn get bangumiId => integer().nullable()();
  TextColumn get bangumiSubjectType => text().nullable()();
  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get title => text()();
  TextColumn get subtitle => text()();
  TextColumn get city => text()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Points extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(Plans, #id)();
  TextColumn get workId => text().references(Works, #id)();
  TextColumn get name => text()();
  TextColumn get subtitle => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get episodeLabel => text()();
  TextColumn get referenceLabel => text()();
  TextColumn get source => text()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get referenceImageUrl => text().nullable()();
  TextColumn get referenceThumbnailPath => text().nullable()();
  TextColumn get referenceFullImagePath => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get groupId => text().nullable().references(PlanGroups, #id)();
  IntColumn get groupOrderIndex => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VisitRecords extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get pointId => text()();
  TextColumn get workId => text()();
  TextColumn get workTitle => text().nullable()();
  TextColumn get workSubtitle => text().nullable()();
  TextColumn get pointName => text().nullable()();
  TextColumn get pointSubtitle => text().nullable()();
  TextColumn get photoPath => text()();
  TextColumn get originalPhotoPath => text().nullable()();
  TextColumn get gradedPhotoPath => text().nullable()();
  TextColumn get colorGradingMode => text().nullable()();
  TextColumn get colorGradingParamsJson => text().nullable()();
  RealColumn get colorGradingIntensity => real().nullable()();
  TextColumn get referenceImagePath => text().nullable()();
  TextColumn get referenceImageUrl => text().nullable()();
  TextColumn get referenceMode => text()();
  DateTimeColumn get capturedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppSettingsEntries extends Table {
  TextColumn get id => text()();
  RealColumn get uiScale => real().withDefault(const Constant(1.0))();
  RealColumn get fontScale => real().withDefault(const Constant(1.0))();
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  TextColumn get cameraAspectRatio =>
      text().withDefault(const Constant('auto'))();
  TextColumn get cameraCaptureAspectRatio =>
      text().withDefault(const Constant('auto'))();
  RealColumn get cameraMinZoom => real().withDefault(const Constant(0.6))();
  RealColumn get cameraMaxZoom => real().withDefault(const Constant(5.0))();
  RealColumn get referenceImageScale =>
      real().withDefault(const Constant(1.0))();
  TextColumn get photoLocationStrategy =>
      text().withDefault(const Constant('askOnFirstCapture'))();
  RealColumn get nearestAssignDistanceMeters =>
      real().withDefault(const Constant(350.0))();
  TextColumn get themePalette =>
      text().withDefault(const Constant('classicGreen'))();
  TextColumn get mapTileProvider =>
      text().withDefault(const Constant('openFreeMap'))();
  TextColumn get openFreeMapStyle =>
      text().withDefault(const Constant('liberty'))();
  TextColumn get anitabiImageSource =>
      text().withDefault(const Constant('auto'))();
  TextColumn get anitabiSiteBaseUrl =>
      text().withDefault(const Constant(defaultAnitabiSiteBaseUrl))();
  TextColumn get anitabiStaticDataBaseUrl =>
      text().withDefault(const Constant(defaultAnitabiStaticDataBaseUrl))();
  TextColumn get anitabiApiBaseUrl =>
      text().withDefault(const Constant(defaultAnitabiApiBaseUrl))();
  TextColumn get anitabiOfficialImageBaseUrl =>
      text().withDefault(const Constant(defaultAnitabiOfficialImageBaseUrl))();
  TextColumn get anitabiMirrorImageBaseUrl =>
      text().withDefault(const Constant(defaultAnitabiMirrorImageBaseUrl))();
  TextColumn get navigationApp =>
      text().withDefault(const Constant('googleMaps'))();
  TextColumn get customXyzTileUrl => text().withDefault(const Constant(''))();
  TextColumn get customMapLibreStyleUrl =>
      text().withDefault(const Constant(''))();
  BoolColumn get saveVisitPhotoToGallery =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get autoSaveComparisonToGallery =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get comparisonShowPilgrimName =>
      boolean().withDefault(const Constant(false))();
  TextColumn get comparisonPilgrimName =>
      text().withDefault(const Constant(''))();
  TextColumn get comparisonExportConfigJson =>
      text().withDefault(const Constant(''))();
  BoolColumn get comparisonExportConfigMigrated =>
      boolean().withDefault(const Constant(true))();
  TextColumn get customThemeColorName =>
      text().withDefault(const Constant('自定义'))();
  IntColumn get customThemeColorValue =>
      integer().withDefault(const Constant(0xFF16C6A8))();
  TextColumn get customThemeColorsJson =>
      text().withDefault(const Constant('[]'))();
  RealColumn get customCameraAspectRatioWidth =>
      real().withDefault(const Constant(1.0))();
  RealColumn get customCameraAspectRatioHeight =>
      real().withDefault(const Constant(1.0))();
  IntColumn get mapThumbnailVisibleThreshold =>
      integer().withDefault(const Constant(40))();
  IntColumn get mapThumbnailConcurrentLoads =>
      integer().withDefault(const Constant(10))();
  BoolColumn get showPlanGroupProgress =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get dismissPlanActionsOnOutsideTap =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get mapMarkerClusteringEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get mapMarkerClusterRadius =>
      integer().withDefault(const Constant(40))();
  IntColumn get mapMarkerClusterMaxZoom =>
      integer().withDefault(const Constant(21))();
  IntColumn get mapGroupAreaRadiusMeters =>
      integer().withDefault(const Constant(160))();
  RealColumn get mapMarkerScale => real().withDefault(const Constant(0.9))();
  IntColumn get mapMaxZoom => integer().withDefault(const Constant(22))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Plans, PlanGroups, Works, Points, VisitRecords, AppSettingsEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 39;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(points, points.isCurrent);
        await migrator.addColumn(points, points.completedAt);
      }
      if (from < 3) {
        await migrator.createTable(visitRecords);
      } else if (from < 4) {
        await migrator.addColumn(visitRecords, visitRecords.referenceImagePath);
        await migrator.addColumn(visitRecords, visitRecords.referenceImageUrl);
      }
      if (from < 5) {
        await migrator.createTable(appSettingsEntries);
      }
      if (from < 6) {
        await migrator.addColumn(points, points.referenceThumbnailPath);
        await migrator.addColumn(points, points.referenceFullImagePath);
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.cameraMinZoom,
        );
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.cameraMaxZoom,
        );
      }
      if (from < 7) {
        await migrator.addColumn(visitRecords, visitRecords.originalPhotoPath);
        await migrator.addColumn(visitRecords, visitRecords.gradedPhotoPath);
        await migrator.addColumn(visitRecords, visitRecords.colorGradingMode);
        await migrator.addColumn(
          visitRecords,
          visitRecords.colorGradingParamsJson,
        );
        await migrator.addColumn(
          visitRecords,
          visitRecords.colorGradingIntensity,
        );
      }
      if (from < 8) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.themePalette,
        );
      }
      if (from < 9) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.cameraCaptureAspectRatio,
        );
      }
      if (from < 10) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.referenceImageScale,
        );
      }
      if (from < 11) {
        await migrator.addColumn(plans, plans.currentGroupId);
        await migrator.createTable(planGroups);
        await migrator.addColumn(points, points.groupId);
        await migrator.addColumn(points, points.groupOrderIndex);
      }
      if (from < 12) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.nearestAssignDistanceMeters,
        );
      }
      if (from < 13) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.mapTileProvider,
        );
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.customXyzTileUrl,
        );
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.customMapLibreStyleUrl,
        );
      }
      if (from < 14) {
        await migrator.addColumn(visitRecords, visitRecords.workTitle);
        await migrator.addColumn(visitRecords, visitRecords.workSubtitle);
        await migrator.addColumn(visitRecords, visitRecords.pointName);
        await migrator.addColumn(visitRecords, visitRecords.pointSubtitle);
        await customStatement('''
          UPDATE visit_records
          SET
            work_title = (
              SELECT works.title
              FROM works
              WHERE works.id = visit_records.work_id
                AND works.plan_id = visit_records.plan_id
              LIMIT 1
            ),
            work_subtitle = (
              SELECT works.subtitle
              FROM works
              WHERE works.id = visit_records.work_id
                AND works.plan_id = visit_records.plan_id
              LIMIT 1
            ),
            point_name = (
              SELECT points.name
              FROM points
              WHERE points.id = visit_records.point_id
                AND points.plan_id = visit_records.plan_id
              LIMIT 1
            ),
            point_subtitle = (
              SELECT points.subtitle
              FROM points
              WHERE points.id = visit_records.point_id
                AND points.plan_id = visit_records.plan_id
              LIMIT 1
            )
        ''');
      }
      if (from < 15) {
        await migrator.addColumn(
          appSettingsEntries,
          appSettingsEntries.saveVisitPhotoToGallery,
        );
      }
      if (from < 16) {
        await _addColumnIfMissing(
          migrator,
          'points',
          'note',
          points,
          points.note,
        );
      }
      if (from < 17) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'comparison_show_pilgrim_name',
          appSettingsEntries,
          appSettingsEntries.comparisonShowPilgrimName,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'comparison_pilgrim_name',
          appSettingsEntries,
          appSettingsEntries.comparisonPilgrimName,
        );
      }
      if (from < 22) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'font_scale',
          appSettingsEntries,
          appSettingsEntries.fontScale,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'theme_mode',
          appSettingsEntries,
          appSettingsEntries.themeMode,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'custom_theme_color_name',
          appSettingsEntries,
          appSettingsEntries.customThemeColorName,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'custom_theme_color_value',
          appSettingsEntries,
          appSettingsEntries.customThemeColorValue,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'custom_theme_colors_json',
          appSettingsEntries,
          appSettingsEntries.customThemeColorsJson,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'custom_camera_aspect_ratio_width',
          appSettingsEntries,
          appSettingsEntries.customCameraAspectRatioWidth,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'custom_camera_aspect_ratio_height',
          appSettingsEntries,
          appSettingsEntries.customCameraAspectRatioHeight,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'navigation_app',
          appSettingsEntries,
          appSettingsEntries.navigationApp,
        );
        await normalizeScopedStorageIds();
      }
      if (from < 23) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'auto_save_comparison_to_gallery',
          appSettingsEntries,
          appSettingsEntries.autoSaveComparisonToGallery,
        );
      }
      if (from < 24) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'open_free_map_style',
          appSettingsEntries,
          appSettingsEntries.openFreeMapStyle,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_image_source',
          appSettingsEntries,
          appSettingsEntries.anitabiImageSource,
        );
      }
      if (from < 25) {
        await normalizeAnitabiImageUrls();
      }
      if (from < 26) {
        await _addColumnIfMissing(migrator, 'plans', 'memo', plans, plans.memo);
      }
      if (from < 27) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_thumbnail_visible_threshold',
          appSettingsEntries,
          appSettingsEntries.mapThumbnailVisibleThreshold,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_thumbnail_concurrent_loads',
          appSettingsEntries,
          appSettingsEntries.mapThumbnailConcurrentLoads,
        );
      }
      if (from < 29) {
        await _addColumnIfMissing(
          migrator,
          'works',
          'bangumi_subject_type',
          works,
          works.bangumiSubjectType,
        );
        await _addColumnIfMissing(
          migrator,
          'works',
          'cover_image_url',
          works,
          works.coverImageUrl,
        );
      }
      if (from < 30) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_marker_clustering_enabled',
          appSettingsEntries,
          appSettingsEntries.mapMarkerClusteringEnabled,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_marker_cluster_radius',
          appSettingsEntries,
          appSettingsEntries.mapMarkerClusterRadius,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_marker_cluster_max_zoom',
          appSettingsEntries,
          appSettingsEntries.mapMarkerClusterMaxZoom,
        );
      }
      if (from < 31) {
        await _addColumnIfMissing(
          migrator,
          'plans',
          'order_index',
          plans,
          plans.orderIndex,
        );
        await customStatement('''
          UPDATE plans
          SET order_index = (
            SELECT COUNT(*)
            FROM plans AS earlier
            WHERE earlier.created_at < plans.created_at
              OR (
                earlier.created_at = plans.created_at
                AND earlier.id < plans.id
              )
          )
        ''');
      }
      if (from < 32) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_group_area_radius_meters',
          appSettingsEntries,
          appSettingsEntries.mapGroupAreaRadiusMeters,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_marker_scale',
          appSettingsEntries,
          appSettingsEntries.mapMarkerScale,
        );
      }
      if (from < 33) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'map_max_zoom',
          appSettingsEntries,
          appSettingsEntries.mapMaxZoom,
        );
      }
      if (from < 34) {
        await customStatement('''
          UPDATE app_settings_entries
          SET map_max_zoom = 22
          WHERE map_max_zoom = 20
        ''');
        await customStatement('''
          UPDATE app_settings_entries
          SET map_marker_cluster_max_zoom = 21
          WHERE map_marker_cluster_max_zoom = 18
        ''');
      }
      if (from < 35) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'show_plan_group_progress',
          appSettingsEntries,
          appSettingsEntries.showPlanGroupProgress,
        );
      }
      if (from < 36) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_site_base_url',
          appSettingsEntries,
          appSettingsEntries.anitabiSiteBaseUrl,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_static_data_base_url',
          appSettingsEntries,
          appSettingsEntries.anitabiStaticDataBaseUrl,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_api_base_url',
          appSettingsEntries,
          appSettingsEntries.anitabiApiBaseUrl,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_official_image_base_url',
          appSettingsEntries,
          appSettingsEntries.anitabiOfficialImageBaseUrl,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'anitabi_mirror_image_base_url',
          appSettingsEntries,
          appSettingsEntries.anitabiMirrorImageBaseUrl,
        );
      }
      if (from < 37) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'comparison_export_config_json',
          appSettingsEntries,
          appSettingsEntries.comparisonExportConfigJson,
        );
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'comparison_export_config_migrated',
          appSettingsEntries,
          appSettingsEntries.comparisonExportConfigMigrated,
        );
        await customStatement('''
          UPDATE app_settings_entries
          SET comparison_export_config_migrated = 0
        ''');
      }
      if (from < 38) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'photo_location_strategy',
          appSettingsEntries,
          appSettingsEntries.photoLocationStrategy,
        );
      }
      if (from < 39) {
        await _addColumnIfMissing(
          migrator,
          'app_settings_entries',
          'dismiss_plan_actions_on_outside_tap',
          appSettingsEntries,
          appSettingsEntries.dismissPlanActionsOnOutsideTap,
        );
      }
    },
  );

  Future<void> normalizeAnitabiImageUrls() async {
    await customStatement('''
      UPDATE points
      SET reference_image_url =
        replace(reference_image_url, '://img-tc.anitabi.cn/', '://image.anitabi.cn/')
      WHERE reference_image_url LIKE '%://img-tc.anitabi.cn/%'
    ''');
    await customStatement('''
      UPDATE visit_records
      SET reference_image_url =
        replace(reference_image_url, '://img-tc.anitabi.cn/', '://image.anitabi.cn/')
      WHERE reference_image_url LIKE '%://img-tc.anitabi.cn/%'
    ''');
  }

  Future<void> normalizeScopedStorageIds() async {
    const separator = '::';
    await customStatement('''
      INSERT OR IGNORE INTO works (
        id,
        plan_id,
        bangumi_id,
        title,
        subtitle,
        city,
        source
      )
      SELECT
        points.plan_id || '$separator' || works.id,
        points.plan_id,
        works.bangumi_id,
        works.title,
        works.subtitle,
        works.city,
        works.source
      FROM points
      INNER JOIN works ON works.id = points.work_id
      WHERE instr(points.work_id, points.plan_id || '$separator') != 1
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO works (
        id,
        plan_id,
        bangumi_id,
        title,
        subtitle,
        city,
        source
      )
      SELECT
        plan_id || '$separator' || id,
        plan_id,
        bangumi_id,
        title,
        subtitle,
        city,
        source
      FROM works
      WHERE instr(id, plan_id || '$separator') != 1
    ''');
    await customStatement('''
      UPDATE points
      SET work_id = plan_id || '$separator' || work_id
      WHERE work_id IS NOT NULL
        AND instr(work_id, plan_id || '$separator') != 1
    ''');
    await customStatement('''
      UPDATE plan_groups
      SET anchor_point_id = plan_id || '$separator' || anchor_point_id
      WHERE anchor_point_id IS NOT NULL
        AND instr(anchor_point_id, plan_id || '$separator') != 1
    ''');
    await customStatement('''
      UPDATE points
      SET id = plan_id || '$separator' || id
      WHERE instr(id, plan_id || '$separator') != 1
    ''');
    await customStatement('''
      DELETE FROM works
      WHERE instr(id, plan_id || '$separator') != 1
        AND NOT EXISTS (
          SELECT 1
          FROM points
          WHERE points.work_id = works.id
        )
    ''');
  }

  Future<void> _addColumnIfMissing(
    Migrator migrator,
    String tableName,
    String columnName,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    final exists = columns.any((row) => row.data['name'] == columnName);
    if (!exists) {
      await migrator.addColumn(table, column);
    }
  }
}
