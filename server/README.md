# kangoos_server

Self-hosted HTTP server exposing [`kangoos_core`](../core) — the same snippet storage, semantic search and RAG chat the desktop app uses, reachable over the network so multiple clients (desktop app, IDE extensions, browser extension) can share one store.

## Run with Docker

```bash
KANGOOS_API_TOKEN=$(openssl rand -hex 32) docker compose up --build
```

`KANGOOS_API_TOKEN` is required — the compose file refuses to start without it. Every request (except `/health`) must send it back as `Authorization: Bearer <token>`.

By default the server talks to Ollama on the Docker host (`http://host.docker.internal:11434`) for both chat and embeddings. Override any setting via environment variables — see the table below.

## Run locally (no Docker)

```bash
cd server
dart pub get
KANGOOS_API_TOKEN=dev-token dart run bin/server.dart
```

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `KANGOOS_API_TOKEN` | — | **Required.** Server refuses to start without it. |
| `KANGOOS_DB_PATH` | `kangoos.db` | SQLite file path. Mount a volume here in Docker. |
| `KANGOOS_LLM_PROVIDER` | `ollama` | `ollama`, `anthropic`, or `openAi`. |
| `KANGOOS_LLM_MODEL` | `llama3` | Model id for the chosen provider. |
| `KANGOOS_LLM_API_KEY` | (empty) | Required for `anthropic`/`openAi`. |
| `KANGOOS_LLM_BASE_URL` | (empty) | Ollama base URL override; empty uses `http://localhost:11434`. |
| `KANGOOS_EMBEDDING_MODEL` | `nomic-embed-text` | Ollama embedding model for semantic search. |
| `KANGOOS_OLLAMA_BASE_URL` | `http://localhost:11434` | Where the embedding provider looks for Ollama. |
| `PORT` | `8080` | HTTP port. |

## API

All routes below require `Authorization: Bearer <KANGOOS_API_TOKEN>` except `/health`.

```
GET    /health                     no auth, liveness check
GET    /snippets?q=&mode=          list/search (mode: keyword [default] | semantic)
POST   /snippets                   create -- { title, content, language?, tags? }
GET    /snippets/<id>              get one
PUT    /snippets/<id>              update -- any of { title, content, language, tags }
DELETE /snippets/<id>              delete
POST   /snippets/<id>/index        (re)compute the embedding for one snippet
POST   /index/missing              backfill embeddings for snippets that don't have one
POST   /chat                       RAG chat -- { message, history? } -> SSE stream of { text }
```

### Examples

```bash
TOKEN=dev-token
BASE=http://localhost:8080

curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Reverse a string","content":"input.split(\"\").reversed.join()"}' \
  "$BASE/snippets"

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/snippets?q=reverse&mode=semantic"

curl -s -N -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"message":"how do I reverse a string?"}' \
  "$BASE/chat"
```

`/chat`'s `history` field is a list of `{"role": "user"|"assistant", "content": "..."}` -- the same shape the app keeps in memory, sent back so the server can reply in context without persisting conversation state server-side.
