# kangoos_server

Self-hosted HTTP server exposing [`kangoos_core`](../core) — the same snippet storage, semantic search and RAG chat the desktop app uses, reachable over the network via its own REST API. The desktop app has a snippet sync client (Server sync icon in the header) that pushes/pulls against this server for multi-device use; it's also usable standalone via curl/scripts, or as the backend for a future client.

## Run with Docker

```bash
KANGOOS_API_TOKEN=$(openssl rand -hex 32) docker compose up --build
```

`KANGOOS_API_TOKEN` is required and must be at least 32 characters — the server refuses to start otherwise. Every request (except `/health`) must send it back as `Authorization: Bearer <token>`.

By default the server talks to Ollama on the Docker host (`http://host.docker.internal:11434`) for both chat and embeddings. Override any setting via environment variables — see the table below.

## Run locally (no Docker)

```bash
cd server
dart pub get
KANGOOS_API_TOKEN=$(openssl rand -hex 32) dart run bin/server.dart
```

## Put it behind TLS

The server speaks plain HTTP and has no TLS support of its own. It binds `0.0.0.0`, and both the bearer token and every snippet body travel in cleartext, so anything beyond `localhost` belongs behind a reverse proxy that terminates TLS (Caddy, nginx, Traefik) or inside a private tunnel (Tailscale, WireGuard). The app warns before syncing to a plain `http://` host that is not on the local machine.

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `KANGOOS_API_TOKEN` | — | **Required**, minimum 32 characters. Generate with `openssl rand -hex 32`. |
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
GET    /snippets?q=&mode=          list/search (mode: keyword [default] | semantic); no q returns all
POST   /snippets                   create -- { title, content, language?, tags?, syncId?, createdAt?, updatedAt? }
GET    /snippets/<id>              get one
PUT    /snippets/<id>              update -- any of { title, content, language, tags, updatedAt }
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

`syncId`/`createdAt`/`updatedAt` on create, and `updatedAt` on update, exist for the app's sync client (`core`'s `SnippetSyncClient`): `syncId` is a client-generated stable id used to match the same snippet across devices (the row's own `id` is per-database and not portable); `createdAt`/`updatedAt` are epoch-millisecond ints, letting the client preserve its own timestamps instead of getting server-assigned ones on every push. All three are optional -- omit them for a plain manual create/update and the server fills in sensible defaults.
