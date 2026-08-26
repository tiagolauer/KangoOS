import 'package:drift/drift.dart';

import 'snippets_table.dart';

enum SummaryKind { periodic, dayRecap, manual, session, daily, weekly, durable }

const automaticDurableMemoryPrefix = '[auto-durable:';

class ActivitySummaryVector {
  const ActivitySummaryVector({required this.id, required this.embedding});

  final int id;
  final List<double> embedding;
}

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
  BlobColumn get embedding =>
      blob().map(const EmbeddingConverter()).nullable()();
  TextColumn get embeddingProviderId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
