import 'dart:io';

import '../database/database.dart';
import '../snippets/snippet_repository.dart';
import '../snippets/snippet_service.dart';

const _usage = '''
Usage: kango <command> [options]

Commands:
  create --title <title> [--language <lang>] [--tags a,b,c]   Create a snippet; content is read from stdin.
  search <query> [--semantic] [--limit <n>]                    Search snippets (keyword by default).
  list [--limit <n>]                                           List recent snippets.
  show <id>                                                    Print a snippet in full.
  edit <id> [--title T] [--content C] [--language L] [--tags a,b]   Update a snippet's fields (--tags "" clears them).
  delete <id>                                                  Delete a snippet.

Env:
  KANGOOS_DB_PATH   Database file to use (defaults to a KangoOS-managed path; see --help output).
''';

Future<int> runKangoCli(
  List<String> arguments, {
  required SnippetService snippets,
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

  final flagWithoutValue = _flagWithoutValue(flags);
  if (flagWithoutValue != null) {
    errorOutput.writeln('Error: --$flagWithoutValue needs a value, '
        'e.g. `--$flagWithoutValue <value>`.');
    return 64;
  }

  switch (arguments.first) {
    case 'create':
      return _create(snippets, flags, readIn, output, errorOutput);
    case 'search':
      return _search(snippets, positionals, flags, output, errorOutput);
    case 'list':
      return _list(snippets, flags, output);
    case 'show':
      return _show(snippets, positionals, output, errorOutput);
    case 'edit':
      return _edit(snippets, positionals, flags, output, errorOutput);
    case 'delete':
      return _delete(snippets, positionals, output, errorOutput);
    default:
      errorOutput.write('Unknown command: ${arguments.first}\n\n$_usage');
      return 64;
  }
}

Future<int> _create(
  SnippetService snippets,
  Map<String, String?> flags,
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

  final result = await snippets.create(NewSnippet(
    title: title,
    content: content,
    language: language == null || language.isEmpty ? null : language,
    tags: tags,
  ));
  out.writeln('Created snippet #${result.snippet.id}: $title');
  if (result.indexingError != null) {
    err.writeln('Warning: snippet saved but indexing failed: '
        '${result.indexingError}');
  }
  return 0;
}

Future<int> _search(
  SnippetService snippets,
  List<String> positionals,
  Map<String, String?> flags,
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

  final List<Snippet> results;
  try {
    results = await snippets.search(
      query,
      mode: flags.containsKey('semantic')
          ? SnippetSearchMode.semantic
          : SnippetSearchMode.keyword,
      limit: limit,
    );
  } catch (error) {
    err.writeln('Search failed: $error');
    return 1;
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
    SnippetService snippets, Map<String, String?> flags, StringSink out) async {
  final limit = int.tryParse(flags['limit'] ?? '') ?? 20;
  final results = await snippets.list(limit: limit);

  if (results.isEmpty) {
    out.writeln('No snippets yet.');
    return 0;
  }
  for (final snippet in results) {
    out.writeln(_summaryLine(snippet));
  }
  return 0;
}

Future<int> _show(
  SnippetService snippets,
  List<String> positionals,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final snippet = await snippets.get(id);
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
  SnippetService snippets,
  List<String> positionals,
  Map<String, String?> flags,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final existing = await snippets.get(id);
  if (existing == null) {
    err.writeln('Error: snippet #$id not found.');
    return 1;
  }

  final result = await snippets.update(
      id,
      SnippetUpdate(
        title: flags['title'] ?? existing.title,
        content: flags['content'] ?? existing.content,
        language: flags.containsKey('language')
            ? (flags['language']!.isEmpty ? null : flags['language'])
            : existing.language,
        languageProvided: flags.containsKey('language'),
        tags: flags.containsKey('tags')
            ? _parseTags(flags['tags'])
            : existing.tags,
        updatedAt: DateTime.now(),
      ));
  if (result?.indexingError != null) {
    err.writeln('Warning: snippet updated but indexing failed: '
        '${result!.indexingError}');
  }
  out.writeln('Updated snippet #$id.');
  return 0;
}

Future<int> _delete(
  SnippetService snippets,
  List<String> positionals,
  StringSink out,
  StringSink err,
) async {
  final id = _requireId(positionals, err);
  if (id == null) return 64;

  final deleted = await snippets.delete(id);
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

const _flagsThatTakeAValue = {
  'title',
  'content',
  'language',
  'tags',
  'limit',
};

String? _flagWithoutValue(Map<String, String?> flags) {
  for (final entry in flags.entries) {
    if (_flagsThatTakeAValue.contains(entry.key) && entry.value == null) {
      return entry.key;
    }
  }
  return null;
}

Map<String, String?> _parseFlags(List<String> args) {
  final flags = <String, String?>{};
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
    flags[name] = hasValue ? args[++i] : null;
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
