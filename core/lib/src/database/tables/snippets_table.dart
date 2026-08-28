import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class DoubleListConverter extends TypeConverter<List<double>, String> {
  const DoubleListConverter();

  @override
  List<double> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).map((e) => (e as num).toDouble()).toList();

  @override
  String toSql(List<double> value) => jsonEncode(value);
}

class SnippetVector {
  const SnippetVector({
    required this.id,
    required this.embedding,
    required this.providerId,
  });

  final int id;
  final List<double> embedding;
  final String providerId;
}

class EmbeddingConverter extends TypeConverter<List<double>, Uint8List> {
  const EmbeddingConverter();

  @override
  List<double> fromSql(Uint8List fromDb) =>
      Float32List.sublistView(Uint8List.fromList(fromDb));

  @override
  Uint8List toSql(List<double> value) =>
      Float32List.fromList(value).buffer.asUint8List();
}

@TableIndex(name: 'snippets_updated_at_idx', columns: {#updatedAt})
class Snippets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get language => text().nullable()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  BlobColumn get embedding =>
      blob().map(const EmbeddingConverter()).nullable()();
  TextColumn get embeddingProviderId => text().nullable()();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
