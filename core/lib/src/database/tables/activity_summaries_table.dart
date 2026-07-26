import 'package:drift/drift.dart';

enum SummaryKind { periodic, dayRecap, manual }

class SummaryKindConverter extends TypeConverter<SummaryKind, String> {
  const SummaryKindConverter();

  @override
  SummaryKind fromSql(String fromDb) =>
      SummaryKind.values.firstWhere((kind) => kind.name == fromDb);

  @override
  String toSql(SummaryKind value) => value.name;
}

@TableIndex(name: 'activity_summaries_period_end_idx', columns: {#periodEnd})
class ActivitySummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text().map(const SummaryKindConverter())();
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
