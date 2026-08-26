import '../snippets/snippet_repository.dart';
import '../snippets/snippet_service.dart';
import 'snippet_sync_engine.dart';
import 'sync_transport.dart';

class SnippetSyncClient {
  const SnippetSyncClient({
    required this.repository,
    required this.transport,
    this.snippetService,
  });

  final SnippetRepository repository;
  final SyncTransport transport;
  final SnippetService? snippetService;

  Future<SyncResult> sync() => SnippetSyncEngine(
        repository: repository,
        transport: transport,
        snippetService: snippetService,
      ).sync();
}
