# KangoOS

Open source alternative to [Pieces OS](https://pieces.app/): a snippet manager with contextual chat (RAG), self-hosted, 100% user-owned data.

## Why

- **Self-hosted**: runs locally by default; optional self-hosted server (Docker) the app can sync snippets with for multi-device use.
- **Local-first LLM**: [Ollama](https://ollama.com/) by default, with optional fallback to OpenAI/Anthropic/Gemini via user-supplied API key.
- **AGPL-3.0 licensed**: free to use and modify, including as a service, as long as modified source stays available.

## Repository structure

```
KangoOS/
├── app/     # Flutter desktop app (Windows/Linux/macOS)
├── core/    # KangoOS Core — pure Dart package (snippets, search, storage, LLM adapter)
└── server/  # Self-hosted HTTP server (Shelf) — exposes core over the network, see server/README.md
```

`app` and `server` both depend on `core` via a path dependency (`../core`). The same `core` runs embedded in the app (standalone mode) or behind the HTTP server (self-hosted mode) — either way it's the same snippet storage, semantic search and RAG chat logic.

## MVP scope

- Snippet CRUD with automatic tagging (via LLM)
- Full-text search (real SQLite FTS5, bm25-ranked, prefix matching) + semantic search (local embeddings, brute-force cosine — fine at snippet-manager scale, no ANN index)
- Contextual chat over saved snippets (RAG)
- LLM provider configuration (local Ollama, or Anthropic/OpenAI/Gemini via API key, stored in the OS keychain — Credential Manager/Keychain/Secret Service, never plaintext on disk), with a reasoning-mode picker (Fast/Balanced/Extra Thinking) mapped to each provider's own mechanism — only takes effect on reasoning-capable models
- Encryption at rest for the desktop app's local database (SQLCipher), keyed by a random key stored in the OS keychain — same mechanism as the LLM API keys. The CLI/MCP/server databases are unaffected (plain SQLite) — separate stores, separate threat model.

- Self-hosted HTTP server (Docker) — same snippet storage/RAG chat as the app, reachable over its REST API (curl, scripts, or the app's own sync client)
- Snippet sync with the self-hosted server (manual, one button): pushes/pulls snippets keyed by a client-generated `syncId`, last-write-wins on `updatedAt` when both sides changed. Snippets only — captured activity, summaries and chat history stay device-local. Deleting a snippet on one side does not (yet) delete it on the other — sync only ever creates or updates, never deletes remotely.
- Activity capture (Windows/Linux/macOS, app + window title by default) with retention/purge
  - Linux requires an X11 session (or XWayland); macOS requires granting Accessibility permission to the app so "System Events" can read other apps' window titles
- Timeline: automatic activity summaries every 20 minutes, plus on-demand day recap (via LLM)
- Opt-in browser URL capture (off by default, real content — not just metadata): reads the active tab's URL for Chrome/Edge/Brave/Safari.
  - macOS: via AppleScript (reliable — browsers expose this directly).
  - Windows: via UI Automation reading the address bar (best-effort heuristic, unverified against a real browser at time of writing).
  - Linux: via AT-SPI/D-Bus tree walk (best-effort, needs an AT-SPI-enabled desktop session; Firefox untested, lowest-confidence of the three).
- CLI (`kango`, see below) for snippet create/search/list/show/edit/delete, embedding `core` directly — no server required.
- MCP server (`kango_mcp`, see below) so IDE assistants (Cursor, GitHub Copilot, Claude Desktop) can search/create/edit snippets as tools.

Out of scope for now (future roadmap): page content beyond the URL, VS Code extension, browser extension, mobile app, plugin system, delete propagation in snippet sync, syncing anything other than snippets (activity/summaries/chat are deliberately device-local).

## CLI

```bash
cd core
echo "input.split('').reversed.join()" | dart run bin/kango.dart create --title "Reverse a string" --language dart --tags strings,dart
dart run bin/kango.dart search reverse
dart run bin/kango.dart list
dart run bin/kango.dart show 1
dart run bin/kango.dart edit 1 --title "New title"
dart run bin/kango.dart delete 1
```

Uses its own database file by default (`KangoOS/kangoos.db` under the OS's app-data folder) — **not** the same file the desktop app uses, since replicating Flutter's `path_provider` folder resolution from a plain Dart binary would be fragile. Point `KANGOOS_DB_PATH` at the app's db file to share storage, or run `kango` standalone for a separate CLI-only snippet store. `--semantic` search and `KANGOOS_OLLAMA_BASE_URL`/`KANGOOS_EMBEDDING_MODEL` work the same way as the app. No `kango chat` yet (LLM settings live in the app's local prefs, not readable from a plain Dart binary) — could take env vars like the server does; not built here.

## MCP server

```bash
cd core
dart run bin/kango_mcp.dart
```

Speaks MCP over stdio: point Cursor/Claude Desktop/Copilot's MCP config at `dart run <path-to-core>/bin/kango_mcp.dart` (same `KANGOOS_DB_PATH`/`KANGOOS_OLLAMA_BASE_URL`/`KANGOOS_EMBEDDING_MODEL` env vars as the CLI). Exposes `search_snippets`, `create_snippet`, `list_snippets`, `get_snippet`, `update_snippet`, `delete_snippet` as tools — same shape as the CLI, just callable by an IDE assistant instead of a human.

This project pins Dart SDK `^3.6.1`; the official `package:dart_mcp` (labs.dart.dev) needs `>=3.7.0`, so the stdio JSON-RPC transport here is hand-rolled rather than pulled from that package — deliberately minimal (tools only, no resources/prompts/sampling). Swap in `package:dart_mcp` once the SDK floor moves to 3.7+.

## Stack

- **UI**: Flutter (desktop)
- **Core**: pure Dart
- **Server**: [Shelf](https://pub.dev/packages/shelf) (self-hosted, Docker)
- **Storage**: [drift](https://drift.simonbinder.eu/) (type-safe SQLite, native FTS)

## Development

```bash
cd core && dart pub get
cd ../app && flutter pub get && flutter run -d windows
```

API keys are stored via [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (OS keychain), which has its own native requirements per platform:
- **Windows**: needs the C++ ATL component of Visual Studio Build Tools (same VS install Flutter Windows desktop already requires — check the "C++ ATL" optional component is ticked).
- **macOS**: needs the `keychain-access-groups` entitlement (already added to `app/macos/Runner/*.entitlements`).
- **Linux**: needs libsecret at build and runtime (`sudo apt install libsecret-1-0 libsecret-1-dev` on Debian/Ubuntu) plus a running keyring service (`gnome-keyring`, `kwallet`, or similar — usually already present on a desktop session).

The app's database encryption (SQLCipher via `sqlcipher_flutter_libs`) has its own native build-time requirement:
- **Windows**: needs OpenSSL installed at build time (`choco install openssl` with Chocolatey, elevated) — statically linked into the generated DLL, so end users don't need it installed.
- **Linux**: needs `libssl-dev` at build time (`sudo apt install libssl-dev` on Debian/Ubuntu) — also statically linked.
- **macOS/iOS/Android**: no extra setup, uses a precompiled SQLCipher build.

**Windows-specific gotcha**: if your installed CMake predates the modern Win64OpenSSL installer's `lib/VC/<arch>/<mode>/` directory layout (this bites the CMake 3.20 that ships with VS2019 Build Tools; VS2022's bundled CMake is newer and may not need this — but VS2022's CMake component isn't installed by default, so you may still be on the VS2019 one even with VS2022 present), the build fails at configure time with `Could NOT find OpenSSL ... OPENSSL_CRYPTO_LIBRARY`. `app/windows/CMakeLists.txt` looks for a compat directory at `app/windows/.openssl-compat/` (gitignored, not committed — it's a partial copy of your real OpenSSL install, machine-specific) and points `OPENSSL_ROOT_DIR` at it if present. Regenerate it after installing OpenSSL:

```powershell
$dst = "app\windows\.openssl-compat"
New-Item -ItemType Directory -Force "$dst\lib\VC\static" | Out-Null
Copy-Item "C:\Program Files\OpenSSL-Win64\include\*" "$dst\include" -Recurse -Force
Copy-Item "C:\Program Files\OpenSSL-Win64\lib\VC\x64\MD\libcrypto_static.lib" "$dst\lib\VC\static\libcrypto_static.lib" -Force
Copy-Item "C:\Program Files\OpenSSL-Win64\lib\VC\x64\MD\libssl_static.lib" "$dst\lib\VC\static\libssl_static.lib" -Force
```

If your CMake is new enough to understand the real install directly, you don't need this at all — just don't create `.openssl-compat/` and the `if(EXISTS ...)` in CMakeLists.txt skips the override.

Verified working end to end on Windows: `flutter build windows --release` produces a `kangoos_app.exe` that launches, opens the SQLCipher-encrypted database, and renders normally.

Self-hosted server: see [server/README.md](server/README.md).

## License

[AGPL-3.0](LICENSE)
