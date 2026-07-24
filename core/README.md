# kangoos_core

Pure Dart core engine for [KangoOS](../README.md): snippet storage (drift/SQLite), search and LLM adapter. Consumed by the `app` package via a path dependency.

## Usage

```dart
import 'package:kangoos_core/kangoos_core.dart';
import 'package:drift/drift.dart';

final db = KangoosDatabase.memory(); // or KangoosDatabase.native(File(path))

final id = await db.createSnippet(SnippetsCompanion.insert(
  title: 'Reverse a string',
  content: 'input.split("").reversed.join()',
  language: const Value('dart'),
  tags: const Value(['string', 'algorithm']),
));

final snippet = await db.getSnippetById(id);
```

## LLM providers

Common `LlmProvider` interface (`chat(List<LlmMessage>) -> Stream<String>`) with three implementations:

```dart
import 'package:kangoos_core/kangoos_core.dart';

final ollama = OllamaProvider(model: 'llama3'); // local, no API key
final anthropic = AnthropicProvider(apiKey: key, model: 'claude-opus-4-8');
final openAi = OpenAiProvider(apiKey: key, model: 'gpt-4o');

await for (final chunk in ollama.chat([
  LlmMessage(role: LlmRole.user, content: 'Explain this snippet'),
])) {
  stdout.write(chunk);
}
```

Gemini is not implemented yet — add when needed.
