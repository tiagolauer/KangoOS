# Changelog

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
