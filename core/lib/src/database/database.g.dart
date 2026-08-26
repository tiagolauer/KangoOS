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
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($SnippetsTable.$convertertags);
  @override
  late final GeneratedColumnWithTypeConverter<List<double>?, Uint8List>
  embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  ).withConverter<List<double>?>($SnippetsTable.$converterembeddingn);
  static const VerificationMeta _embeddingProviderIdMeta =
      const VerificationMeta('embeddingProviderId');
  @override
  late final GeneratedColumn<String> embeddingProviderId =
      GeneratedColumn<String>(
        'embedding_provider_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    language,
    tags,
    embedding,
    embeddingProviderId,
    syncId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Snippet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('embedding_provider_id')) {
      context.handle(
        _embeddingProviderIdMeta,
        embeddingProviderId.isAcceptableOrUnknown(
          data['embedding_provider_id']!,
          _embeddingProviderIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Snippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snippet(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      tags: $SnippetsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      embedding: $SnippetsTable.$converterembeddingn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}embedding'],
        ),
      ),
      embeddingProviderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_provider_id'],
      ),
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $SnippetsTable createAlias(String alias) {
    return $SnippetsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<double>, Uint8List> $converterembedding =
      const EmbeddingConverter();
  static TypeConverter<List<double>?, Uint8List?> $converterembeddingn =
      NullAwareTypeConverter.wrap($converterembedding);
}

class Snippet extends DataClass implements Insertable<Snippet> {
  final int id;
  final String title;
  final String content;
  final String? language;
  final List<String> tags;
  final List<double>? embedding;
  final String? embeddingProviderId;
  final String? syncId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Snippet({
    required this.id,
    required this.title,
    required this.content,
    this.language,
    required this.tags,
    this.embedding,
    this.embeddingProviderId,
    this.syncId,
    required this.createdAt,
    required this.updatedAt,
  });
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
      map['embedding'] = Variable<Uint8List>(
        $SnippetsTable.$converterembeddingn.toSql(embedding),
      );
    }
    if (!nullToAbsent || embeddingProviderId != null) {
      map['embedding_provider_id'] = Variable<String>(embeddingProviderId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
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
      language:
          language == null && nullToAbsent
              ? const Value.absent()
              : Value(language),
      tags: Value(tags),
      embedding:
          embedding == null && nullToAbsent
              ? const Value.absent()
              : Value(embedding),
      embeddingProviderId:
          embeddingProviderId == null && nullToAbsent
              ? const Value.absent()
              : Value(embeddingProviderId),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Snippet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snippet(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      language: serializer.fromJson<String?>(json['language']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      embedding: serializer.fromJson<List<double>?>(json['embedding']),
      embeddingProviderId: serializer.fromJson<String?>(
        json['embeddingProviderId'],
      ),
      syncId: serializer.fromJson<String?>(json['syncId']),
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
      'embeddingProviderId': serializer.toJson<String?>(embeddingProviderId),
      'syncId': serializer.toJson<String?>(syncId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Snippet copyWith({
    int? id,
    String? title,
    String? content,
    Value<String?> language = const Value.absent(),
    List<String>? tags,
    Value<List<double>?> embedding = const Value.absent(),
    Value<String?> embeddingProviderId = const Value.absent(),
    Value<String?> syncId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Snippet(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    language: language.present ? language.value : this.language,
    tags: tags ?? this.tags,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingProviderId:
        embeddingProviderId.present
            ? embeddingProviderId.value
            : this.embeddingProviderId,
    syncId: syncId.present ? syncId.value : this.syncId,
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
      embeddingProviderId:
          data.embeddingProviderId.present
              ? data.embeddingProviderId.value
              : this.embeddingProviderId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
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
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    language,
    tags,
    embedding,
    embeddingProviderId,
    syncId,
    createdAt,
    updatedAt,
  );
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
          other.embeddingProviderId == this.embeddingProviderId &&
          other.syncId == this.syncId &&
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
  final Value<String?> embeddingProviderId;
  final Value<String?> syncId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SnippetsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.syncId = const Value.absent(),
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
    this.embeddingProviderId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title),
       content = Value(content);
  static Insertable<Snippet> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? language,
    Expression<String>? tags,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingProviderId,
    Expression<String>? syncId,
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
      if (embeddingProviderId != null)
        'embedding_provider_id': embeddingProviderId,
      if (syncId != null) 'sync_id': syncId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SnippetsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? content,
    Value<String?>? language,
    Value<List<String>>? tags,
    Value<List<double>?>? embedding,
    Value<String?>? embeddingProviderId,
    Value<String?>? syncId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SnippetsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      embedding: embedding ?? this.embedding,
      embeddingProviderId: embeddingProviderId ?? this.embeddingProviderId,
      syncId: syncId ?? this.syncId,
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
      map['tags'] = Variable<String>(
        $SnippetsTable.$convertertags.toSql(tags.value),
      );
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(
        $SnippetsTable.$converterembeddingn.toSql(embedding.value),
      );
    }
    if (embeddingProviderId.present) {
      map['embedding_provider_id'] = Variable<String>(
        embeddingProviderId.value,
      );
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
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
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, Activity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appNameMeta = const VerificationMeta(
    'appName',
  );
  @override
  late final GeneratedColumn<String> appName = GeneratedColumn<String>(
    'app_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowTitleMeta = const VerificationMeta(
    'windowTitle',
  );
  @override
  late final GeneratedColumn<String> windowTitle = GeneratedColumn<String>(
    'window_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTextMeta = const VerificationMeta(
    'capturedText',
  );
  @override
  late final GeneratedColumn<String> capturedText = GeneratedColumn<String>(
    'captured_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedUrlMeta = const VerificationMeta(
    'capturedUrl',
  );
  @override
  late final GeneratedColumn<String> capturedUrl = GeneratedColumn<String>(
    'captured_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedClipboardMeta = const VerificationMeta(
    'capturedClipboard',
  );
  @override
  late final GeneratedColumn<String> capturedClipboard =
      GeneratedColumn<String>(
        'captured_clipboard',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capturedScreenTextMeta =
      const VerificationMeta('capturedScreenText');
  @override
  late final GeneratedColumn<String> capturedScreenText =
      GeneratedColumn<String>(
        'captured_screen_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capturedAudioTextMeta = const VerificationMeta(
    'capturedAudioText',
  );
  @override
  late final GeneratedColumn<String> capturedAudioText =
      GeneratedColumn<String>(
        'captured_audio_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    appName,
    windowTitle,
    capturedText,
    capturedUrl,
    capturedClipboard,
    capturedScreenText,
    capturedAudioText,
    capturedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Activity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('app_name')) {
      context.handle(
        _appNameMeta,
        appName.isAcceptableOrUnknown(data['app_name']!, _appNameMeta),
      );
    } else if (isInserting) {
      context.missing(_appNameMeta);
    }
    if (data.containsKey('window_title')) {
      context.handle(
        _windowTitleMeta,
        windowTitle.isAcceptableOrUnknown(
          data['window_title']!,
          _windowTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowTitleMeta);
    }
    if (data.containsKey('captured_text')) {
      context.handle(
        _capturedTextMeta,
        capturedText.isAcceptableOrUnknown(
          data['captured_text']!,
          _capturedTextMeta,
        ),
      );
    }
    if (data.containsKey('captured_url')) {
      context.handle(
        _capturedUrlMeta,
        capturedUrl.isAcceptableOrUnknown(
          data['captured_url']!,
          _capturedUrlMeta,
        ),
      );
    }
    if (data.containsKey('captured_clipboard')) {
      context.handle(
        _capturedClipboardMeta,
        capturedClipboard.isAcceptableOrUnknown(
          data['captured_clipboard']!,
          _capturedClipboardMeta,
        ),
      );
    }
    if (data.containsKey('captured_screen_text')) {
      context.handle(
        _capturedScreenTextMeta,
        capturedScreenText.isAcceptableOrUnknown(
          data['captured_screen_text']!,
          _capturedScreenTextMeta,
        ),
      );
    }
    if (data.containsKey('captured_audio_text')) {
      context.handle(
        _capturedAudioTextMeta,
        capturedAudioText.isAcceptableOrUnknown(
          data['captured_audio_text']!,
          _capturedAudioTextMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Activity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Activity(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      appName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}app_name'],
          )!,
      windowTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}window_title'],
          )!,
      capturedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_text'],
      ),
      capturedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_url'],
      ),
      capturedClipboard: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_clipboard'],
      ),
      capturedScreenText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_screen_text'],
      ),
      capturedAudioText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_audio_text'],
      ),
      capturedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}captured_at'],
          )!,
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class Activity extends DataClass implements Insertable<Activity> {
  final int id;
  final String? sourceId;
  final String appName;
  final String windowTitle;
  final String? capturedText;
  final String? capturedUrl;
  final String? capturedClipboard;
  final String? capturedScreenText;
  final String? capturedAudioText;
  final DateTime capturedAt;
  const Activity({
    required this.id,
    this.sourceId,
    required this.appName,
    required this.windowTitle,
    this.capturedText,
    this.capturedUrl,
    this.capturedClipboard,
    this.capturedScreenText,
    this.capturedAudioText,
    required this.capturedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['app_name'] = Variable<String>(appName);
    map['window_title'] = Variable<String>(windowTitle);
    if (!nullToAbsent || capturedText != null) {
      map['captured_text'] = Variable<String>(capturedText);
    }
    if (!nullToAbsent || capturedUrl != null) {
      map['captured_url'] = Variable<String>(capturedUrl);
    }
    if (!nullToAbsent || capturedClipboard != null) {
      map['captured_clipboard'] = Variable<String>(capturedClipboard);
    }
    if (!nullToAbsent || capturedScreenText != null) {
      map['captured_screen_text'] = Variable<String>(capturedScreenText);
    }
    if (!nullToAbsent || capturedAudioText != null) {
      map['captured_audio_text'] = Variable<String>(capturedAudioText);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      sourceId:
          sourceId == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceId),
      appName: Value(appName),
      windowTitle: Value(windowTitle),
      capturedText:
          capturedText == null && nullToAbsent
              ? const Value.absent()
              : Value(capturedText),
      capturedUrl:
          capturedUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(capturedUrl),
      capturedClipboard:
          capturedClipboard == null && nullToAbsent
              ? const Value.absent()
              : Value(capturedClipboard),
      capturedScreenText:
          capturedScreenText == null && nullToAbsent
              ? const Value.absent()
              : Value(capturedScreenText),
      capturedAudioText:
          capturedAudioText == null && nullToAbsent
              ? const Value.absent()
              : Value(capturedAudioText),
      capturedAt: Value(capturedAt),
    );
  }

  factory Activity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Activity(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      appName: serializer.fromJson<String>(json['appName']),
      windowTitle: serializer.fromJson<String>(json['windowTitle']),
      capturedText: serializer.fromJson<String?>(json['capturedText']),
      capturedUrl: serializer.fromJson<String?>(json['capturedUrl']),
      capturedClipboard: serializer.fromJson<String?>(
        json['capturedClipboard'],
      ),
      capturedScreenText: serializer.fromJson<String?>(
        json['capturedScreenText'],
      ),
      capturedAudioText: serializer.fromJson<String?>(
        json['capturedAudioText'],
      ),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String?>(sourceId),
      'appName': serializer.toJson<String>(appName),
      'windowTitle': serializer.toJson<String>(windowTitle),
      'capturedText': serializer.toJson<String?>(capturedText),
      'capturedUrl': serializer.toJson<String?>(capturedUrl),
      'capturedClipboard': serializer.toJson<String?>(capturedClipboard),
      'capturedScreenText': serializer.toJson<String?>(capturedScreenText),
      'capturedAudioText': serializer.toJson<String?>(capturedAudioText),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
    };
  }

  Activity copyWith({
    int? id,
    Value<String?> sourceId = const Value.absent(),
    String? appName,
    String? windowTitle,
    Value<String?> capturedText = const Value.absent(),
    Value<String?> capturedUrl = const Value.absent(),
    Value<String?> capturedClipboard = const Value.absent(),
    Value<String?> capturedScreenText = const Value.absent(),
    Value<String?> capturedAudioText = const Value.absent(),
    DateTime? capturedAt,
  }) => Activity(
    id: id ?? this.id,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    appName: appName ?? this.appName,
    windowTitle: windowTitle ?? this.windowTitle,
    capturedText: capturedText.present ? capturedText.value : this.capturedText,
    capturedUrl: capturedUrl.present ? capturedUrl.value : this.capturedUrl,
    capturedClipboard:
        capturedClipboard.present
            ? capturedClipboard.value
            : this.capturedClipboard,
    capturedScreenText:
        capturedScreenText.present
            ? capturedScreenText.value
            : this.capturedScreenText,
    capturedAudioText:
        capturedAudioText.present
            ? capturedAudioText.value
            : this.capturedAudioText,
    capturedAt: capturedAt ?? this.capturedAt,
  );
  Activity copyWithCompanion(ActivitiesCompanion data) {
    return Activity(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      appName: data.appName.present ? data.appName.value : this.appName,
      windowTitle:
          data.windowTitle.present ? data.windowTitle.value : this.windowTitle,
      capturedText:
          data.capturedText.present
              ? data.capturedText.value
              : this.capturedText,
      capturedUrl:
          data.capturedUrl.present ? data.capturedUrl.value : this.capturedUrl,
      capturedClipboard:
          data.capturedClipboard.present
              ? data.capturedClipboard.value
              : this.capturedClipboard,
      capturedScreenText:
          data.capturedScreenText.present
              ? data.capturedScreenText.value
              : this.capturedScreenText,
      capturedAudioText:
          data.capturedAudioText.present
              ? data.capturedAudioText.value
              : this.capturedAudioText,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Activity(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('appName: $appName, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('capturedText: $capturedText, ')
          ..write('capturedUrl: $capturedUrl, ')
          ..write('capturedClipboard: $capturedClipboard, ')
          ..write('capturedScreenText: $capturedScreenText, ')
          ..write('capturedAudioText: $capturedAudioText, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    appName,
    windowTitle,
    capturedText,
    capturedUrl,
    capturedClipboard,
    capturedScreenText,
    capturedAudioText,
    capturedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.appName == this.appName &&
          other.windowTitle == this.windowTitle &&
          other.capturedText == this.capturedText &&
          other.capturedUrl == this.capturedUrl &&
          other.capturedClipboard == this.capturedClipboard &&
          other.capturedScreenText == this.capturedScreenText &&
          other.capturedAudioText == this.capturedAudioText &&
          other.capturedAt == this.capturedAt);
}

class ActivitiesCompanion extends UpdateCompanion<Activity> {
  final Value<int> id;
  final Value<String?> sourceId;
  final Value<String> appName;
  final Value<String> windowTitle;
  final Value<String?> capturedText;
  final Value<String?> capturedUrl;
  final Value<String?> capturedClipboard;
  final Value<String?> capturedScreenText;
  final Value<String?> capturedAudioText;
  final Value<DateTime> capturedAt;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.appName = const Value.absent(),
    this.windowTitle = const Value.absent(),
    this.capturedText = const Value.absent(),
    this.capturedUrl = const Value.absent(),
    this.capturedClipboard = const Value.absent(),
    this.capturedScreenText = const Value.absent(),
    this.capturedAudioText = const Value.absent(),
    this.capturedAt = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    required String appName,
    required String windowTitle,
    this.capturedText = const Value.absent(),
    this.capturedUrl = const Value.absent(),
    this.capturedClipboard = const Value.absent(),
    this.capturedScreenText = const Value.absent(),
    this.capturedAudioText = const Value.absent(),
    this.capturedAt = const Value.absent(),
  }) : appName = Value(appName),
       windowTitle = Value(windowTitle);
  static Insertable<Activity> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? appName,
    Expression<String>? windowTitle,
    Expression<String>? capturedText,
    Expression<String>? capturedUrl,
    Expression<String>? capturedClipboard,
    Expression<String>? capturedScreenText,
    Expression<String>? capturedAudioText,
    Expression<DateTime>? capturedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (appName != null) 'app_name': appName,
      if (windowTitle != null) 'window_title': windowTitle,
      if (capturedText != null) 'captured_text': capturedText,
      if (capturedUrl != null) 'captured_url': capturedUrl,
      if (capturedClipboard != null) 'captured_clipboard': capturedClipboard,
      if (capturedScreenText != null)
        'captured_screen_text': capturedScreenText,
      if (capturedAudioText != null) 'captured_audio_text': capturedAudioText,
      if (capturedAt != null) 'captured_at': capturedAt,
    });
  }

  ActivitiesCompanion copyWith({
    Value<int>? id,
    Value<String?>? sourceId,
    Value<String>? appName,
    Value<String>? windowTitle,
    Value<String?>? capturedText,
    Value<String?>? capturedUrl,
    Value<String?>? capturedClipboard,
    Value<String?>? capturedScreenText,
    Value<String?>? capturedAudioText,
    Value<DateTime>? capturedAt,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      appName: appName ?? this.appName,
      windowTitle: windowTitle ?? this.windowTitle,
      capturedText: capturedText ?? this.capturedText,
      capturedUrl: capturedUrl ?? this.capturedUrl,
      capturedClipboard: capturedClipboard ?? this.capturedClipboard,
      capturedScreenText: capturedScreenText ?? this.capturedScreenText,
      capturedAudioText: capturedAudioText ?? this.capturedAudioText,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (appName.present) {
      map['app_name'] = Variable<String>(appName.value);
    }
    if (windowTitle.present) {
      map['window_title'] = Variable<String>(windowTitle.value);
    }
    if (capturedText.present) {
      map['captured_text'] = Variable<String>(capturedText.value);
    }
    if (capturedUrl.present) {
      map['captured_url'] = Variable<String>(capturedUrl.value);
    }
    if (capturedClipboard.present) {
      map['captured_clipboard'] = Variable<String>(capturedClipboard.value);
    }
    if (capturedScreenText.present) {
      map['captured_screen_text'] = Variable<String>(capturedScreenText.value);
    }
    if (capturedAudioText.present) {
      map['captured_audio_text'] = Variable<String>(capturedAudioText.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('appName: $appName, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('capturedText: $capturedText, ')
          ..write('capturedUrl: $capturedUrl, ')
          ..write('capturedClipboard: $capturedClipboard, ')
          ..write('capturedScreenText: $capturedScreenText, ')
          ..write('capturedAudioText: $capturedAudioText, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }
}

class $ActivitySummariesTable extends ActivitySummaries
    with TableInfo<$ActivitySummariesTable, ActivitySummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SummaryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SummaryKind>($ActivitySummariesTable.$converterkind);
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<DateTime> periodStart = GeneratedColumn<DateTime>(
    'period_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<DateTime> periodEnd = GeneratedColumn<DateTime>(
    'period_end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<double>?, Uint8List>
  embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  ).withConverter<List<double>?>($ActivitySummariesTable.$converterembeddingn);
  static const VerificationMeta _embeddingProviderIdMeta =
      const VerificationMeta('embeddingProviderId');
  @override
  late final GeneratedColumn<String> embeddingProviderId =
      GeneratedColumn<String>(
        'embedding_provider_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    periodStart,
    periodEnd,
    content,
    embedding,
    embeddingProviderId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivitySummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodStartMeta);
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    } else if (isInserting) {
      context.missing(_periodEndMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('embedding_provider_id')) {
      context.handle(
        _embeddingProviderIdMeta,
        embeddingProviderId.isAcceptableOrUnknown(
          data['embedding_provider_id']!,
          _embeddingProviderIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivitySummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivitySummary(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      kind: $ActivitySummariesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      periodStart:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}period_start'],
          )!,
      periodEnd:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}period_end'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      embedding: $ActivitySummariesTable.$converterembeddingn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}embedding'],
        ),
      ),
      embeddingProviderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_provider_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ActivitySummariesTable createAlias(String alias) {
    return $ActivitySummariesTable(attachedDatabase, alias);
  }

  static TypeConverter<SummaryKind, String> $converterkind =
      const SummaryKindConverter();
  static TypeConverter<List<double>, Uint8List> $converterembedding =
      const EmbeddingConverter();
  static TypeConverter<List<double>?, Uint8List?> $converterembeddingn =
      NullAwareTypeConverter.wrap($converterembedding);
}

class ActivitySummary extends DataClass implements Insertable<ActivitySummary> {
  final int id;
  final SummaryKind kind;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String content;
  final List<double>? embedding;
  final String? embeddingProviderId;
  final DateTime createdAt;
  const ActivitySummary({
    required this.id,
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.content,
    this.embedding,
    this.embeddingProviderId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $ActivitySummariesTable.$converterkind.toSql(kind),
      );
    }
    map['period_start'] = Variable<DateTime>(periodStart);
    map['period_end'] = Variable<DateTime>(periodEnd);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(
        $ActivitySummariesTable.$converterembeddingn.toSql(embedding),
      );
    }
    if (!nullToAbsent || embeddingProviderId != null) {
      map['embedding_provider_id'] = Variable<String>(embeddingProviderId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ActivitySummariesCompanion toCompanion(bool nullToAbsent) {
    return ActivitySummariesCompanion(
      id: Value(id),
      kind: Value(kind),
      periodStart: Value(periodStart),
      periodEnd: Value(periodEnd),
      content: Value(content),
      embedding:
          embedding == null && nullToAbsent
              ? const Value.absent()
              : Value(embedding),
      embeddingProviderId:
          embeddingProviderId == null && nullToAbsent
              ? const Value.absent()
              : Value(embeddingProviderId),
      createdAt: Value(createdAt),
    );
  }

  factory ActivitySummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivitySummary(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<SummaryKind>(json['kind']),
      periodStart: serializer.fromJson<DateTime>(json['periodStart']),
      periodEnd: serializer.fromJson<DateTime>(json['periodEnd']),
      content: serializer.fromJson<String>(json['content']),
      embedding: serializer.fromJson<List<double>?>(json['embedding']),
      embeddingProviderId: serializer.fromJson<String?>(
        json['embeddingProviderId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<SummaryKind>(kind),
      'periodStart': serializer.toJson<DateTime>(periodStart),
      'periodEnd': serializer.toJson<DateTime>(periodEnd),
      'content': serializer.toJson<String>(content),
      'embedding': serializer.toJson<List<double>?>(embedding),
      'embeddingProviderId': serializer.toJson<String?>(embeddingProviderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ActivitySummary copyWith({
    int? id,
    SummaryKind? kind,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? content,
    Value<List<double>?> embedding = const Value.absent(),
    Value<String?> embeddingProviderId = const Value.absent(),
    DateTime? createdAt,
  }) => ActivitySummary(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    content: content ?? this.content,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingProviderId:
        embeddingProviderId.present
            ? embeddingProviderId.value
            : this.embeddingProviderId,
    createdAt: createdAt ?? this.createdAt,
  );
  ActivitySummary copyWithCompanion(ActivitySummariesCompanion data) {
    return ActivitySummary(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      periodStart:
          data.periodStart.present ? data.periodStart.value : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      content: data.content.present ? data.content.value : this.content,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingProviderId:
          data.embeddingProviderId.present
              ? data.embeddingProviderId.value
              : this.embeddingProviderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivitySummary(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    periodStart,
    periodEnd,
    content,
    embedding,
    embeddingProviderId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivitySummary &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.content == this.content &&
          other.embedding == this.embedding &&
          other.embeddingProviderId == this.embeddingProviderId &&
          other.createdAt == this.createdAt);
}

class ActivitySummariesCompanion extends UpdateCompanion<ActivitySummary> {
  final Value<int> id;
  final Value<SummaryKind> kind;
  final Value<DateTime> periodStart;
  final Value<DateTime> periodEnd;
  final Value<String> content;
  final Value<List<double>?> embedding;
  final Value<String?> embeddingProviderId;
  final Value<DateTime> createdAt;
  const ActivitySummariesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.content = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ActivitySummariesCompanion.insert({
    this.id = const Value.absent(),
    required SummaryKind kind,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String content,
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : kind = Value(kind),
       periodStart = Value(periodStart),
       periodEnd = Value(periodEnd),
       content = Value(content);
  static Insertable<ActivitySummary> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<DateTime>? periodStart,
    Expression<DateTime>? periodEnd,
    Expression<String>? content,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingProviderId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (content != null) 'content': content,
      if (embedding != null) 'embedding': embedding,
      if (embeddingProviderId != null)
        'embedding_provider_id': embeddingProviderId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ActivitySummariesCompanion copyWith({
    Value<int>? id,
    Value<SummaryKind>? kind,
    Value<DateTime>? periodStart,
    Value<DateTime>? periodEnd,
    Value<String>? content,
    Value<List<double>?>? embedding,
    Value<String?>? embeddingProviderId,
    Value<DateTime>? createdAt,
  }) {
    return ActivitySummariesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      embeddingProviderId: embeddingProviderId ?? this.embeddingProviderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ActivitySummariesTable.$converterkind.toSql(kind.value),
      );
    }
    if (periodStart.present) {
      map['period_start'] = Variable<DateTime>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<DateTime>(periodEnd.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(
        $ActivitySummariesTable.$converterembeddingn.toSql(embedding.value),
      );
    }
    if (embeddingProviderId.present) {
      map['embedding_provider_id'] = Variable<String>(
        embeddingProviderId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitySummariesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith({int? id, DateTime? createdAt, DateTime? updatedAt}) =>
      Conversation(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConversationsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
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
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ConversationMessagesTable extends ConversationMessages
    with TableInfo<$ConversationMessagesTable, ConversationMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LlmRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LlmRole>($ConversationMessagesTable.$converterrole);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<double>?, Uint8List>
  embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  ).withConverter<List<double>?>(
    $ConversationMessagesTable.$converterembeddingn,
  );
  static const VerificationMeta _embeddingProviderIdMeta =
      const VerificationMeta('embeddingProviderId');
  @override
  late final GeneratedColumn<String> embeddingProviderId =
      GeneratedColumn<String>(
        'embedding_provider_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    role,
    content,
    embedding,
    embeddingProviderId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('embedding_provider_id')) {
      context.handle(
        _embeddingProviderIdMeta,
        embeddingProviderId.isAcceptableOrUnknown(
          data['embedding_provider_id']!,
          _embeddingProviderIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMessage(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      conversationId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}conversation_id'],
          )!,
      role: $ConversationMessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      embedding: $ConversationMessagesTable.$converterembeddingn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}embedding'],
        ),
      ),
      embeddingProviderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_provider_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ConversationMessagesTable createAlias(String alias) {
    return $ConversationMessagesTable(attachedDatabase, alias);
  }

  static TypeConverter<LlmRole, String> $converterrole =
      const LlmRoleConverter();
  static TypeConverter<List<double>, Uint8List> $converterembedding =
      const EmbeddingConverter();
  static TypeConverter<List<double>?, Uint8List?> $converterembeddingn =
      NullAwareTypeConverter.wrap($converterembedding);
}

class ConversationMessage extends DataClass
    implements Insertable<ConversationMessage> {
  final int id;
  final int conversationId;
  final LlmRole role;
  final String content;
  final List<double>? embedding;
  final String? embeddingProviderId;
  final DateTime createdAt;
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.embedding,
    this.embeddingProviderId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    {
      map['role'] = Variable<String>(
        $ConversationMessagesTable.$converterrole.toSql(role),
      );
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(
        $ConversationMessagesTable.$converterembeddingn.toSql(embedding),
      );
    }
    if (!nullToAbsent || embeddingProviderId != null) {
      map['embedding_provider_id'] = Variable<String>(embeddingProviderId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ConversationMessagesCompanion toCompanion(bool nullToAbsent) {
    return ConversationMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      embedding:
          embedding == null && nullToAbsent
              ? const Value.absent()
              : Value(embedding),
      embeddingProviderId:
          embeddingProviderId == null && nullToAbsent
              ? const Value.absent()
              : Value(embeddingProviderId),
      createdAt: Value(createdAt),
    );
  }

  factory ConversationMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      role: serializer.fromJson<LlmRole>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      embedding: serializer.fromJson<List<double>?>(json['embedding']),
      embeddingProviderId: serializer.fromJson<String?>(
        json['embeddingProviderId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'role': serializer.toJson<LlmRole>(role),
      'content': serializer.toJson<String>(content),
      'embedding': serializer.toJson<List<double>?>(embedding),
      'embeddingProviderId': serializer.toJson<String?>(embeddingProviderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ConversationMessage copyWith({
    int? id,
    int? conversationId,
    LlmRole? role,
    String? content,
    Value<List<double>?> embedding = const Value.absent(),
    Value<String?> embeddingProviderId = const Value.absent(),
    DateTime? createdAt,
  }) => ConversationMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingProviderId:
        embeddingProviderId.present
            ? embeddingProviderId.value
            : this.embeddingProviderId,
    createdAt: createdAt ?? this.createdAt,
  );
  ConversationMessage copyWithCompanion(ConversationMessagesCompanion data) {
    return ConversationMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId:
          data.conversationId.present
              ? data.conversationId.value
              : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingProviderId:
          data.embeddingProviderId.present
              ? data.embeddingProviderId.value
              : this.embeddingProviderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    role,
    content,
    embedding,
    embeddingProviderId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.embedding == this.embedding &&
          other.embeddingProviderId == this.embeddingProviderId &&
          other.createdAt == this.createdAt);
}

class ConversationMessagesCompanion
    extends UpdateCompanion<ConversationMessage> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<LlmRole> role;
  final Value<String> content;
  final Value<List<double>?> embedding;
  final Value<String?> embeddingProviderId;
  final Value<DateTime> createdAt;
  const ConversationMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ConversationMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required LlmRole role,
    required String content,
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : conversationId = Value(conversationId),
       role = Value(role),
       content = Value(content);
  static Insertable<ConversationMessage> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingProviderId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (embedding != null) 'embedding': embedding,
      if (embeddingProviderId != null)
        'embedding_provider_id': embeddingProviderId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ConversationMessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? conversationId,
    Value<LlmRole>? role,
    Value<String>? content,
    Value<List<double>?>? embedding,
    Value<String?>? embeddingProviderId,
    Value<DateTime>? createdAt,
  }) {
    return ConversationMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      embeddingProviderId: embeddingProviderId ?? this.embeddingProviderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $ConversationMessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(
        $ConversationMessagesTable.$converterembeddingn.toSql(embedding.value),
      );
    }
    if (embeddingProviderId.present) {
      map['embedding_provider_id'] = Variable<String>(
        embeddingProviderId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DeletedSnippetsTable extends DeletedSnippets
    with TableInfo<$DeletedSnippetsTable, DeletedSnippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletedSnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [syncId, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deleted_snippets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeletedSnippet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  DeletedSnippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletedSnippet(
      syncId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sync_id'],
          )!,
      deletedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}deleted_at'],
          )!,
    );
  }

  @override
  $DeletedSnippetsTable createAlias(String alias) {
    return $DeletedSnippetsTable(attachedDatabase, alias);
  }
}

class DeletedSnippet extends DataClass implements Insertable<DeletedSnippet> {
  final String syncId;
  final DateTime deletedAt;
  const DeletedSnippet({required this.syncId, required this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  DeletedSnippetsCompanion toCompanion(bool nullToAbsent) {
    return DeletedSnippetsCompanion(
      syncId: Value(syncId),
      deletedAt: Value(deletedAt),
    );
  }

  factory DeletedSnippet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeletedSnippet(
      syncId: serializer.fromJson<String>(json['syncId']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  DeletedSnippet copyWith({String? syncId, DateTime? deletedAt}) =>
      DeletedSnippet(
        syncId: syncId ?? this.syncId,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  DeletedSnippet copyWithCompanion(DeletedSnippetsCompanion data) {
    return DeletedSnippet(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeletedSnippet(')
          ..write('syncId: $syncId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncId, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeletedSnippet &&
          other.syncId == this.syncId &&
          other.deletedAt == this.deletedAt);
}

class DeletedSnippetsCompanion extends UpdateCompanion<DeletedSnippet> {
  final Value<String> syncId;
  final Value<DateTime> deletedAt;
  final Value<int> rowid;
  const DeletedSnippetsCompanion({
    this.syncId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeletedSnippetsCompanion.insert({
    required String syncId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId);
  static Insertable<DeletedSnippet> custom({
    Expression<String>? syncId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeletedSnippetsCompanion copyWith({
    Value<String>? syncId,
    Value<DateTime>? deletedAt,
    Value<int>? rowid,
  }) {
    return DeletedSnippetsCompanion(
      syncId: syncId ?? this.syncId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletedSnippetsCompanion(')
          ..write('syncId: $syncId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEpisodesTable extends MemoryEpisodes
    with TableInfo<$MemoryEpisodesTable, MemoryEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  applications = GeneratedColumn<String>(
    'applications',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($MemoryEpisodesTable.$converterapplications);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> urls =
      GeneratedColumn<String>(
        'urls',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($MemoryEpisodesTable.$converterurls);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> topics =
      GeneratedColumn<String>(
        'topics',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($MemoryEpisodesTable.$convertertopics);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> entities =
      GeneratedColumn<String>(
        'entities',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($MemoryEpisodesTable.$converterentities);
  static const VerificationMeta _formationVersionMeta = const VerificationMeta(
    'formationVersion',
  );
  @override
  late final GeneratedColumn<int> formationVersion = GeneratedColumn<int>(
    'formation_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MemoryFormationStatus, String>
  formationStatus = GeneratedColumn<String>(
    'formation_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deterministic'),
  ).withConverter<MemoryFormationStatus>(
    $MemoryEpisodesTable.$converterformationStatus,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> decisions =
      GeneratedColumn<String>(
        'decisions',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($MemoryEpisodesTable.$converterdecisions);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  actionItems = GeneratedColumn<String>(
    'action_items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($MemoryEpisodesTable.$converteractionItems);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  technologies = GeneratedColumn<String>(
    'technologies',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($MemoryEpisodesTable.$convertertechnologies);
  static const VerificationMeta _formationModelIdMeta = const VerificationMeta(
    'formationModelId',
  );
  @override
  late final GeneratedColumn<String> formationModelId = GeneratedColumn<String>(
    'formation_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String>
  sourceActivityIds = GeneratedColumn<String>(
    'source_activity_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<int>>($MemoryEpisodesTable.$convertersourceActivityIds);
  @override
  late final GeneratedColumnWithTypeConverter<List<double>?, Uint8List>
  embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  ).withConverter<List<double>?>($MemoryEpisodesTable.$converterembeddingn);
  static const VerificationMeta _embeddingProviderIdMeta =
      const VerificationMeta('embeddingProviderId');
  @override
  late final GeneratedColumn<String> embeddingProviderId =
      GeneratedColumn<String>(
        'embedding_provider_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceKey,
    startedAt,
    endedAt,
    title,
    summary,
    applications,
    urls,
    topics,
    entities,
    formationVersion,
    contentHash,
    formationStatus,
    confidence,
    decisions,
    actionItems,
    technologies,
    formationModelId,
    sourceActivityIds,
    embedding,
    embeddingProviderId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('formation_version')) {
      context.handle(
        _formationVersionMeta,
        formationVersion.isAcceptableOrUnknown(
          data['formation_version']!,
          _formationVersionMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('formation_model_id')) {
      context.handle(
        _formationModelIdMeta,
        formationModelId.isAcceptableOrUnknown(
          data['formation_model_id']!,
          _formationModelIdMeta,
        ),
      );
    }
    if (data.containsKey('embedding_provider_id')) {
      context.handle(
        _embeddingProviderIdMeta,
        embeddingProviderId.isAcceptableOrUnknown(
          data['embedding_provider_id']!,
          _embeddingProviderIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEpisode(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      sourceKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_key'],
          )!,
      startedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_at'],
          )!,
      endedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}ended_at'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      summary:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}summary'],
          )!,
      applications: $MemoryEpisodesTable.$converterapplications.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}applications'],
        )!,
      ),
      urls: $MemoryEpisodesTable.$converterurls.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}urls'],
        )!,
      ),
      topics: $MemoryEpisodesTable.$convertertopics.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}topics'],
        )!,
      ),
      entities: $MemoryEpisodesTable.$converterentities.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entities'],
        )!,
      ),
      formationVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}formation_version'],
          )!,
      contentHash:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content_hash'],
          )!,
      formationStatus: $MemoryEpisodesTable.$converterformationStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}formation_status'],
        )!,
      ),
      confidence:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}confidence'],
          )!,
      decisions: $MemoryEpisodesTable.$converterdecisions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}decisions'],
        )!,
      ),
      actionItems: $MemoryEpisodesTable.$converteractionItems.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action_items'],
        )!,
      ),
      technologies: $MemoryEpisodesTable.$convertertechnologies.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}technologies'],
        )!,
      ),
      formationModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formation_model_id'],
      ),
      sourceActivityIds: $MemoryEpisodesTable.$convertersourceActivityIds
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}source_activity_ids'],
            )!,
          ),
      embedding: $MemoryEpisodesTable.$converterembeddingn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}embedding'],
        ),
      ),
      embeddingProviderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_provider_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $MemoryEpisodesTable createAlias(String alias) {
    return $MemoryEpisodesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterapplications =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterurls =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertopics =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterentities =
      const StringListConverter();
  static TypeConverter<MemoryFormationStatus, String>
  $converterformationStatus = const MemoryFormationStatusConverter();
  static TypeConverter<List<String>, String> $converterdecisions =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converteractionItems =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertechnologies =
      const StringListConverter();
  static TypeConverter<List<int>, String> $convertersourceActivityIds =
      const IntListConverter();
  static TypeConverter<List<double>, Uint8List> $converterembedding =
      const EmbeddingConverter();
  static TypeConverter<List<double>?, Uint8List?> $converterembeddingn =
      NullAwareTypeConverter.wrap($converterembedding);
}

class MemoryEpisode extends DataClass implements Insertable<MemoryEpisode> {
  final int id;
  final String sourceKey;
  final DateTime startedAt;
  final DateTime endedAt;
  final String title;
  final String summary;
  final List<String> applications;
  final List<String> urls;
  final List<String> topics;
  final List<String> entities;
  final int formationVersion;
  final String contentHash;
  final MemoryFormationStatus formationStatus;
  final double confidence;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> technologies;
  final String? formationModelId;
  final List<int> sourceActivityIds;
  final List<double>? embedding;
  final String? embeddingProviderId;
  final DateTime createdAt;
  const MemoryEpisode({
    required this.id,
    required this.sourceKey,
    required this.startedAt,
    required this.endedAt,
    required this.title,
    required this.summary,
    required this.applications,
    required this.urls,
    required this.topics,
    required this.entities,
    required this.formationVersion,
    required this.contentHash,
    required this.formationStatus,
    required this.confidence,
    required this.decisions,
    required this.actionItems,
    required this.technologies,
    this.formationModelId,
    required this.sourceActivityIds,
    this.embedding,
    this.embeddingProviderId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_key'] = Variable<String>(sourceKey);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    {
      map['applications'] = Variable<String>(
        $MemoryEpisodesTable.$converterapplications.toSql(applications),
      );
    }
    {
      map['urls'] = Variable<String>(
        $MemoryEpisodesTable.$converterurls.toSql(urls),
      );
    }
    {
      map['topics'] = Variable<String>(
        $MemoryEpisodesTable.$convertertopics.toSql(topics),
      );
    }
    {
      map['entities'] = Variable<String>(
        $MemoryEpisodesTable.$converterentities.toSql(entities),
      );
    }
    map['formation_version'] = Variable<int>(formationVersion);
    map['content_hash'] = Variable<String>(contentHash);
    {
      map['formation_status'] = Variable<String>(
        $MemoryEpisodesTable.$converterformationStatus.toSql(formationStatus),
      );
    }
    map['confidence'] = Variable<double>(confidence);
    {
      map['decisions'] = Variable<String>(
        $MemoryEpisodesTable.$converterdecisions.toSql(decisions),
      );
    }
    {
      map['action_items'] = Variable<String>(
        $MemoryEpisodesTable.$converteractionItems.toSql(actionItems),
      );
    }
    {
      map['technologies'] = Variable<String>(
        $MemoryEpisodesTable.$convertertechnologies.toSql(technologies),
      );
    }
    if (!nullToAbsent || formationModelId != null) {
      map['formation_model_id'] = Variable<String>(formationModelId);
    }
    {
      map['source_activity_ids'] = Variable<String>(
        $MemoryEpisodesTable.$convertersourceActivityIds.toSql(
          sourceActivityIds,
        ),
      );
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(
        $MemoryEpisodesTable.$converterembeddingn.toSql(embedding),
      );
    }
    if (!nullToAbsent || embeddingProviderId != null) {
      map['embedding_provider_id'] = Variable<String>(embeddingProviderId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MemoryEpisodesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEpisodesCompanion(
      id: Value(id),
      sourceKey: Value(sourceKey),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      title: Value(title),
      summary: Value(summary),
      applications: Value(applications),
      urls: Value(urls),
      topics: Value(topics),
      entities: Value(entities),
      formationVersion: Value(formationVersion),
      contentHash: Value(contentHash),
      formationStatus: Value(formationStatus),
      confidence: Value(confidence),
      decisions: Value(decisions),
      actionItems: Value(actionItems),
      technologies: Value(technologies),
      formationModelId:
          formationModelId == null && nullToAbsent
              ? const Value.absent()
              : Value(formationModelId),
      sourceActivityIds: Value(sourceActivityIds),
      embedding:
          embedding == null && nullToAbsent
              ? const Value.absent()
              : Value(embedding),
      embeddingProviderId:
          embeddingProviderId == null && nullToAbsent
              ? const Value.absent()
              : Value(embeddingProviderId),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEpisode(
      id: serializer.fromJson<int>(json['id']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      applications: serializer.fromJson<List<String>>(json['applications']),
      urls: serializer.fromJson<List<String>>(json['urls']),
      topics: serializer.fromJson<List<String>>(json['topics']),
      entities: serializer.fromJson<List<String>>(json['entities']),
      formationVersion: serializer.fromJson<int>(json['formationVersion']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      formationStatus: serializer.fromJson<MemoryFormationStatus>(
        json['formationStatus'],
      ),
      confidence: serializer.fromJson<double>(json['confidence']),
      decisions: serializer.fromJson<List<String>>(json['decisions']),
      actionItems: serializer.fromJson<List<String>>(json['actionItems']),
      technologies: serializer.fromJson<List<String>>(json['technologies']),
      formationModelId: serializer.fromJson<String?>(json['formationModelId']),
      sourceActivityIds: serializer.fromJson<List<int>>(
        json['sourceActivityIds'],
      ),
      embedding: serializer.fromJson<List<double>?>(json['embedding']),
      embeddingProviderId: serializer.fromJson<String?>(
        json['embeddingProviderId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'applications': serializer.toJson<List<String>>(applications),
      'urls': serializer.toJson<List<String>>(urls),
      'topics': serializer.toJson<List<String>>(topics),
      'entities': serializer.toJson<List<String>>(entities),
      'formationVersion': serializer.toJson<int>(formationVersion),
      'contentHash': serializer.toJson<String>(contentHash),
      'formationStatus': serializer.toJson<MemoryFormationStatus>(
        formationStatus,
      ),
      'confidence': serializer.toJson<double>(confidence),
      'decisions': serializer.toJson<List<String>>(decisions),
      'actionItems': serializer.toJson<List<String>>(actionItems),
      'technologies': serializer.toJson<List<String>>(technologies),
      'formationModelId': serializer.toJson<String?>(formationModelId),
      'sourceActivityIds': serializer.toJson<List<int>>(sourceActivityIds),
      'embedding': serializer.toJson<List<double>?>(embedding),
      'embeddingProviderId': serializer.toJson<String?>(embeddingProviderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MemoryEpisode copyWith({
    int? id,
    String? sourceKey,
    DateTime? startedAt,
    DateTime? endedAt,
    String? title,
    String? summary,
    List<String>? applications,
    List<String>? urls,
    List<String>? topics,
    List<String>? entities,
    int? formationVersion,
    String? contentHash,
    MemoryFormationStatus? formationStatus,
    double? confidence,
    List<String>? decisions,
    List<String>? actionItems,
    List<String>? technologies,
    Value<String?> formationModelId = const Value.absent(),
    List<int>? sourceActivityIds,
    Value<List<double>?> embedding = const Value.absent(),
    Value<String?> embeddingProviderId = const Value.absent(),
    DateTime? createdAt,
  }) => MemoryEpisode(
    id: id ?? this.id,
    sourceKey: sourceKey ?? this.sourceKey,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    applications: applications ?? this.applications,
    urls: urls ?? this.urls,
    topics: topics ?? this.topics,
    entities: entities ?? this.entities,
    formationVersion: formationVersion ?? this.formationVersion,
    contentHash: contentHash ?? this.contentHash,
    formationStatus: formationStatus ?? this.formationStatus,
    confidence: confidence ?? this.confidence,
    decisions: decisions ?? this.decisions,
    actionItems: actionItems ?? this.actionItems,
    technologies: technologies ?? this.technologies,
    formationModelId:
        formationModelId.present
            ? formationModelId.value
            : this.formationModelId,
    sourceActivityIds: sourceActivityIds ?? this.sourceActivityIds,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingProviderId:
        embeddingProviderId.present
            ? embeddingProviderId.value
            : this.embeddingProviderId,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryEpisode copyWithCompanion(MemoryEpisodesCompanion data) {
    return MemoryEpisode(
      id: data.id.present ? data.id.value : this.id,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      applications:
          data.applications.present
              ? data.applications.value
              : this.applications,
      urls: data.urls.present ? data.urls.value : this.urls,
      topics: data.topics.present ? data.topics.value : this.topics,
      entities: data.entities.present ? data.entities.value : this.entities,
      formationVersion:
          data.formationVersion.present
              ? data.formationVersion.value
              : this.formationVersion,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      formationStatus:
          data.formationStatus.present
              ? data.formationStatus.value
              : this.formationStatus,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
      decisions: data.decisions.present ? data.decisions.value : this.decisions,
      actionItems:
          data.actionItems.present ? data.actionItems.value : this.actionItems,
      technologies:
          data.technologies.present
              ? data.technologies.value
              : this.technologies,
      formationModelId:
          data.formationModelId.present
              ? data.formationModelId.value
              : this.formationModelId,
      sourceActivityIds:
          data.sourceActivityIds.present
              ? data.sourceActivityIds.value
              : this.sourceActivityIds,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingProviderId:
          data.embeddingProviderId.present
              ? data.embeddingProviderId.value
              : this.embeddingProviderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisode(')
          ..write('id: $id, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('applications: $applications, ')
          ..write('urls: $urls, ')
          ..write('topics: $topics, ')
          ..write('entities: $entities, ')
          ..write('formationVersion: $formationVersion, ')
          ..write('contentHash: $contentHash, ')
          ..write('formationStatus: $formationStatus, ')
          ..write('confidence: $confidence, ')
          ..write('decisions: $decisions, ')
          ..write('actionItems: $actionItems, ')
          ..write('technologies: $technologies, ')
          ..write('formationModelId: $formationModelId, ')
          ..write('sourceActivityIds: $sourceActivityIds, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sourceKey,
    startedAt,
    endedAt,
    title,
    summary,
    applications,
    urls,
    topics,
    entities,
    formationVersion,
    contentHash,
    formationStatus,
    confidence,
    decisions,
    actionItems,
    technologies,
    formationModelId,
    sourceActivityIds,
    embedding,
    embeddingProviderId,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEpisode &&
          other.id == this.id &&
          other.sourceKey == this.sourceKey &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.applications == this.applications &&
          other.urls == this.urls &&
          other.topics == this.topics &&
          other.entities == this.entities &&
          other.formationVersion == this.formationVersion &&
          other.contentHash == this.contentHash &&
          other.formationStatus == this.formationStatus &&
          other.confidence == this.confidence &&
          other.decisions == this.decisions &&
          other.actionItems == this.actionItems &&
          other.technologies == this.technologies &&
          other.formationModelId == this.formationModelId &&
          other.sourceActivityIds == this.sourceActivityIds &&
          other.embedding == this.embedding &&
          other.embeddingProviderId == this.embeddingProviderId &&
          other.createdAt == this.createdAt);
}

class MemoryEpisodesCompanion extends UpdateCompanion<MemoryEpisode> {
  final Value<int> id;
  final Value<String> sourceKey;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<String> title;
  final Value<String> summary;
  final Value<List<String>> applications;
  final Value<List<String>> urls;
  final Value<List<String>> topics;
  final Value<List<String>> entities;
  final Value<int> formationVersion;
  final Value<String> contentHash;
  final Value<MemoryFormationStatus> formationStatus;
  final Value<double> confidence;
  final Value<List<String>> decisions;
  final Value<List<String>> actionItems;
  final Value<List<String>> technologies;
  final Value<String?> formationModelId;
  final Value<List<int>> sourceActivityIds;
  final Value<List<double>?> embedding;
  final Value<String?> embeddingProviderId;
  final Value<DateTime> createdAt;
  const MemoryEpisodesCompanion({
    this.id = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.applications = const Value.absent(),
    this.urls = const Value.absent(),
    this.topics = const Value.absent(),
    this.entities = const Value.absent(),
    this.formationVersion = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.formationStatus = const Value.absent(),
    this.confidence = const Value.absent(),
    this.decisions = const Value.absent(),
    this.actionItems = const Value.absent(),
    this.technologies = const Value.absent(),
    this.formationModelId = const Value.absent(),
    this.sourceActivityIds = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MemoryEpisodesCompanion.insert({
    this.id = const Value.absent(),
    required String sourceKey,
    required DateTime startedAt,
    required DateTime endedAt,
    required String title,
    required String summary,
    this.applications = const Value.absent(),
    this.urls = const Value.absent(),
    this.topics = const Value.absent(),
    this.entities = const Value.absent(),
    this.formationVersion = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.formationStatus = const Value.absent(),
    this.confidence = const Value.absent(),
    this.decisions = const Value.absent(),
    this.actionItems = const Value.absent(),
    this.technologies = const Value.absent(),
    this.formationModelId = const Value.absent(),
    this.sourceActivityIds = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingProviderId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       title = Value(title),
       summary = Value(summary);
  static Insertable<MemoryEpisode> custom({
    Expression<int>? id,
    Expression<String>? sourceKey,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? applications,
    Expression<String>? urls,
    Expression<String>? topics,
    Expression<String>? entities,
    Expression<int>? formationVersion,
    Expression<String>? contentHash,
    Expression<String>? formationStatus,
    Expression<double>? confidence,
    Expression<String>? decisions,
    Expression<String>? actionItems,
    Expression<String>? technologies,
    Expression<String>? formationModelId,
    Expression<String>? sourceActivityIds,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingProviderId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceKey != null) 'source_key': sourceKey,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (applications != null) 'applications': applications,
      if (urls != null) 'urls': urls,
      if (topics != null) 'topics': topics,
      if (entities != null) 'entities': entities,
      if (formationVersion != null) 'formation_version': formationVersion,
      if (contentHash != null) 'content_hash': contentHash,
      if (formationStatus != null) 'formation_status': formationStatus,
      if (confidence != null) 'confidence': confidence,
      if (decisions != null) 'decisions': decisions,
      if (actionItems != null) 'action_items': actionItems,
      if (technologies != null) 'technologies': technologies,
      if (formationModelId != null) 'formation_model_id': formationModelId,
      if (sourceActivityIds != null) 'source_activity_ids': sourceActivityIds,
      if (embedding != null) 'embedding': embedding,
      if (embeddingProviderId != null)
        'embedding_provider_id': embeddingProviderId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MemoryEpisodesCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceKey,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<String>? title,
    Value<String>? summary,
    Value<List<String>>? applications,
    Value<List<String>>? urls,
    Value<List<String>>? topics,
    Value<List<String>>? entities,
    Value<int>? formationVersion,
    Value<String>? contentHash,
    Value<MemoryFormationStatus>? formationStatus,
    Value<double>? confidence,
    Value<List<String>>? decisions,
    Value<List<String>>? actionItems,
    Value<List<String>>? technologies,
    Value<String?>? formationModelId,
    Value<List<int>>? sourceActivityIds,
    Value<List<double>?>? embedding,
    Value<String?>? embeddingProviderId,
    Value<DateTime>? createdAt,
  }) {
    return MemoryEpisodesCompanion(
      id: id ?? this.id,
      sourceKey: sourceKey ?? this.sourceKey,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      applications: applications ?? this.applications,
      urls: urls ?? this.urls,
      topics: topics ?? this.topics,
      entities: entities ?? this.entities,
      formationVersion: formationVersion ?? this.formationVersion,
      contentHash: contentHash ?? this.contentHash,
      formationStatus: formationStatus ?? this.formationStatus,
      confidence: confidence ?? this.confidence,
      decisions: decisions ?? this.decisions,
      actionItems: actionItems ?? this.actionItems,
      technologies: technologies ?? this.technologies,
      formationModelId: formationModelId ?? this.formationModelId,
      sourceActivityIds: sourceActivityIds ?? this.sourceActivityIds,
      embedding: embedding ?? this.embedding,
      embeddingProviderId: embeddingProviderId ?? this.embeddingProviderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (applications.present) {
      map['applications'] = Variable<String>(
        $MemoryEpisodesTable.$converterapplications.toSql(applications.value),
      );
    }
    if (urls.present) {
      map['urls'] = Variable<String>(
        $MemoryEpisodesTable.$converterurls.toSql(urls.value),
      );
    }
    if (topics.present) {
      map['topics'] = Variable<String>(
        $MemoryEpisodesTable.$convertertopics.toSql(topics.value),
      );
    }
    if (entities.present) {
      map['entities'] = Variable<String>(
        $MemoryEpisodesTable.$converterentities.toSql(entities.value),
      );
    }
    if (formationVersion.present) {
      map['formation_version'] = Variable<int>(formationVersion.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (formationStatus.present) {
      map['formation_status'] = Variable<String>(
        $MemoryEpisodesTable.$converterformationStatus.toSql(
          formationStatus.value,
        ),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (decisions.present) {
      map['decisions'] = Variable<String>(
        $MemoryEpisodesTable.$converterdecisions.toSql(decisions.value),
      );
    }
    if (actionItems.present) {
      map['action_items'] = Variable<String>(
        $MemoryEpisodesTable.$converteractionItems.toSql(actionItems.value),
      );
    }
    if (technologies.present) {
      map['technologies'] = Variable<String>(
        $MemoryEpisodesTable.$convertertechnologies.toSql(technologies.value),
      );
    }
    if (formationModelId.present) {
      map['formation_model_id'] = Variable<String>(formationModelId.value);
    }
    if (sourceActivityIds.present) {
      map['source_activity_ids'] = Variable<String>(
        $MemoryEpisodesTable.$convertersourceActivityIds.toSql(
          sourceActivityIds.value,
        ),
      );
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(
        $MemoryEpisodesTable.$converterembeddingn.toSql(embedding.value),
      );
    }
    if (embeddingProviderId.present) {
      map['embedding_provider_id'] = Variable<String>(
        embeddingProviderId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('applications: $applications, ')
          ..write('urls: $urls, ')
          ..write('topics: $topics, ')
          ..write('entities: $entities, ')
          ..write('formationVersion: $formationVersion, ')
          ..write('contentHash: $contentHash, ')
          ..write('formationStatus: $formationStatus, ')
          ..write('confidence: $confidence, ')
          ..write('decisions: $decisions, ')
          ..write('actionItems: $actionItems, ')
          ..write('technologies: $technologies, ')
          ..write('formationModelId: $formationModelId, ')
          ..write('sourceActivityIds: $sourceActivityIds, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingProviderId: $embeddingProviderId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$KangoosDatabase extends GeneratedDatabase {
  _$KangoosDatabase(QueryExecutor e) : super(e);
  $KangoosDatabaseManager get managers => $KangoosDatabaseManager(this);
  late final $SnippetsTable snippets = $SnippetsTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $ActivitySummariesTable activitySummaries =
      $ActivitySummariesTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ConversationMessagesTable conversationMessages =
      $ConversationMessagesTable(this);
  late final $DeletedSnippetsTable deletedSnippets = $DeletedSnippetsTable(
    this,
  );
  late final $MemoryEpisodesTable memoryEpisodes = $MemoryEpisodesTable(this);
  late final Index snippetsUpdatedAtIdx = Index(
    'snippets_updated_at_idx',
    'CREATE INDEX snippets_updated_at_idx ON snippets (updated_at)',
  );
  late final Index activitiesCapturedAtIdx = Index(
    'activities_captured_at_idx',
    'CREATE INDEX activities_captured_at_idx ON activities (captured_at)',
  );
  late final Index activitySummariesPeriodEndIdx = Index(
    'activity_summaries_period_end_idx',
    'CREATE INDEX activity_summaries_period_end_idx ON activity_summaries (period_end)',
  );
  late final Index conversationMessagesConversationIdIdx = Index(
    'conversation_messages_conversation_id_idx',
    'CREATE INDEX conversation_messages_conversation_id_idx ON conversation_messages (conversation_id)',
  );
  late final Index deletedSnippetsDeletedAtIdx = Index(
    'deleted_snippets_deleted_at_idx',
    'CREATE INDEX deleted_snippets_deleted_at_idx ON deleted_snippets (deleted_at)',
  );
  late final Index memoryEpisodesStartedAtIdx = Index(
    'memory_episodes_started_at_idx',
    'CREATE INDEX memory_episodes_started_at_idx ON memory_episodes (started_at)',
  );
  late final Index memoryEpisodesEndedAtIdx = Index(
    'memory_episodes_ended_at_idx',
    'CREATE INDEX memory_episodes_ended_at_idx ON memory_episodes (ended_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    snippets,
    activities,
    activitySummaries,
    conversations,
    conversationMessages,
    deletedSnippets,
    memoryEpisodes,
    snippetsUpdatedAtIdx,
    activitiesCapturedAtIdx,
    activitySummariesPeriodEndIdx,
    conversationMessagesConversationIdIdx,
    deletedSnippetsDeletedAtIdx,
    memoryEpisodesStartedAtIdx,
    memoryEpisodesEndedAtIdx,
  ];
}

typedef $$SnippetsTableCreateCompanionBuilder =
    SnippetsCompanion Function({
      Value<int> id,
      required String title,
      required String content,
      Value<String?> language,
      Value<List<String>> tags,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<String?> syncId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$SnippetsTableUpdateCompanionBuilder =
    SnippetsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> content,
      Value<String?> language,
      Value<List<String>> tags,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<String?> syncId,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<double>?, List<double>, Uint8List>
  get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumnWithTypeConverter<List<double>?, Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SnippetsTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function()
        > {
  $$SnippetsTableTableManager(_$KangoosDatabase db, $SnippetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SnippetsCompanion(
                id: id,
                title: title,
                content: content,
                language: language,
                tags: tags,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String content,
                Value<String?> language = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SnippetsCompanion.insert(
                id: id,
                title: title,
                content: content,
                language: language,
                tags: tags,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnippetsTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableCreateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<int> id,
      Value<String?> sourceId,
      required String appName,
      required String windowTitle,
      Value<String?> capturedText,
      Value<String?> capturedUrl,
      Value<String?> capturedClipboard,
      Value<String?> capturedScreenText,
      Value<String?> capturedAudioText,
      Value<DateTime> capturedAt,
    });
typedef $$ActivitiesTableUpdateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<int> id,
      Value<String?> sourceId,
      Value<String> appName,
      Value<String> windowTitle,
      Value<String?> capturedText,
      Value<String?> capturedUrl,
      Value<String?> capturedClipboard,
      Value<String?> capturedScreenText,
      Value<String?> capturedAudioText,
      Value<DateTime> capturedAt,
    });

class $$ActivitiesTableFilterComposer
    extends Composer<_$KangoosDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appName => $composableBuilder(
    column: $table.appName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedText => $composableBuilder(
    column: $table.capturedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedUrl => $composableBuilder(
    column: $table.capturedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedClipboard => $composableBuilder(
    column: $table.capturedClipboard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedScreenText => $composableBuilder(
    column: $table.capturedScreenText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedAudioText => $composableBuilder(
    column: $table.capturedAudioText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$KangoosDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appName => $composableBuilder(
    column: $table.appName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedText => $composableBuilder(
    column: $table.capturedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedUrl => $composableBuilder(
    column: $table.capturedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedClipboard => $composableBuilder(
    column: $table.capturedClipboard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedScreenText => $composableBuilder(
    column: $table.capturedScreenText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedAudioText => $composableBuilder(
    column: $table.capturedAudioText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get appName =>
      $composableBuilder(column: $table.appName, builder: (column) => column);

  GeneratedColumn<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedText => $composableBuilder(
    column: $table.capturedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedUrl => $composableBuilder(
    column: $table.capturedUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedClipboard => $composableBuilder(
    column: $table.capturedClipboard,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedScreenText => $composableBuilder(
    column: $table.capturedScreenText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedAudioText => $composableBuilder(
    column: $table.capturedAudioText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $ActivitiesTable,
          Activity,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (
            Activity,
            BaseReferences<_$KangoosDatabase, $ActivitiesTable, Activity>,
          ),
          Activity,
          PrefetchHooks Function()
        > {
  $$ActivitiesTableTableManager(_$KangoosDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String> appName = const Value.absent(),
                Value<String> windowTitle = const Value.absent(),
                Value<String?> capturedText = const Value.absent(),
                Value<String?> capturedUrl = const Value.absent(),
                Value<String?> capturedClipboard = const Value.absent(),
                Value<String?> capturedScreenText = const Value.absent(),
                Value<String?> capturedAudioText = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                sourceId: sourceId,
                appName: appName,
                windowTitle: windowTitle,
                capturedText: capturedText,
                capturedUrl: capturedUrl,
                capturedClipboard: capturedClipboard,
                capturedScreenText: capturedScreenText,
                capturedAudioText: capturedAudioText,
                capturedAt: capturedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                required String appName,
                required String windowTitle,
                Value<String?> capturedText = const Value.absent(),
                Value<String?> capturedUrl = const Value.absent(),
                Value<String?> capturedClipboard = const Value.absent(),
                Value<String?> capturedScreenText = const Value.absent(),
                Value<String?> capturedAudioText = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                sourceId: sourceId,
                appName: appName,
                windowTitle: windowTitle,
                capturedText: capturedText,
                capturedUrl: capturedUrl,
                capturedClipboard: capturedClipboard,
                capturedScreenText: capturedScreenText,
                capturedAudioText: capturedAudioText,
                capturedAt: capturedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $ActivitiesTable,
      Activity,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (Activity, BaseReferences<_$KangoosDatabase, $ActivitiesTable, Activity>),
      Activity,
      PrefetchHooks Function()
    >;
typedef $$ActivitySummariesTableCreateCompanionBuilder =
    ActivitySummariesCompanion Function({
      Value<int> id,
      required SummaryKind kind,
      required DateTime periodStart,
      required DateTime periodEnd,
      required String content,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });
typedef $$ActivitySummariesTableUpdateCompanionBuilder =
    ActivitySummariesCompanion Function({
      Value<int> id,
      Value<SummaryKind> kind,
      Value<DateTime> periodStart,
      Value<DateTime> periodEnd,
      Value<String> content,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });

class $$ActivitySummariesTableFilterComposer
    extends Composer<_$KangoosDatabase, $ActivitySummariesTable> {
  $$ActivitySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SummaryKind, SummaryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<double>?, List<double>, Uint8List>
  get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitySummariesTableOrderingComposer
    extends Composer<_$KangoosDatabase, $ActivitySummariesTable> {
  $$ActivitySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitySummariesTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $ActivitySummariesTable> {
  $$ActivitySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SummaryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<double>?, Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ActivitySummariesTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $ActivitySummariesTable,
          ActivitySummary,
          $$ActivitySummariesTableFilterComposer,
          $$ActivitySummariesTableOrderingComposer,
          $$ActivitySummariesTableAnnotationComposer,
          $$ActivitySummariesTableCreateCompanionBuilder,
          $$ActivitySummariesTableUpdateCompanionBuilder,
          (
            ActivitySummary,
            BaseReferences<
              _$KangoosDatabase,
              $ActivitySummariesTable,
              ActivitySummary
            >,
          ),
          ActivitySummary,
          PrefetchHooks Function()
        > {
  $$ActivitySummariesTableTableManager(
    _$KangoosDatabase db,
    $ActivitySummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ActivitySummariesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ActivitySummariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ActivitySummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<SummaryKind> kind = const Value.absent(),
                Value<DateTime> periodStart = const Value.absent(),
                Value<DateTime> periodEnd = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ActivitySummariesCompanion(
                id: id,
                kind: kind,
                periodStart: periodStart,
                periodEnd: periodEnd,
                content: content,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required SummaryKind kind,
                required DateTime periodStart,
                required DateTime periodEnd,
                required String content,
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ActivitySummariesCompanion.insert(
                id: id,
                kind: kind,
                periodStart: periodStart,
                periodEnd: periodEnd,
                content: content,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitySummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $ActivitySummariesTable,
      ActivitySummary,
      $$ActivitySummariesTableFilterComposer,
      $$ActivitySummariesTableOrderingComposer,
      $$ActivitySummariesTableAnnotationComposer,
      $$ActivitySummariesTableCreateCompanionBuilder,
      $$ActivitySummariesTableUpdateCompanionBuilder,
      (
        ActivitySummary,
        BaseReferences<
          _$KangoosDatabase,
          $ActivitySummariesTable,
          ActivitySummary
        >,
      ),
      ActivitySummary,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$KangoosDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$KangoosDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<
              _$KangoosDatabase,
              $ConversationsTable,
              Conversation
            >,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(
    _$KangoosDatabase db,
    $ConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$KangoosDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$ConversationMessagesTableCreateCompanionBuilder =
    ConversationMessagesCompanion Function({
      Value<int> id,
      required int conversationId,
      required LlmRole role,
      required String content,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });
typedef $$ConversationMessagesTableUpdateCompanionBuilder =
    ConversationMessagesCompanion Function({
      Value<int> id,
      Value<int> conversationId,
      Value<LlmRole> role,
      Value<String> content,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });

class $$ConversationMessagesTableFilterComposer
    extends Composer<_$KangoosDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LlmRole, LlmRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<double>?, List<double>, Uint8List>
  get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationMessagesTableOrderingComposer
    extends Composer<_$KangoosDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationMessagesTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<LlmRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<double>?, Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ConversationMessagesTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $ConversationMessagesTable,
          ConversationMessage,
          $$ConversationMessagesTableFilterComposer,
          $$ConversationMessagesTableOrderingComposer,
          $$ConversationMessagesTableAnnotationComposer,
          $$ConversationMessagesTableCreateCompanionBuilder,
          $$ConversationMessagesTableUpdateCompanionBuilder,
          (
            ConversationMessage,
            BaseReferences<
              _$KangoosDatabase,
              $ConversationMessagesTable,
              ConversationMessage
            >,
          ),
          ConversationMessage,
          PrefetchHooks Function()
        > {
  $$ConversationMessagesTableTableManager(
    _$KangoosDatabase db,
    $ConversationMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConversationMessagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ConversationMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ConversationMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> conversationId = const Value.absent(),
                Value<LlmRole> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ConversationMessagesCompanion(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int conversationId,
                required LlmRole role,
                required String content,
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ConversationMessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $ConversationMessagesTable,
      ConversationMessage,
      $$ConversationMessagesTableFilterComposer,
      $$ConversationMessagesTableOrderingComposer,
      $$ConversationMessagesTableAnnotationComposer,
      $$ConversationMessagesTableCreateCompanionBuilder,
      $$ConversationMessagesTableUpdateCompanionBuilder,
      (
        ConversationMessage,
        BaseReferences<
          _$KangoosDatabase,
          $ConversationMessagesTable,
          ConversationMessage
        >,
      ),
      ConversationMessage,
      PrefetchHooks Function()
    >;
typedef $$DeletedSnippetsTableCreateCompanionBuilder =
    DeletedSnippetsCompanion Function({
      required String syncId,
      Value<DateTime> deletedAt,
      Value<int> rowid,
    });
typedef $$DeletedSnippetsTableUpdateCompanionBuilder =
    DeletedSnippetsCompanion Function({
      Value<String> syncId,
      Value<DateTime> deletedAt,
      Value<int> rowid,
    });

class $$DeletedSnippetsTableFilterComposer
    extends Composer<_$KangoosDatabase, $DeletedSnippetsTable> {
  $$DeletedSnippetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeletedSnippetsTableOrderingComposer
    extends Composer<_$KangoosDatabase, $DeletedSnippetsTable> {
  $$DeletedSnippetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeletedSnippetsTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $DeletedSnippetsTable> {
  $$DeletedSnippetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DeletedSnippetsTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $DeletedSnippetsTable,
          DeletedSnippet,
          $$DeletedSnippetsTableFilterComposer,
          $$DeletedSnippetsTableOrderingComposer,
          $$DeletedSnippetsTableAnnotationComposer,
          $$DeletedSnippetsTableCreateCompanionBuilder,
          $$DeletedSnippetsTableUpdateCompanionBuilder,
          (
            DeletedSnippet,
            BaseReferences<
              _$KangoosDatabase,
              $DeletedSnippetsTable,
              DeletedSnippet
            >,
          ),
          DeletedSnippet,
          PrefetchHooks Function()
        > {
  $$DeletedSnippetsTableTableManager(
    _$KangoosDatabase db,
    $DeletedSnippetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$DeletedSnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DeletedSnippetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DeletedSnippetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletedSnippetsCompanion(
                syncId: syncId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                Value<DateTime> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletedSnippetsCompanion.insert(
                syncId: syncId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeletedSnippetsTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $DeletedSnippetsTable,
      DeletedSnippet,
      $$DeletedSnippetsTableFilterComposer,
      $$DeletedSnippetsTableOrderingComposer,
      $$DeletedSnippetsTableAnnotationComposer,
      $$DeletedSnippetsTableCreateCompanionBuilder,
      $$DeletedSnippetsTableUpdateCompanionBuilder,
      (
        DeletedSnippet,
        BaseReferences<
          _$KangoosDatabase,
          $DeletedSnippetsTable,
          DeletedSnippet
        >,
      ),
      DeletedSnippet,
      PrefetchHooks Function()
    >;
typedef $$MemoryEpisodesTableCreateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      Value<int> id,
      required String sourceKey,
      required DateTime startedAt,
      required DateTime endedAt,
      required String title,
      required String summary,
      Value<List<String>> applications,
      Value<List<String>> urls,
      Value<List<String>> topics,
      Value<List<String>> entities,
      Value<int> formationVersion,
      Value<String> contentHash,
      Value<MemoryFormationStatus> formationStatus,
      Value<double> confidence,
      Value<List<String>> decisions,
      Value<List<String>> actionItems,
      Value<List<String>> technologies,
      Value<String?> formationModelId,
      Value<List<int>> sourceActivityIds,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });
typedef $$MemoryEpisodesTableUpdateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      Value<int> id,
      Value<String> sourceKey,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<String> title,
      Value<String> summary,
      Value<List<String>> applications,
      Value<List<String>> urls,
      Value<List<String>> topics,
      Value<List<String>> entities,
      Value<int> formationVersion,
      Value<String> contentHash,
      Value<MemoryFormationStatus> formationStatus,
      Value<double> confidence,
      Value<List<String>> decisions,
      Value<List<String>> actionItems,
      Value<List<String>> technologies,
      Value<String?> formationModelId,
      Value<List<int>> sourceActivityIds,
      Value<List<double>?> embedding,
      Value<String?> embeddingProviderId,
      Value<DateTime> createdAt,
    });

class $$MemoryEpisodesTableFilterComposer
    extends Composer<_$KangoosDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get applications => $composableBuilder(
    column: $table.applications,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get urls =>
      $composableBuilder(
        column: $table.urls,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get topics => $composableBuilder(
    column: $table.topics,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get entities => $composableBuilder(
    column: $table.entities,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get formationVersion => $composableBuilder(
    column: $table.formationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    MemoryFormationStatus,
    MemoryFormationStatus,
    String
  >
  get formationStatus => $composableBuilder(
    column: $table.formationStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get decisions => $composableBuilder(
    column: $table.decisions,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get actionItems => $composableBuilder(
    column: $table.actionItems,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get technologies => $composableBuilder(
    column: $table.technologies,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get formationModelId => $composableBuilder(
    column: $table.formationModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String>
  get sourceActivityIds => $composableBuilder(
    column: $table.sourceActivityIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<double>?, List<double>, Uint8List>
  get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryEpisodesTableOrderingComposer
    extends Composer<_$KangoosDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get applications => $composableBuilder(
    column: $table.applications,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urls => $composableBuilder(
    column: $table.urls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topics => $composableBuilder(
    column: $table.topics,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entities => $composableBuilder(
    column: $table.entities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formationVersion => $composableBuilder(
    column: $table.formationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formationStatus => $composableBuilder(
    column: $table.formationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decisions => $composableBuilder(
    column: $table.decisions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionItems => $composableBuilder(
    column: $table.actionItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get technologies => $composableBuilder(
    column: $table.technologies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formationModelId => $composableBuilder(
    column: $table.formationModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceActivityIds => $composableBuilder(
    column: $table.sourceActivityIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryEpisodesTableAnnotationComposer
    extends Composer<_$KangoosDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get applications =>
      $composableBuilder(
        column: $table.applications,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get urls =>
      $composableBuilder(column: $table.urls, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get topics =>
      $composableBuilder(column: $table.topics, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get entities =>
      $composableBuilder(column: $table.entities, builder: (column) => column);

  GeneratedColumn<int> get formationVersion => $composableBuilder(
    column: $table.formationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MemoryFormationStatus, String>
  get formationStatus => $composableBuilder(
    column: $table.formationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get decisions =>
      $composableBuilder(column: $table.decisions, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get actionItems =>
      $composableBuilder(
        column: $table.actionItems,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get technologies =>
      $composableBuilder(
        column: $table.technologies,
        builder: (column) => column,
      );

  GeneratedColumn<String> get formationModelId => $composableBuilder(
    column: $table.formationModelId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<int>, String> get sourceActivityIds =>
      $composableBuilder(
        column: $table.sourceActivityIds,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<double>?, Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingProviderId => $composableBuilder(
    column: $table.embeddingProviderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MemoryEpisodesTableTableManager
    extends
        RootTableManager<
          _$KangoosDatabase,
          $MemoryEpisodesTable,
          MemoryEpisode,
          $$MemoryEpisodesTableFilterComposer,
          $$MemoryEpisodesTableOrderingComposer,
          $$MemoryEpisodesTableAnnotationComposer,
          $$MemoryEpisodesTableCreateCompanionBuilder,
          $$MemoryEpisodesTableUpdateCompanionBuilder,
          (
            MemoryEpisode,
            BaseReferences<
              _$KangoosDatabase,
              $MemoryEpisodesTable,
              MemoryEpisode
            >,
          ),
          MemoryEpisode,
          PrefetchHooks Function()
        > {
  $$MemoryEpisodesTableTableManager(
    _$KangoosDatabase db,
    $MemoryEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MemoryEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$MemoryEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$MemoryEpisodesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<List<String>> applications = const Value.absent(),
                Value<List<String>> urls = const Value.absent(),
                Value<List<String>> topics = const Value.absent(),
                Value<List<String>> entities = const Value.absent(),
                Value<int> formationVersion = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<MemoryFormationStatus> formationStatus =
                    const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> decisions = const Value.absent(),
                Value<List<String>> actionItems = const Value.absent(),
                Value<List<String>> technologies = const Value.absent(),
                Value<String?> formationModelId = const Value.absent(),
                Value<List<int>> sourceActivityIds = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MemoryEpisodesCompanion(
                id: id,
                sourceKey: sourceKey,
                startedAt: startedAt,
                endedAt: endedAt,
                title: title,
                summary: summary,
                applications: applications,
                urls: urls,
                topics: topics,
                entities: entities,
                formationVersion: formationVersion,
                contentHash: contentHash,
                formationStatus: formationStatus,
                confidence: confidence,
                decisions: decisions,
                actionItems: actionItems,
                technologies: technologies,
                formationModelId: formationModelId,
                sourceActivityIds: sourceActivityIds,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceKey,
                required DateTime startedAt,
                required DateTime endedAt,
                required String title,
                required String summary,
                Value<List<String>> applications = const Value.absent(),
                Value<List<String>> urls = const Value.absent(),
                Value<List<String>> topics = const Value.absent(),
                Value<List<String>> entities = const Value.absent(),
                Value<int> formationVersion = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<MemoryFormationStatus> formationStatus =
                    const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> decisions = const Value.absent(),
                Value<List<String>> actionItems = const Value.absent(),
                Value<List<String>> technologies = const Value.absent(),
                Value<String?> formationModelId = const Value.absent(),
                Value<List<int>> sourceActivityIds = const Value.absent(),
                Value<List<double>?> embedding = const Value.absent(),
                Value<String?> embeddingProviderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MemoryEpisodesCompanion.insert(
                id: id,
                sourceKey: sourceKey,
                startedAt: startedAt,
                endedAt: endedAt,
                title: title,
                summary: summary,
                applications: applications,
                urls: urls,
                topics: topics,
                entities: entities,
                formationVersion: formationVersion,
                contentHash: contentHash,
                formationStatus: formationStatus,
                confidence: confidence,
                decisions: decisions,
                actionItems: actionItems,
                technologies: technologies,
                formationModelId: formationModelId,
                sourceActivityIds: sourceActivityIds,
                embedding: embedding,
                embeddingProviderId: embeddingProviderId,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$KangoosDatabase,
      $MemoryEpisodesTable,
      MemoryEpisode,
      $$MemoryEpisodesTableFilterComposer,
      $$MemoryEpisodesTableOrderingComposer,
      $$MemoryEpisodesTableAnnotationComposer,
      $$MemoryEpisodesTableCreateCompanionBuilder,
      $$MemoryEpisodesTableUpdateCompanionBuilder,
      (
        MemoryEpisode,
        BaseReferences<_$KangoosDatabase, $MemoryEpisodesTable, MemoryEpisode>,
      ),
      MemoryEpisode,
      PrefetchHooks Function()
    >;

class $KangoosDatabaseManager {
  final _$KangoosDatabase _db;
  $KangoosDatabaseManager(this._db);
  $$SnippetsTableTableManager get snippets =>
      $$SnippetsTableTableManager(_db, _db.snippets);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$ActivitySummariesTableTableManager get activitySummaries =>
      $$ActivitySummariesTableTableManager(_db, _db.activitySummaries);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ConversationMessagesTableTableManager get conversationMessages =>
      $$ConversationMessagesTableTableManager(_db, _db.conversationMessages);
  $$DeletedSnippetsTableTableManager get deletedSnippets =>
      $$DeletedSnippetsTableTableManager(_db, _db.deletedSnippets);
  $$MemoryEpisodesTableTableManager get memoryEpisodes =>
      $$MemoryEpisodesTableTableManager(_db, _db.memoryEpisodes);
}
