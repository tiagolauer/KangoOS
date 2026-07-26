# KangoOS

Open source alternative to [Pieces OS](https://pieces.app/): a snippet manager with contextual chat (RAG), self-hosted, 100% user-owned data.

## Why

- **Self-hosted**: runs locally by default; optional self-hosted server (Docker) the app can sync snippets with for multi-device use.
- **Local-first LLM**: [Ollama](https://ollama.com/) by default, with optional fallback to OpenAI/Anthropic/Gemini via user-supplied API key.
- **AGPL-3.0 licensed**: free to use and modify, including as a service, as long as modified source stays available.

## Platform support

**Windows is the supported target for 1.0** — it's the only platform the app is built, run and verified on (see the CI `windows-build` job, which produces the released binary). The cross-platform code (activity capture, browser-URL reading, keychain, tray) is written for Linux and macOS too, but those builds are **experimental**: not packaged, not CI-built, and not verified end to end. Linux additionally needs `libayatana-appindicator3-dev`, `libssl-dev` and libsecret at build time. Treat non-Windows as build-it-yourself until a later release.

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
- Full-text search (real SQLite FTS5, bm25-ranked, prefix matching) + semantic search (local embeddings, brute-force cosine — no ANN index, deliberately: see below)

  Embeddings are stored as packed float32 blobs, and scoring reads only `(id, embedding)` before fetching the full rows for the top hits. Measured with `dart run tool/semantic_search_benchmark.dart` (768 dimensions, per query):

  | snippets | before | after |
  |---------:|-------:|------:|
  |    1 000 |   48 ms |   4 ms |
  |   10 000 |  573 ms |  40 ms |
  |   50 000 | 3022 ms | 217 ms |

  An approximate-nearest-neighbour index was considered and rejected on these numbers: even before the change, distance computation was only ~3% of query time (17 ms of 573 ms at 10 000 snippets) — the cost was loading and JSON-decoding every embedding, which an ANN index does not address. Revisit above ~50 000 snippets, where holding vectors in memory or an on-disk vector index would start to pay.
- Contextual chat over saved snippets (RAG)
- LLM provider configuration (local Ollama, or Anthropic/OpenAI/Gemini via API key, stored in the OS keychain — Credential Manager/Keychain/Secret Service, never plaintext on disk), with a reasoning-mode picker (Fast/Balanced/Extra Thinking) mapped to each provider's own mechanism — only takes effect on reasoning-capable models
- Encryption at rest for the desktop app's local database (SQLCipher), keyed by a random key stored in the OS keychain — same mechanism as the LLM API keys. The CLI/MCP/server databases are unaffected (plain SQLite) — separate stores, separate threat model. **Because the key lives in the OS keychain, not the database file, wiping the keychain entry (or moving the `.db` to another machine) makes the data unrecoverable — export your snippets first (below) if that's a risk.**
- Snippet export/import (More menu → Export/Import snippets): writes/reads a plain JSON file (title, content, language, tags, timestamps, syncId — not embeddings, which re-index locally). Import de-duplicates by syncId, or by title+content when there's no syncId. This is the backup path for snippets specifically; captured activity and chat history are not exported.

- Self-hosted HTTP server (Docker) — same snippet storage/RAG chat as the app, reachable over its REST API (curl, scripts, or the app's own sync client)
- Snippet sync with the self-hosted server (manual, one button): pushes/pulls snippets keyed by a client-generated `syncId`, last-write-wins on `updatedAt` when both sides changed. Deletions propagate both ways via tombstones: deleting on one side deletes on the other, while an edit strictly newer than the deletion resurrects the snippet instead. On an exact timestamp tie the deletion wins — SQLite stores whole seconds, so ties are common. Tombstones are kept indefinitely so a device that syncs late still learns about the deletion. Snippets only — captured activity, summaries and chat history stay device-local.
- Activity capture (Windows/Linux/macOS, app + window title by default) with retention/purge
  - Linux requires an X11 session (or XWayland); macOS requires granting Accessibility permission to the app so "System Events" can read other apps' window titles
- Timeline: automatic activity summaries every 20 minutes, plus on-demand day recap (via LLM)
- Opt-in microphone transcription (Windows only, off by default): every 10 minutes, records a 30-second clip from the default input device and transcribes it locally with [whisper.cpp](https://github.com/ggml-org/whisper.cpp). The audio never leaves the machine and the clip is deleted immediately after transcription — only the text is stored, alongside the focused window, and indexed for full-text search.

  Requires a one-time ~140 MB speech-model download (`ggml-base`), triggered explicitly from capture settings; the toggle stays disabled until the model is present. whisper.cpp is fetched and compiled by CMake during the Windows build (pinned commit, adds roughly 30 seconds to a clean build), so no prebuilt binaries are vendored.

  **Recording captures whoever is speaking — including other people in the room or on a call, who have not agreed to it.** Whether that is lawful depends on where you are: some jurisdictions require every party to consent. Check before enabling.
- Opt-in continuous screen OCR (Windows only, off by default): each time the focused window changes, a bundled `screen_ocr.exe` helper captures the virtual screen and runs Windows' built-in OCR engine (`Windows.Media.Ocr` — local, no cloud, no extra downloads), storing the text alongside the activity entry and indexing it for full-text search.

  **This is the most invasive capture source in KangoOS and it is not comparable to the others.** It reads the *entire screen*, so it records things you never focused and never opened: another person's messages in a shared call, a document a colleague put on screen, notifications that happen to pop up. The excluded-apps list does **not** protect you here — that list filters by the foreground process, while OCR reads every pixel regardless of which window owns it. Leave it off unless you have thought about what is on your screen, and prefer a short retention window if you turn it on.
- Opt-in browser URL capture (off by default, real content — not just metadata): reads the active tab's URL for Chrome/Edge/Brave/Safari.
  - macOS: via AppleScript (reliable — browsers expose this directly).
  - Windows: via UI Automation reading the address bar (best-effort heuristic, unverified against a real browser at time of writing).
  - Linux: via AT-SPI/D-Bus tree walk (best-effort, needs an AT-SPI-enabled desktop session; Firefox untested, lowest-confidence of the three).
- Localized interface (English and Brazilian Portuguese), following the OS language and falling back to English. Strings live in `app/lib/l10n/*.arb`; dates, weekday and month names come from `intl` per locale. The single-click summary prompts are localized too, so the assistant answers in the same language as the UI. A test asserts the two translation files never drift apart — add a key to `app_en.arb` without translating it and the suite fails.
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
