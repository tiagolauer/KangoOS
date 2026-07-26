import 'package:drift/drift.dart';

@TableIndex(name: 'activities_captured_at_idx', columns: {#capturedAt})
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get appName => text()();
  TextColumn get windowTitle => text()();
  TextColumn get capturedText => text().nullable()();
  TextColumn get capturedUrl => text().nullable()();
  DateTimeColumn get capturedAt => dateTime().withDefault(currentDateAndTime)();
}
