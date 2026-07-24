# KangoOS

Open source alternative to [Pieces OS](https://pieces.app/): a snippet manager with contextual chat (RAG), self-hosted, 100% user-owned data.

## Why

- **Self-hosted**: runs locally by default; optional self-hosted server (Docker) for multi-device sync.
- **Local-first LLM**: [Ollama](https://ollama.com/) by default, with optional fallback to OpenAI/Anthropic/Gemini via user-supplied API key.
- **AGPL-3.0 licensed**: free to use and modify, including as a service, as long as modified source stays available.

## Repository structure

```
KangoOS/
├── app/    # Flutter desktop app (Windows/Linux/macOS)
└── core/   # KangoOS Core — pure Dart package (snippets, search, storage, LLM adapter)
```

`app` depends on `core` via a path dependency (`../core`). The same `core` runs embedded in the app (standalone mode) or exposed over HTTP (future self-hosted mode).

## MVP scope

- Snippet CRUD with automatic tagging (via LLM)
- Full-text + semantic search (local embeddings)
- Contextual chat over saved snippets (RAG)
- LLM provider configuration (local Ollama or third-party API key)

Out of MVP scope (future roadmap): automatic context capture (timeline/LTM), VS Code extension, browser extension, mobile app, plugin system.

## Stack

- **UI**: Flutter (desktop)
- **Core**: pure Dart
- **Storage**: [drift](https://drift.simonbinder.eu/) (type-safe SQLite, native FTS)

## Development

```bash
cd core && dart pub get
cd ../app && flutter pub get && flutter run -d windows
```

## License

[AGPL-3.0](LICENSE)
