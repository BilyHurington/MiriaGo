import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get area => text()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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
  TextColumn get sourceUrl => text().nullable()();
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
      text().withDefault(const Constant('landscape16x9'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Plans, Works, Points, VisitRecords, AppSettingsEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

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
    },
  );
}
