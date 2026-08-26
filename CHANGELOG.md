# Changelog

## Unreleased

## 1.2.0

### Added
- Unified Timeline for events, episodes, summaries, manual memories,
  conversations and DeepStudy reports, with lexical/semantic search, filters,
  favorites, source review and granular deletion.
- Conversation-scoped memory filters and file/folder attachments, inspectable
  evidence, retry controls and explicit Reflection/DeepStudy modes.
- Timed capture pause, LTM settings and granular deletion in the Windows tray
  panel.
- Seven-day canonical LTM corpus, privacy-safe health metrics, LM Studio and
  Windows-native release gates, 50k scale benchmark and configurable soak test.
- Versioned Windows installer CI with SHA-256 output and separate macOS/Linux
  compilation gates.

## 1.1.0

### Fixed
- The app could hang on an endless loading spinner at startup. A database
  created before encryption was introduced is plaintext on disk, and opening it
  with a key fails; the failure surfaced inside drift's streams, where the
  sidebar rendered its null-data spinner forever. The key is now validated when
  the database opens, a legacy plaintext database is migrated in place (the
  original is kept as `.plaintext-backup`), and a failure shows a readable
  error screen instead of a spinner.
- The "New snippet" button rendered as an empty circle. The theme let Flutter
  derive `secondaryContainer` from `secondary`, which matched the global icon
  colour, so the glyph was drawn in the same colour as its own background.

### Added
- Interface localization in English and Brazilian Portuguese, following the OS
  language. Dates and weekday/month names are locale-aware, and the
  single-click summary prompts are localized too, so answers come back in the
  same language as the UI.
- Snippet deletions now propagate through sync in both directions, using
  tombstones keyed by sync id. An edit strictly newer than the deletion
  resurrects the snippet; on an exact timestamp tie the deletion wins.
- Opt-in continuous screen OCR (Windows), using the OCR engine built into
  Windows. Off by default — it reads the entire screen, and the excluded-apps
  list cannot filter it.
- Opt-in microphone transcription (Windows) with local Whisper. Records a
  30-second clip every 10 minutes, transcribes it on-device, deletes the audio
  and keeps only the text. Requires a one-time ~140 MB model download and is
  off by default.

### Changed
- Semantic search is roughly 14x faster: embeddings are stored as packed
  float32 blobs instead of JSON text, and scoring reads only the vectors before
  fetching full rows for the top hits. At 10 000 snippets a query went from
  573 ms to 40 ms. An approximate-nearest-neighbour index was measured and
  rejected — distance computation was never the bottleneck.

## 1.0.0

First release. Windows desktop app (Linux/macOS are experimental — see the
README's platform-support section).

### Snippets
- Create/edit/delete with automatic LLM tagging.
- Full-text search (SQLite FTS5, bm25-ranked, prefix + implicit-AND) and
  semantic search (local Ollama embeddings, cosine similarity).
- Contextual chat over snippets (RAG), with browsable, persisted chat history.
- JSON export/import, de-duplicated by a stable sync id.

### Long-term memory
- Activity capture (foreground app + window title), opt-in first-run consent,
  retention/purge, per-app denylist, swipe-to-delete and clear-all.
- Opt-in browser-URL, focused-visible-text (Windows UI Automation) and
  clipboard capture.
- Full-text search over captured activity.
- Automatic 20-minute activity summaries plus on-demand day recaps; Timeline
  grouped by day; today's-activity sparkline.
- Chat and the `ask_kango_ltm` MCP tool are grounded in captured activity and
  summaries, with plain-English time ranges (today/yesterday/this week/last
  week).

### LLM providers
- Ollama (local, default), Anthropic, OpenAI and Gemini, with a
  Fast/Balanced/Extra-Thinking reasoning-mode picker.
- API keys stored in the OS keychain, never plaintext on disk.

### Storage and security
- Encryption at rest for the app database (SQLCipher), keyed from the OS
  keychain.
- No account, no telemetry; everything local by default.

### Integrations and self-hosting
- `kango` CLI and `kango_mcp` MCP server (snippet tools + `ask_kango_ltm` /
  `create_kango_memory`).
- Self-hosted HTTP server (Docker, bearer-token auth) exposing snippets and
  RAG chat.
- Manual snippet sync between the app and a self-hosted server.

### Tooling
- GitHub Actions CI: analyze + test for core/server/app and a real Windows
  release build.
