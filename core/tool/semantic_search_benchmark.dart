import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

class _StubEmbeddingProvider implements EmbeddingProvider {
  _StubEmbeddingProvider(this.dimensions);

  final int dimensions;
  final _random = Random(7);

  @override
  String get id => 'stub';

  @override
  Future<List<double>> embed(String text) async =>
      List<double>.generate(dimensions, (_) => _random.nextDouble());
}

const _dimensions = 768;
const _corpusSizes = [100, 1000, 10000, 50000];
const _queryRuns = 10;

Future<void> main() async {
  print('dims=$_dimensions runs per size=$_queryRuns\n');
  print('snippets | load+decode | cosine+sort |   total | per query');
  print('---------|-------------|-------------|---------|----------');

  for (final size in _corpusSizes) {
    final database = KangoosDatabase.memory();
    final provider = _StubEmbeddingProvider(_dimensions);

    await database.batch((batch) {
      batch.insertAll(
        database.snippets,
        [
          for (var i = 0; i < size; i++)
            SnippetsCompanion.insert(
              title: 'snippet $i',
              content: 'body $i',
              embedding: Value(List<double>.generate(
                  _dimensions, (d) => ((i * 31 + d * 17) % 1000) / 1000)),
            ),
        ],
      );
    });

    final queryEmbedding = await provider.embed('query');

    var loadMicros = 0;
    var scoreMicros = 0;
    final watch = Stopwatch();

    for (var run = 0; run < _queryRuns; run++) {
      watch
        ..reset()
        ..start();
      final candidates = await database.snippetVectors();
      watch.stop();
      loadMicros += watch.elapsedMicroseconds;

      watch
        ..reset()
        ..start();
      final matches = candidates
          .map((s) => cosineSimilarity(queryEmbedding, s.embedding))
          .toList()
        ..sort((a, b) => b.compareTo(a));
      watch.stop();
      scoreMicros += watch.elapsedMicroseconds;
      if (matches.isEmpty) throw StateError('no matches');
    }

    final load = loadMicros / _queryRuns / 1000;
    final score = scoreMicros / _queryRuns / 1000;
    print('${size.toString().padLeft(8)} | '
        '${load.toStringAsFixed(1).padLeft(8)} ms | '
        '${score.toStringAsFixed(1).padLeft(8)} ms | '
        '${(load + score).toStringAsFixed(1).padLeft(6)} ms | '
        '${((load + score)).toStringAsFixed(1)} ms');

    await database.close();
  }
}
