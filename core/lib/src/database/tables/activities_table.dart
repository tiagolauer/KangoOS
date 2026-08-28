import 'package:drift/drift.dart';

@TableIndex(name: 'activities_captured_at_idx', columns: {#capturedAt})
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get appName => text()();
  TextColumn get windowTitle => text()();
  TextColumn get capturedText => text().nullable()();
  TextColumn get capturedUrl => text().nullable()();
  TextColumn get capturedClipboard => text().nullable()();
  TextColumn get capturedScreenText => text().nullable()();
  TextColumn get capturedAudioText => text().nullable()();
  DateTimeColumn get capturedAt => dateTime().withDefault(currentDateAndTime)();
}
