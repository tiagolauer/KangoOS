import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../search/semantic_search.dart';

const _usage = '''
Usage: kango <command> [options]

Commands:
  create --title <title> [--language <lang>] [--tags a,b,c]   Create a snippet; content is read from stdin.
  search <query> [--semantic] [--limit <n>]                    Search snippets (keyword by default).
  list [--limit <n>]                                           List recent snippets.
  show <id>                                                    Print a snippet in full.
  edit <id> [--title T] [--content C] [--language L] [--tags a,b]   Update a snippet's fields.
  delete <id>                                                  Delete a snippet.

Env:
  KANGOOS_DB_PATH   Database file to use (defaults to a KangoOS-managed path; see --help output).
''';

Future<int> runKangoCli(
  List<String> arguments, {
  required KangoosDatabase database,
  SemanticSearch? semanticSearch,
  StringSink? out,
  StringSink? err,
  String Function()? readStdin,
}) async {
  final output = out ?? stdout;
  final errorOutput = err ?? stderr;
  final readIn = readStdin ?? _readAllStdin;

  if (arguments.isEmpty ||
      arguments.first == 'help' ||
      arguments.first == '--help') {
    (arguments.isEmpty ? errorOutput : output).write(_usage);
    return arguments.isEmpty ? 64 : 0;
  }

  final rest = arguments.skip(1).toList();
  final flags = _parseFlags(rest);
  final positionals = _positionals(rest);

  switch (arguments.first) {
    case 'create':
      return _create(database, flags, readIn, output, errorOutput);
    case 'search':
      return _search(
          database, semanticSearch, positionals, flags, output, errorOutput);
    case 'list':
      return _list(database, flags, output);
    case 'show':
      return _show(database, positionals, output, errorOutput);
    case 'edit':
      return _edit(database, positionals, flags, output, errorOutput);
    case 'delete':
      return _delete(database, positionals, output, errorOutput);
    default:
      errorOutput.write('Unknown command: ${arguments.first}\n\n$_usage');
      return 64;
  }
}

Future<int> _create(
  KangoosDatabase database,
  Map<String, String> flags,
  String Function() readIn,
  StringSink out,
  StringSink err,
) async {
  final title = flags['title']?.trim() ?? '';
  if (title.isEmpty) {
    err.writeln('Error: --title is required.');
    return 64;
  }

  final content = readIn().trim();
  if (content.isEmpty) {
    err.writeln(
        'Error: no content on stdin. Pipe content in, e.g. `cat file.dart | kango create --title foo`.');
    return 64;
  }

  final tags = _parseTags(flags['tags']);
  final language = flags['language']?.trim();

  final id = await database.createSnippet(SnippetsCompanion.insert(
    title: title,
    content: content,
    language: Value(language == null || language.isEmpty ? null : language),
    tags: Value(tags),
  ));
  out.writeln('Created snippet #$id: $title');
  return 0;
}

Future<int> _search(
  KangoosDatabase database,
  SemanticSearch? semanticSearch,
  List<String> positionals,
  Map<String, String> flags,
  StringSink out,
  StringSink err,
) async {
  if (positionals.isEmpty) {
    err.writeln(
        'Error: search requires a query, e.g. `kango search "reverse a string"`.');
    return 64;
  }
  final query = positionals.join(' ');
  final limit = int.tryParse(flags['limit'] ?? '') ?? 10;

  List<Snippet> results;
  if (flags.containsKey('semantic')) {
    if (semanticSearch == null) {
      err.writeln('Error: semantic search is not available.');
      return 1;
    }
    try {
      final matches = await semanticSearch.search(query, limit: limit);
      results = matches.map((match) => match.snippet).toList();
    } catch (e) {
      err.writeln('Semantic search failed: $e');
      return 1;
    }
  } else {
    final matches = await database.searchByKeyword(query);
    results = matches.take(limit).toList();
  }

  if (results.isEmpty) {
    out.writeln('No snippets found.');
    return 0;
  }
  for (final snippet in results) {
    out.writeln(_summaryLine(snippet));
  }
  return 0;
}

Future<int> _list(
    KangoosDatabase database, Map<String, String> flags, StringSink out) async {
  final limit = int.tryParse(flags['limit'] ?? '') ?? 20;
  final snippets = (await database.watchAllSnippets().first).take(limit);

  if (snippets.isEmpty) {
    out.writeln('No snippets yet.');
    return 0;
  }
  for (final snippet in snippets) {
    out.writeln(_summaryLine(snippet));
  }
  return 0;
}

Future<int> _show(
  KangoosDatabase database,
  List<String> positionals,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final snippet = await database.getSnippetById(id);
  if (snippet == null) {
    err.writeln('Error: snippet #$id not found.');
    return 1;
  }

  out
    ..writeln('#${snippet.id}: ${snippet.title}')
    ..writeln('language: ${snippet.language ?? '(none)'}')
    ..writeln(
        'tags: ${snippet.tags.isEmpty ? '(none)' : snippet.tags.join(', ')}')
    ..writeln('updated: ${snippet.updatedAt.toLocal()}')
    ..writeln('---')
    ..writeln(snippet.content);
  return 0;
}

Future<int> _edit(
  KangoosDatabase database,
  List<String> positionals,
  Map<String, String> flags,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final existing = await database.getSnippetById(id);
  if (existing == null) {
    err.writeln('Error: snippet #$id not found.');
    return 1;
  }

  final updated = existing.copyWith(
    title: flags['title'] ?? existing.title,
    content: flags['content'] ?? existing.content,
    language: flags.containsKey('language')
        ? Value(flags['language']!.isEmpty ? null : flags['language'])
        : Value(existing.language),
    tags: flags.containsKey('tags') ? _parseTags(flags['tags']) : existing.tags,
    updatedAt: DateTime.now(),
  );
  await database.updateSnippet(updated);
  out.writeln('Updated snippet #$id.');
  return 0;
}

Future<int> _delete(
  KangoosDatabase database,
  List<String> positionals,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final deleted = await database.deleteSnippet(id);
  if (deleted == 0) {
    err.writeln('Error: snippet #$id not found.');
    return 1;
  }
  out.writeln('Deleted snippet #$id.');
  return 0;
}

int? _requireId(List<String> positionals, StringSink err) {
  if (positionals.isEmpty) {
    err.writeln('Error: an id is required.');
    return null;
  }
  final id = int.tryParse(positionals.first);
  if (id == null) {
    err.writeln('Error: "${positionals.first}" is not a valid id.');
    return null;
  }
  return id;
}

String _summaryLine(Snippet snippet) {
  final line = snippet.content.split('\n').first;
  final preview = line.length > 60 ? '${line.substring(0, 60)}…' : line;
  final tags = snippet.tags.isEmpty ? '' : ' [${snippet.tags.join(', ')}]';
  return '#${snippet.id}  ${snippet.title}$tags  $preview';
}

String _readAllStdin() {
  final buffer = StringBuffer();
  String? line;
  while ((line = stdin.readLineSync()) != null) {
    buffer.writeln(line);
  }
  return buffer.toString();
}

List<String> _parseTags(String? raw) => (raw ?? '')
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList();

Map<String, String> _parseFlags(List<String> args) {
  final flags = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final name = arg.substring(2);
    final eqIndex = name.indexOf('=');
    if (eqIndex != -1) {
      flags[name.substring(0, eqIndex)] = name.substring(eqIndex + 1);
      continue;
    }
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    flags[name] = hasValue ? args[++i] : 'true';
  }
  return flags;
}

List<String> _positionals(List<String> args) {
  final positionals = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      final hasValue = !arg.contains('=') &&
          i + 1 < args.length &&
          !args[i + 1].startsWith('--');
      if (hasValue) i++;
      continue;
    }
    positionals.add(arg);
  }
  return positionals;
}
