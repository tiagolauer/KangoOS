import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../memory/persona_repository.dart';

const localPersonaId = 1;

class SqlitePersonaRepository implements PersonaRepository {
  const SqlitePersonaRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<LocalPersona?> load() =>
      (database.select(database.localPersonas)
        ..where((row) => row.id.equals(localPersonaId))).getSingleOrNull();

  @override
  Future<LocalPersona> save({
    required bool enabled,
    required String content,
    required List<int> sourceSummaryIds,
  }) async {
    final existing = await load();
    final now = DateTime.now();
    await database
        .into(database.localPersonas)
        .insertOnConflictUpdate(
          LocalPersonasCompanion.insert(
            id: const Value(localPersonaId),
            enabled: Value(enabled),
            content: content,
            sourceSummaryIds: Value(sourceSummaryIds),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    final stored = await load();
    if (stored == null) {
      throw StateError('Local persona could not be loaded after save.');
    }
    return stored;
  }

  @override
  Future<int> delete() =>
      (database.delete(database.localPersonas)
        ..where((row) => row.id.equals(localPersonaId))).go();
}
