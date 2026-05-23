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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Plans, Works, Points])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
