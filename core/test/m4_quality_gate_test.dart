import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

import '../benchmark/m4_corpus.dart';

void main() {
  test(
    'M4 versioned corpus meets recall and temporal accuracy gates',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final episodes = SqliteEpisodeRepository(database);
      final corpusStart = DateTime.utc(2026, 1, 1);
      for (var index = 0; index < m4CorpusTopics.length; index++) {
        await episodes.create(m4CorpusEpisode(index, corpusStart));
      }
      final engine = MemoryQueryEngine(episodes: episodes);
      final searchCases = buildM4SearchCases();
      var recalled = 0;
      for (final testCase in searchCases) {
        final result = await engine.search(
          testCase.query,
          reference: DateTime.utc(2026, 8, 26),
          mode: MemorySearchMode.lexical,
        );
        if (result.evidence.any((item) => item.id == testCase.expectedKey)) {
          recalled++;
        }
      }
      final temporalCases = buildM4TemporalCases();
      const parser = RuleBasedTemporalParser();
      var temporallyCorrect = 0;
      for (final testCase in temporalCases) {
        final parsed = parser.parseSync(testCase.query, testCase.reference);
        if (parsed.start == testCase.start && parsed.end == testCase.end) {
          temporallyCorrect++;
        }
      }
      final recallAt10 = recalled / searchCases.length;
      final temporalAccuracy = temporallyCorrect / temporalCases.length;

      expect(m4SyntheticCorpusVersion, 1);
      expect(searchCases.length, greaterThanOrEqualTo(100));
      expect(temporalCases.length, greaterThanOrEqualTo(100));
      expect(recallAt10, greaterThanOrEqualTo(0.85));
      expect(temporalAccuracy, greaterThanOrEqualTo(0.9));
    },
  );
}
