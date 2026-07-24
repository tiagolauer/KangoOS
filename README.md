# KangoOS

Alternativa open source ao [Pieces OS](https://pieces.app/): gerenciador de snippets com chat contextual (RAG), self-hosted, dados 100% do usuário.

## Diferencial

- **Self-hosted**: roda local por padrão; servidor próprio (Docker) opcional pra sync entre dispositivos.
- **LLM local-first**: [Ollama](https://ollama.com/) por padrão, com fallback opcional pra OpenAI/Anthropic/Gemini via API key do usuário.
- **Licença AGPL-3.0**: uso e modificação livres, inclusive como serviço, desde que o código-fonte modificado também seja disponibilizado.

## Estrutura do repositório

```
KangoOS/
├── app/    # App Flutter (desktop: Windows/Linux/macOS)
└── core/   # KangoOS Core — package Dart puro (snippets, busca, storage, LLM adapter)
```

`app` depende de `core` via path dependency (`../core`). O mesmo `core` roda embutido no app (modo standalone) ou exposto via servidor HTTP (modo self-hosted, futuro).

## Escopo do MVP

- CRUD de snippets com tags automáticas (via LLM)
- Busca full-text + semântica (embeddings locais)
- Chat contextual sobre os snippets salvos (RAG)
- Configuração de provider LLM (Ollama local ou API key de terceiros)

Fora do MVP (roadmap futuro): captura automática de contexto (timeline/LTM), extensão VS Code, extensão de browser, app mobile, sistema de plugins.

## Stack

- **UI**: Flutter (desktop)
- **Core**: Dart puro
- **Storage**: [drift](https://drift.simonbinder.eu/) (SQLite type-safe, FTS nativo)

## Desenvolvimento

```bash
cd core && dart pub get
cd ../app && flutter pub get && flutter run -d windows
```

## Licença

[AGPL-3.0](LICENSE)
