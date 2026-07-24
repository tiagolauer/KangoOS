// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SnippetsTable extends Snippets with TableInfo<$SnippetsTable, Snippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _languageMeta =
      const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
      'language', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>('tags', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<String>>($SnippetsTable.$convertertags);
  @override
  late final GeneratedColumnWithTypeConverter<List<double>?, String> embedding =
      GeneratedColumn<String>('embedding', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<double>?>($SnippetsTable.$converterembeddingn);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, content, language, tags, embedding, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippets';
  @override
  VerificationContext validateIntegrity(Insertable<Snippet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('language')) {
      context.handle(_languageMeta,
          language.isAcceptableOrUnknown(data['language']!, _languageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Snippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snippet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      language: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language']),
      tags: $SnippetsTable.$convertertags.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!),
      embedding: $SnippetsTable.$converterembeddingn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}embedding'])),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SnippetsTable createAlias(String alias) {
    return $SnippetsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<double>, String> $converterembedding =
      const DoubleListConverter();
  static TypeConverter<List<double>?, String?> $converterembeddingn =
      NullAwareTypeConverter.wrap($converterembedding);
}

class Snippet extends DataClass implements Insertable<Snippet> {
  final int id;
  final String title;
  final String content;
  final String? language;
  final List<String> tags;
  final List<double>? embedding;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Snippet(
      {required this.id,
      required this.title,
      required this.content,
      this.language,
      required this.tags,
      this.embedding,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    {
      map['tags'] = Variable<String>($SnippetsTable.$convertertags.toSql(tags));
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<String>(
          $SnippetsTable.$converterembeddingn.toSql(embedding));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SnippetsCompanion toCompanion(bool nullToAbsent) {
    return SnippetsCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      tags: Value(tags),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Snippet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snippet(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      language: serializer.fromJson<String?>(json['language']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      embedding: serializer.fromJson<List<double>?>(json['embedding']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'language': serializer.toJson<String?>(language),
      'tags': serializer.toJson<List<String>>(tags),
      'embedding': serializer.toJson<List<double>?>(embedding),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Snippet copyWith(
          {int? id,
          String? title,
          String? content,
          Value<String?> language = const Value.absent(),
          List<String>? tags,
          Value<List<double>?> embedding = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Snippet(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        language: language.present ? language.value : this.language,
        tags: tags ?? this.tags,
        embedding: embedding.present ? embedding.value : this.embedding,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Snippet copyWithCompanion(SnippetsCompanion data) {
    return Snippet(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      language: data.language.present ? data.language.value : this.language,
      tags: data.tags.present ? data.tags.value : this.tags,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Snippet(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('embedding: $embedding, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, title, content, language, tags, embedding, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Snippet &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.language == this.language &&
          other.tags == this.tags &&
          other.embedding == this.embedding &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SnippetsCompanion extends UpdateCompanion<Snippet> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String?> language;
  final Value<List<String>> tags;
  final Value<List<double>?> embedding;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SnippetsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.embedding = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SnippetsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String content,
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.embedding = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : title = Value(title),
        content = Value(content);
  static Insertable<Snippet> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? language,
    Expression<String>? tags,
    Expression<String>? embedding,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (language != null) 'language': language,
      if (tags != null) 'tags': tags,
      if (embedding != null) 'embedding': embedding,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SnippetsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? content,
      Value<String?>? language,
      Value<List<String>>? tags,
      Value<List<double>?>? embedding,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return SnippetsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      embedding: embedding ?? this.embedding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (tags.present) {
      map['tags'] =
          Variable<String>($SnippetsTable.$convertertags.toSql(tags.value));
    }
    if (embedding.present) {
      map['embedding'] = Variable<String>(
          $SnippetsTable.$converterembeddingn.toSql(embedding.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('embedding: $embedding, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$KangoosDatabase extends GeneratedDatabase {
  _$KangoosDatabase(QueryExecutor e) : super(e);
  $KangoosDatabaseManager get managers => $KangoosDatabaseManager(this);
  late final $SnippetsTable snippets = $SnippetsTable(this);
  late final Index snippetsUpdatedAtIdx = Index('snippets_updated_at_idx',
      'CREATE INDEX snippets_updated_at_idx ON snippets (updated_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [snippets, snippetsUpdatedAtIdx];
}

typedef $$SnippetsTableCreateCompanionBuilder = SnippetsCompanion Function({
  Value<int> id,
  required String title,
  required String content,
  Value<String?> language,
  Value<List<String>> tags,
  Value<List<double>?> embedding,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$SnippetsTableUpdateCompanionBuilder = SnippetsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> content,
  Value<String?> language,
  Value<List<String>> tags,
  Value<List<double>?> embedding,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$SnippetsTableFilterComposer
    extends Composer<_$KangoosDatabase, $SnippetsTable> {
  $$SnippetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
          column: $table.tags,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<double>?, List<double>, String>
      get embedding => $composableBuilder(
          column: $table.embedding,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SnippetsTableOrderingComposer
    extends Composer<_$KangoosDatabase, $SnippetsTable> {
  $$SnippetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get embedding => $composableBuilder(
      column: $table.embedding, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SnippetsTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $SnippetsTable> {
  $$SnippetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<double>?, String> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SnippetsTableTableManager extends RootTableManager<
    _$KangoosDatabase,
    $SnippetsTable,
    Snippet,
    $$SnippetsTableFilterComposer,
    $$SnippetsTableOrderingComposer,
    $$SnippetsTableAnnotationComposer,
    $$SnippetsTableCreateCompanionBuilder,
    $$SnippetsTableUpdateCompanionBuilder,
    (Snippet, BaseReferences<_$KangoosDatabase, $SnippetsTable, Snippet>),
    Snippet,
    PrefetchHooks Function()> {
  $$SnippetsTableTableManager(_$KangoosDatabase db, $SnippetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> language = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<List<double>?> embedding = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              SnippetsCompanion(
            id: id,
            title: title,
            content: content,
            language: language,
            tags: tags,
            embedding: embedding,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String content,
            Value<String?> language = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<List<double>?> embedding = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              SnippetsCompanion.insert(
            id: id,
            title: title,
            content: content,
            language: language,
            tags: tags,
            embedding: embedding,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SnippetsTableProcessedTableManager = ProcessedTableManager<
    _$KangoosDatabase,
    $SnippetsTable,
    Snippet,
    $$SnippetsTableFilterComposer,
    $$SnippetsTableOrderingComposer,
    $$SnippetsTableAnnotationComposer,
    $$SnippetsTableCreateCompanionBuilder,
    $$SnippetsTableUpdateCompanionBuilder,
    (Snippet, BaseReferences<_$KangoosDatabase, $SnippetsTable, Snippet>),
    Snippet,
    PrefetchHooks Function()>;

class $KangoosDatabaseManager {
  final _$KangoosDatabase _db;
  $KangoosDatabaseManager(this._db);
  $$SnippetsTableTableManager get snippets =>
      $$SnippetsTableTableManager(_db, _db.snippets);
}
