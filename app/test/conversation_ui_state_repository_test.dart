import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/home/conversation_ui_state_repository.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'conversation filters, attachments and evidence survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ConversationUiStateRepository();
      final evidence = MemoryEvidence(
        id: 'episode:1',
        kind: MemoryEvidenceKind.episode,
        title: 'Entrega',
        content: 'Entrega concluída',
        startedAt: DateTime.utc(2026, 8, 26),
        endedAt: DateTime.utc(2026, 8, 26, 1),
      );
      await repository.save(
        7,
        ConversationUiState(
          filters: const MemorySearchFilters(
            sources: {MemoryEvidenceSource.episode},
            applications: {'Code'},
            modalities: {MemoryModality.metadata},
            projects: {'KangoOS'},
          ),
          attachmentPaths: const ['C:\\projetos\\KangoOS'],
          evidence: [evidence],
        ),
      );

      final restored = await repository.load(7);

      expect(restored.filters.sources, {MemoryEvidenceSource.episode});
      expect(restored.filters.applications, {'Code'});
      expect(restored.filters.modalities, {MemoryModality.metadata});
      expect(restored.filters.projects, {'KangoOS'});
      expect(restored.attachmentPaths, [r'C:\projetos\KangoOS']);
      expect(restored.evidence.single.id, evidence.id);
    },
  );

  test(
    'attachment context reads only bounded text files selected by user',
    () async {
      final directory = await Directory.systemTemp.createTemp('kangoos-m7-');
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}${Platform.pathSeparator}notes.md',
      ).writeAsString('evidência local');
      await File(
        '${directory.path}${Platform.pathSeparator}image.png',
      ).writeAsBytes([0, 1, 2, 3]);

      final context = await buildAttachmentContext([directory.path]);

      expect(context, contains('evidência local'));
      expect(context, isNot(contains('image.png')));
      expect(context, contains('"untrusted":true'));
    },
  );
}
