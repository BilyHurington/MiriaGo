import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get area => text()();
  TextColumn get currentGroupId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
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
  TextColumn get cameraAspectRatio =>
      text().withDefault(const Constant('auto'))();
  TextColumn get cameraCaptureAspectRatio =>
      text().withDefault(const Constant('auto'))();
  RealColumn get cameraMinZoom => real().withDefault(const Constant(0.6))();
  RealColumn get cameraMaxZoom => real().withDefault(const Constant(5.0))();
  RealColumn get referenceImageScale =>
      real().withDefault(const Constant(1.0))();
  TextColumn get themePalette =>
      text().withDefault(const Constant('classicGreen'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Plans, PlanGroups, Works, Points, VisitRecords, AppSettingsEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 11;

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
    },
  );
}
