<div align="center">

# KangoOS

**An open source, self-hosted alternative to [Pieces OS](https://pieces.app/).**

A developer snippet manager with long-term memory and contextual LLM chat — running locally, on your own machine, over data you own.

[![CI](https://github.com/tiagolauer/KangoOS/actions/workflows/ci.yml/badge.svg)](https://github.com/tiagolauer/KangoOS/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Release](https://img.shields.io/badge/release-1.1.0-brightgreen.svg)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Windows-informational.svg)](#platform-support)
[![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter%20%2B%20Dart-02569B.svg)](https://flutter.dev)

</div>

---

## Table of contents

- [Overview](#overview)
- [Feature highlights](#feature-highlights)
- [Platform support](#platform-support)
- [Getting started](#getting-started)
- [Architecture](#architecture)
- [Long-term memory and capture](#long-term-memory-and-capture)
- [Privacy and security](#privacy-and-security)
- [Command-line interface](#command-line-interface)
- [MCP server](#mcp-server)
- [Self-hosted server](#self-hosted-server)
- [Performance](#performance)
- [Development](#development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

KangoOS stores the code you keep re-writing, remembers what you were working on, and answers questions about both — without sending anything to a vendor you have to trust.

| Principle | What it means in practice |
|---|---|
| **Local first** | The desktop app runs standalone. No account, no telemetry, no cloud dependency. |
| **Local LLM by default** | [Ollama](https://ollama.com/) out of the box; Anthropic, OpenAI and Gemini are opt-in with your own API key. |
| **You own the data** | SQLite on your disk, encrypted at rest, exportable to plain JSON at any time. |
| **Optional self-hosting** | A Docker server you control, for multi-device sync and scripted access — never a requirement. |
| **Free software** | AGPL-3.0. Use it, modify it, run it as a service — as long as your modifications stay open. |

## Feature highlights

### Snippets

- Create, edit and delete snippets with automatic tagging by an LLM.
- **Full-text search** — SQLite FTS5, bm25-ranked, prefix matching and implicit AND.
- **Semantic search** — local embeddings with brute-force cosine similarity over packed `float32` blobs ([why no ANN index](#performance)).
- **Contextual chat (RAG)** grounded in your saved snippets, with browsable, persisted chat history.
- **Export / import** — plain JSON (title, content, language, tags, timestamps, sync id), de-duplicated on import by sync id, or by title + content when no sync id is present. Embeddings are re-indexed locally rather than exported.

### Long-term memory

- **Activity capture** — foreground application and window title, with opt-in first-run consent, retention and purge policies, a per-application denylist, swipe-to-delete and clear-all.
- **Unified Timeline** — events, episodes, summaries, manual memories, conversations and DeepStudy reports in one searchable view, with favorites, source details and granular deletion.
- **Hybrid memory search** — FTS5, semantic similarity and shared filters for type, application, modality, period and project across Timeline and chat.
- **Agentic retrieval and DeepStudy** — bounded multi-source investigation over episodes, summaries, snippets and conversations, with evidence trails, coverage, confidence and missing-evidence markers.
- **Conversation workspace** — recent-activity suggestions, file/folder attachments, persistent memory filters, inspectable evidence, stop/retry and explicit Reflection/DeepStudy modes.
- Chat and MCP tools answer over structured episodes using plain-English time ranges in English and Portuguese.

### LLM providers

- Ollama (local, default), Anthropic, OpenAI and Gemini.
- A **Fast / Balanced / Extra Thinking** reasoning-mode picker, mapped to each provider's native mechanism. It only takes effect on reasoning-capable models.
- API keys are stored in the OS keychain — Windows Credential Manager, macOS Keychain, Linux Secret Service — never in plaintext on disk.

### Integrations

- **[`kango` CLI](#command-line-interface)** — snippet CRUD and search from the terminal, embedding the core engine directly. No server needed.
- **[`kango_mcp` MCP server](#mcp-server)** — exposes snippets and long-term memory as tools to Cursor, GitHub Copilot and Claude Desktop.
- **[Self-hosted HTTP server](#self-hosted-server)** — the same engine behind a REST API, with bearer-token authentication.
- **Snippet sync** — manual, one button, between the app and your server.

### Interface

- English and Brazilian Portuguese, following the OS language and falling back to English. Dates and weekday/month names are locale-aware, and summary prompts are localized so the assistant answers in the language of the UI.
- Capture status, timed pause, LTM settings and granular deletion are available from both the main window and the Windows tray panel.
- Keyboard focus, semantic labels and explicit loading, empty, error and cancellation states cover the primary memory workflow.
- Translation files live in `app/lib/l10n/*.arb`. A test asserts the two files never drift apart: adding a key to `app_en.arb` without translating it fails the suite.

## Platform support

| Platform | Status | Notes |
|---|---|---|
| **Windows** | ✅ Supported | The only platform built, run and verified end to end. The CI `windows-build` job produces the released binary. |
| **Linux** | ⚠️ Experimental | Code is written for it, but it is not packaged, not CI-built and not verified. Requires `libayatana-appindicator3-dev`, `libssl-dev` and libsecret at build time, plus an X11 (or XWayland) session for activity capture. |
| **macOS** | ⚠️ Experimental | Code is written for it, but it is not packaged, not CI-built and not verified. Requires granting Accessibility permission so window titles can be read. |

Treat anything other than Windows as build-it-yourself until a later release.

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.29.3 (Dart 3.7.2). Standalone Dart CI jobs use 3.7.3.
- [Ollama](https://ollama.com/) running locally, if you want local inference and semantic search. Pull an embedding model with `ollama pull nomic-embed-text`.
- Windows: Visual Studio Build Tools with the **C++ ATL** component, and OpenSSL (`choco install openssl`). See [Development](#development) for the details.

### Run the desktop app

```bash
git clone https://github.com/tiagolauer/KangoOS.git
```

```bash
cd KangoOS/core && dart pub get
```

```bash
cd ../app && flutter pub get && flutter run -d windows
```

There is no account to create and no configuration required to start: the app opens an encrypted local database and works offline. Point it at a different LLM provider from Settings whenever you want.

## Architecture

```
KangoOS/
├── app/      Flutter desktop application (Windows, Linux, macOS)
├── core/     KangoOS Core — pure Dart: snippets, search, memory, storage, LLM and tool registry
├── mcp/      Official Dart MCP stdio adapter
└── server/   Self-hosted HTTP server (Shelf) — exposes core over the network
```

`app`, `mcp` and `server` depend on `core` through a path dependency (`../core`). The core is a modular monolith: UI, HTTP, CLI and MCP adapters call application services; repositories isolate drift/SQLite; sync transport is separate from reconciliation. The desktop app is the composition root and no UI widget queries drift directly.

| Layer | Technology |
|---|---|
| Desktop UI | Flutter (desktop) |
| Core engine | Pure Dart |
| Server | [Shelf](https://pub.dev/packages/shelf), Docker |
| Storage | [drift](https://drift.simonbinder.eu/) — type-safe SQLite with native FTS5 |
| Encryption at rest | SQLCipher via `sqlcipher_flutter_libs` |
| Secrets | `flutter_secure_storage` (OS keychain) |

### Sync model

Snippet sync is manual and explicit — one button, keyed by a client-generated `syncId`, with last-write-wins on `updatedAt` when both sides changed.

Deletions propagate in both directions through tombstones: deleting on one device deletes on the other, while an edit strictly newer than the deletion resurrects the snippet. On an exact timestamp tie the deletion wins — SQLite stores whole seconds, so ties are common. Tombstones are retained indefinitely, so a device that syncs late still learns about the deletion.

**Only snippets sync.** Captured activity, summaries and chat history are deliberately device-local.

## Long-term memory and capture

Every capture source below is **opt-in and off by default**, gated behind a first-run consent prompt, and subject to the retention and purge settings.

| Source | Platforms | What it records |
|---|---|---|
| Foreground activity | Windows, Linux, macOS | Application name and window title. |
| Browser URL | Windows, Linux, macOS | The active tab's URL for Chrome, Edge, Brave and Safari. |
| Focused visible text | Windows | Text of the focused UI element, via UI Automation. |
| Clipboard | Windows | Clipboard contents as they change. |
| Screen OCR | Windows | Text from the entire screen, on each focus change. |
| Microphone transcription | Windows | Speech transcribed on-device; audio is deleted immediately. |

### Browser URL capture

Reliability varies significantly by platform:

- **macOS** — AppleScript. Reliable; browsers expose the URL directly.
- **Windows** — UI Automation reading the address bar. Best-effort heuristic.
- **Linux** — AT-SPI/D-Bus tree walk. Best-effort, requires an AT-SPI-enabled desktop session; Firefox is untested and this is the lowest-confidence of the three.

### Microphone transcription (Windows)

Every 10 minutes the app records a 30-second clip from the default input device and transcribes it locally with [whisper.cpp](https://github.com/ggml-org/whisper.cpp). The audio never leaves the machine and the clip is deleted immediately after transcription — only the text is stored, alongside the focused window, and indexed for full-text search.

The native recorder applies voice activity detection before transcription. Timestamped transcripts are grouped by inactivity into session memories, and known conferencing applications mark meeting sessions. System-audio capture and speaker separation are not performed.

A one-time ~140 MB speech-model download (`ggml-base`) is required and must be triggered explicitly from capture settings; the toggle stays disabled until the model is present. whisper.cpp is fetched and compiled by CMake during the Windows build from a pinned commit, adding roughly 30 seconds to a clean build — no prebuilt binaries are vendored.

> [!WARNING]
> **Recording captures whoever is speaking — including other people in the room or on a call, who have not agreed to it.** Whether that is lawful depends on where you are; some jurisdictions require every party to consent. Check before enabling.

### Screen OCR (Windows)

Each time the focused window changes, a bundled `screen_ocr.exe` helper captures the virtual screen and runs Windows' built-in OCR engine (`Windows.Media.Ocr` — local, no cloud, no additional downloads). The text is stored alongside the activity entry and indexed for full-text search.

> [!CAUTION]
> **This is the most invasive capture source in KangoOS, and it is not comparable to the others.** It reads the *entire screen*, so it records things you never focused and never opened: another person's messages in a shared call, a document a colleague put on screen, notifications that happen to pop up. The excluded-apps list does **not** protect you here — that list filters by foreground process, while OCR reads every pixel regardless of which window owns it. Leave it off unless you have thought about what is on your screen, and prefer a short retention window if you enable it.

## Privacy and security

- **No account, no telemetry.** Nothing is transmitted unless you configure a remote LLM provider or a sync server. Automatic remote activity summaries require a separate explicit opt-in; loopback Ollama remains local by default.
- **Privacy filtering before persistence.** Common credentials and tokens are redacted before captured activity is written to storage.
- **Encryption at rest.** The desktop database is SQLCipher-encrypted with a random key held in the OS keychain. CLI, MCP and server can open an encrypted database when given the same path and key through the environment.
- **Secrets in the keychain.** LLM API keys and the database key use the same OS-native mechanism, never plaintext on disk.
- **The self-hosted server has no TLS of its own.** It binds `0.0.0.0` and sends the bearer token and every snippet body in cleartext, so anything beyond `localhost` belongs behind a TLS-terminating reverse proxy (Caddy, nginx, Traefik) or inside a private tunnel (Tailscale, WireGuard). The app warns before syncing to a plain `http://` host that is not local.

> [!IMPORTANT]
> Because the database key lives in the OS keychain rather than in the database file, **wiping the keychain entry — or moving the `.db` to another machine — makes the data unrecoverable.** Export your snippets first (More menu → Export snippets) if that is a risk. Note that export covers snippets only; captured activity and chat history are not included.

## Command-line interface

`kango` embeds the core engine directly — no server, no running app.

```bash
cd core
```

```bash
echo "input.split('').reversed.join()" | dart run bin/kango.dart create --title "Reverse a string" --language dart --tags strings,dart
```

```bash
dart run bin/kango.dart search reverse
```

```bash
dart run bin/kango.dart list
```

```bash
dart run bin/kango.dart show 1
```

```bash
dart run bin/kango.dart edit 1 --title "New title"
```

```bash
dart run bin/kango.dart delete 1
```

By default the CLI uses its own database file (`KangoOS/kangoos.db` in the OS app-data folder). To share the desktop database, set its exact path and provide the SQLCipher key directly or through a protected key file. Do not put real keys in shell history or source control.

| Variable | Purpose |
|---|---|
| `KANGOOS_DB_PATH` | SQLite file to use. |
| `KANGOOS_DB_KEY` | SQLCipher key for an encrypted database. |
| `KANGOOS_DB_KEY_FILE` | File containing the SQLCipher key; preferred over an inline value. |
| `KANGOOS_OLLAMA_BASE_URL` | Ollama endpoint for embeddings (default `http://localhost:11434`). |
| `KANGOOS_EMBEDDING_MODEL` | Embedding model (default `nomic-embed-text`). |

`--semantic` search behaves exactly as it does in the app. There is no `kango chat` yet: LLM settings live in the app's local preferences, which a plain Dart binary cannot read. Environment variables, as the server uses, would be the natural path.

## MCP server

```bash
cd mcp && dart run bin/kangoos_mcp.dart
```

The primary MCP entrypoint uses the official `dart_mcp` SDK and Dart 3.7. Point Cursor, Claude Desktop or GitHub Copilot's MCP configuration at `dart run <path-to-repository>/mcp/bin/kangoos_mcp.dart`, using the same environment variables as the CLI.

Plain Dart binaries on Linux require `libsqlite3-dev` so the native SQLite library is discoverable.

| Tool | Purpose |
|---|---|
| `search_snippets` | Keyword or semantic search. |
| `list_snippets` | List stored snippets. |
| `get_snippet` | Fetch one snippet by id. |
| `create_snippet` | Store a new snippet. |
| `update_snippet` | Edit an existing snippet. |
| `delete_snippet` | Remove a snippet. |
| `ask_kango_ltm` | Query long-term memory over a time range. |
| `create_kango_memory` | Write an entry into long-term memory. |
| `search_memories` | Hybrid memory search. |
| `search_memories_semantic` | Semantic episode search. |
| `search_memories_by_time` | Search episodes inside a parsed time range. |
| `get_memory_episode` | Fetch one structured episode. |
| `list_recent_memories` | List recent episodes. |
| `find_related_memories` | Find episodes related to another episode. |
| `investigate_memory` | Retrieve across memory sources and reflect on evidence quality. |
| `deep_study` | Build a cross-referenced report with an evidence trail. |
| `search_entities` / `search_projects` | Search extracted entity and project references. |
| `forget_memory` | Delete a memory episode. |
| `get_daily_summary` / `get_weekly_summary` | Read stored summaries. |
| `remember` | Alias for manually storing a memory. |

The repository is pinned to Flutter 3.29.3 (Dart 3.7.2), while standalone Dart jobs use 3.7.3. The legacy `core/bin/kango_mcp.dart` tools-only transport remains available, and both entrypoints share the same tool registry and composition root.

## Self-hosted server

The Docker server exposes the same snippet storage, semantic search and RAG chat over a REST API, for multi-device sync, scripts, or as the backend for a future client.

```bash
KANGOOS_API_TOKEN=$(openssl rand -hex 32) docker compose up --build
```

`KANGOOS_API_TOKEN` is required and must be at least 32 characters; the server refuses to start otherwise. Every request except `/health` must send it back as `Authorization: Bearer <token>`.

Full API reference, configuration table and curl examples: **[server/README.md](server/README.md)**.

## Performance

Semantic search uses the `VectorIndex` contract with a measured brute-force implementation, and embeddings are stored as packed `float32` blobs. Scoring reads only `(id, embedding)` and fetches full rows just for the top hits. Measured with `dart run tool/semantic_search_benchmark.dart` at 768 dimensions, per query:

| Snippets | Before | After |
|---:|---:|---:|
| 1,000 | 48 ms | **4 ms** |
| 10,000 | 573 ms | **40 ms** |
| 50,000 | 3,022 ms | **217 ms** |

An approximate-nearest-neighbour index was considered and rejected on these numbers. Even before the change, distance computation accounted for only ~3% of query time (17 ms of 573 ms at 10,000 snippets) — the real cost was loading and JSON-decoding every embedding, which an ANN index does not address. Worth revisiting above ~50,000 snippets, where in-memory vectors or an on-disk vector index would start to pay off.

## Development

```powershell
.\tool\verify.ps1
```

The command resolves dependencies, analyzes and tests `core`, `server`, `mcp` and `app`. Add `-BuildInstaller` on Windows to build the release bundle, verify an encrypted database upgrade against its SQLCipher library and compile the installer. See the [M0 verification baseline](docs/m0-verification-baseline.md).

CI runs `analyze` and `test` for `core`, `server`, `mcp` and `app` on Ubuntu, repeats the Dart suites on Windows, builds and smoke-tests the authenticated Docker server, and produces a real `flutter build windows --release` artifact.

### Native requirements

**`flutter_secure_storage` (OS keychain)**

| Platform | Requirement |
|---|---|
| Windows | The C++ ATL component of Visual Studio Build Tools — the same VS installation Flutter's Windows desktop support already requires. Verify "C++ ATL" is ticked. |
| macOS | The `keychain-access-groups` entitlement (already present in `app/macos/Runner/*.entitlements`). |
| Linux | libsecret at build and runtime (`sudo apt install libsecret-1-0 libsecret-1-dev`) plus a running keyring service such as `gnome-keyring` or `kwallet`. |

**SQLCipher (encryption at rest)**

| Platform | Requirement |
|---|---|
| Windows | OpenSSL at build time (`choco install openssl`, elevated). Statically linked into the generated DLL, so end users do not need it. |
| Linux | `libssl-dev` at build time (`sudo apt install libssl-dev`). Also statically linked. |
| macOS / iOS / Android | None — a precompiled SQLCipher build is used. |

### Known issue: OpenSSL discovery on Windows

If your installed CMake predates the modern Win64OpenSSL installer's `lib/VC/<arch>/<mode>/` directory layout, configuration fails with `Could NOT find OpenSSL ... OPENSSL_CRYPTO_LIBRARY`.

This affects the CMake 3.20 bundled with VS2019 Build Tools. VS2022's CMake is newer and may not need the workaround — but its CMake component is not installed by default, so a machine with VS2022 can still be running the VS2019 CMake.

`app/windows/CMakeLists.txt` looks for a compatibility directory at `app/windows/.openssl-compat/` and points `OPENSSL_ROOT_DIR` at it when present. The directory is gitignored and machine-specific — a partial copy of your real OpenSSL install. Regenerate it after installing OpenSSL:

```powershell
$dst = "app\windows\.openssl-compat"; New-Item -ItemType Directory -Force "$dst\lib\VC\static" | Out-Null; Copy-Item "C:\Program Files\OpenSSL-Win64\include\*" "$dst\include" -Recurse -Force; Copy-Item "C:\Program Files\OpenSSL-Win64\lib\VC\x64\MD\libcrypto_static.lib" "$dst\lib\VC\static\libcrypto_static.lib" -Force; Copy-Item "C:\Program Files\OpenSSL-Win64\lib\VC\x64\MD\libssl_static.lib" "$dst\lib\VC\static\libssl_static.lib" -Force
```

If your CMake understands the real install directly, skip this entirely: without `.openssl-compat/`, the `if(EXISTS ...)` guard in `CMakeLists.txt` never fires.

## Roadmap

Currently out of scope, in rough order of interest:

- Page content beyond the URL for browser capture
- VS Code extension and browser extension
- Mobile application
- Plugin system
- ANN/vector storage only after brute-force search exceeds its measured ceiling
- Syncing anything beyond snippets — activity, summaries and chat history stay device-local by design

## Contributing

Issues and pull requests are welcome. Before opening a PR:

1. Run `dart analyze` and `dart test` in `core` and `server`.
2. Run `flutter analyze` and `flutter test` in `app`.
3. Add any new UI string to both `app/lib/l10n/app_en.arb` and `app_pt.arb` — the localization drift test enforces this.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

[AGPL-3.0](LICENSE) — free to use and modify, including as a network service, provided modified source stays available.
