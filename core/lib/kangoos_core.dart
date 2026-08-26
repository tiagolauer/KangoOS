library;

export 'src/activity/activity_span.dart';
export 'src/capture/quick_capture.dart';
export 'src/chat/rag_chat.dart';
export 'src/chat/temporal_query.dart';
export 'src/connectors/agent_connector.dart';
export 'src/connectors/browser_connector.dart';
export 'src/connectors/caldav_connector.dart';
export 'src/connectors/connector_repository.dart';
export 'src/connectors/local_file_connector.dart';
export 'src/connectors/searxng_connector.dart';
export 'src/database/database.dart'
    show
        Activity,
        ActivitySummary,
        ConnectorSource,
        ConnectorToolPermission,
        Conversation,
        ConversationMessage,
        DeletedSnippet,
        LocalPersona,
        MemoryEpisode,
        Snippet;
export 'src/database/tables/agent_context_tables.dart' show ConnectorSourceKind;
export 'src/database/snippet_json.dart';
export 'src/database/tables/activity_summaries_table.dart'
    show ActivitySummaryVector, SummaryKind, automaticDurableMemoryPrefix;
export 'src/database/tables/memory_episodes_table.dart'
    show MemoryFormationStatus;
export 'src/database/tables/conversations_table.dart'
    show ConversationMessageVector, ConversationSummary;
export 'src/database/tables/snippets_table.dart' show SnippetVector;
export 'src/embedding/embedding_provider.dart';
export 'src/exchange/snippet_exchange.dart';
export 'src/embedding/providers/ollama_embedding_provider.dart';
export 'src/embedding/providers/openai_embedding_provider.dart';
export 'src/memory/activity_repository.dart';
export 'src/memory/episode_builder.dart';
export 'src/memory/episode_repository.dart';
export 'src/memory/memory_service.dart';
export 'src/memory/memory_formation_service.dart';
export 'src/memory/memory_enricher.dart';
export 'src/memory/memory_hierarchy_service.dart';
export 'src/memory/memory_metrics.dart';
export 'src/memory/memory_agent.dart';
export 'src/memory/memory_deletion.dart';
export 'src/memory/memory_query_engine.dart';
export 'src/memory/privacy_filter.dart';
export 'src/memory/observation.dart';
export 'src/memory/persona_repository.dart';
export 'src/memory/persona_service.dart';
export 'src/memory/summary_repository.dart';
export 'src/mcp/kango_mcp_server.dart';
export 'src/snippets/snippet_repository.dart';
export 'src/snippets/snippet_service.dart';
export 'src/chat/conversation_repository.dart';
export 'src/llm/llm_http.dart';
export 'src/llm/llm_provider.dart';
export 'src/llm/llm_stream.dart';
export 'src/llm/llm_settings.dart';
export 'src/llm/providers/anthropic_provider.dart';
export 'src/llm/providers/gemini_provider.dart';
export 'src/llm/providers/ollama_provider.dart';
export 'src/llm/providers/openai_provider.dart';
export 'src/search/semantic_search.dart';
export 'src/search/vector_index.dart';
export 'src/summary/activity_summarizer.dart';
export 'src/sync/snippet_sync_client.dart';
export 'src/sync/snippet_sync_engine.dart';
export 'src/sync/sync_transport.dart';
export 'src/sync/http_sync_transport.dart';
export 'src/tagging/snippet_tagger.dart';
