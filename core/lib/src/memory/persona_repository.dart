import '../database/database.dart';

abstract interface class PersonaRepository {
  Future<LocalPersona?> load();

  Future<LocalPersona> save({
    required bool enabled,
    required String content,
    required List<int> sourceSummaryIds,
  });

  Future<int> delete();
}
