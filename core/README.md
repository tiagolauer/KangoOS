# kangoos_core

Pure Dart core engine for [KangoOS](../README.md): application services, repository contracts, drift/SQLite adapters, search, memory, sync and LLM adapters. Consumed by the desktop app and server through path dependencies.

## Usage

```dart
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

final db = KangoosDatabase.memory();
final repository = SqliteSnippetRepository(db);
final snippets = SnippetService(repository: repository);

final result = await snippets.create(const NewSnippet(
  title: 'Reverse a string',
  content: 'input.split("").reversed.join()',
  language: 'dart',
  tags: ['string', 'algorithm'],
));

final snippet = await snippets.get(result.snippet.id);
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

`GeminiProvider` is also implemented, same interface.

## Semantic search

`SemanticSearch` indexes snippets via an `EmbeddingProvider` and ranks by cosine similarity. Only `OllamaEmbeddingProvider` is implemented (Anthropic has no embeddings endpoint; OpenAI's is not wired up yet):

```dart
final search = SemanticSearch(
  repository: repository,
  embeddingProvider: OllamaEmbeddingProvider(model: 'nomic-embed-text'),
);
final snippets = SnippetService(
  repository: repository,
  semanticSearch: search,
);

final result = await snippets.create(const NewSnippet(
  title: 'Reverse a string',
  content: 'input.split("").reversed.join()',
));
final report = await snippets.indexPending();

final matches = await snippets.search(
  'reverse a string',
  mode: SnippetSearchMode.semantic,
);
```

Embeddings are packed `float32` blobs and carry a provider/model fingerprint. Changing the model makes old vectors pending instead of mixing incompatible embedding spaces. Mutation and backfill results surface per-item indexing failures.

## Snippet sync

`SnippetSyncClient` reconciles snippets against a [`kangoos_server`](../server) instance over HTTP — pushes local-only snippets, pulls remote-only ones, and resolves conflicts (present on both sides) by `updatedAt`, last write wins. Matching across devices is by a client-generated `syncId`, not the local autoincrement `id` (which is per-database and never portable) — a snippet without one gets assigned one on its first sync.

```dart
final client = SnippetSyncClient(
  engine: SnippetSyncEngine(
    repository: repository,
    snippets: snippets,
    transport: HttpSyncTransport(
      baseUrl: Uri.parse('http://localhost:8080'),
      apiToken: token,
    ),
  ),
);

final result = await client.sync(); // SyncResult(pushed, pulled, updated)
```

Snippets only — embeddings are excluded from the sync payload and re-indexed locally. Tombstones propagate deletions in both directions; a strictly newer edit resurrects a snippet, while deletion wins an exact timestamp tie.

## Long-term memory

Captured observations pass through `PrivacyFilter`, are persisted through `MemoryService`, and are grouped into deterministic inactivity-bounded episodes. Completed episodes are compacted into session, daily and weekly memories; explicit memories are durable. `MemoryQueryEngine` combines FTS5, semantic similarity and English/Portuguese temporal parsing, including fuzzy ranges and timezone offsets, without an external vector or graph database.

`MemoryAgent` performs bounded retrieval across episodes, summaries, snippets and conversations, reflects on evidence coverage and confidence, and expands weak searches without exposing hidden reasoning. `deepStudy` returns a Markdown evidence trail with cross-references and missing-evidence markers.

The Dart 3.7 `../mcp` package is the primary MCP entrypoint and uses the official `dart_mcp` SDK. The legacy `bin/kango_mcp.dart` tools-only transport remains available; both share the same tool registry and composition root.

`kangoos_core.dart` is the stable application API. Composition roots that construct SQLite adapters import `kangoos_core_storage.dart`; UI, HTTP, MCP and CLI code should otherwise stay on services and repository contracts.

## Database configuration

CLI, MCP and server resolve `KANGOOS_DB_PATH`, `KANGOOS_DB_KEY` and `KANGOOS_DB_KEY_FILE` through `DatabaseConfiguration`. A key file is preferred for encrypted shared storage because it avoids putting a key directly in process arguments or shell history.
