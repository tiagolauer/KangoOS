import 'dart:convert';

import 'package:drift/drift.dart';

import 'snippets_table.dart';

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) => (jsonDecode(fromDb) as List).cast<int>();

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

@TableIndex(name: 'memory_episodes_started_at_idx', columns: {#startedAt})
@TableIndex(name: 'memory_episodes_ended_at_idx', columns: {#endedAt})
class MemoryEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceKey => text().unique()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get title => text()();
  TextColumn get summary => text()();
  TextColumn get applications => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get urls => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get topics => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get entities => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get sourceActivityIds =>
      text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  BlobColumn get embedding =>
      blob().map(const EmbeddingConverter()).nullable()();
  TextColumn get embeddingProviderId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
