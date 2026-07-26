import 'database.dart';

Map<String, dynamic> snippetToJson(Snippet snippet) => {
      'id': snippet.id,
      'title': snippet.title,
      'content': snippet.content,
      'language': snippet.language,
      'tags': snippet.tags,
      'syncId': snippet.syncId,
      'indexed': snippet.embedding != null,
      'createdAt': snippet.createdAt.millisecondsSinceEpoch,
      'updatedAt': snippet.updatedAt.millisecondsSinceEpoch,
    };
