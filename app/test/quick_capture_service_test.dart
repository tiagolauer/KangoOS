import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

import 'package:kangoos_app/capture/window_capture_service.dart';
import 'package:kangoos_app/quick_capture_service.dart';

import 'test_services.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

void main() {
  late KangoosDatabase database;
  late TestServices services;

  setUp(() {
    database = KangoosDatabase.memory();
    services = TestServices(
      database,
      embeddingProvider: _FakeEmbeddingProvider(),
    );
  });
  tearDown(() => database.close());

  QuickCaptureService service({
    required String? clipboard,
    String appName = 'code.exe',
  }) =>
      QuickCaptureService(
        snippets: services.snippets,
        readClipboard: () async => clipboard,
        readWindow: () =>
            WindowSnapshot(appName: appName, windowTitle: 'main.dart'),
      );

  test('saves the clipboard as an indexed snippet with its source', () async {
    final id = await service(clipboard: 'def greet(name):\n    print(name)')
        .saveClipboard();

    final snippet = (await database.getSnippetById(id!))!;
    expect(snippet.title, 'def greet(name):');
    expect(snippet.language, 'python');
    expect(snippet.tags, contains('code.exe'));
    expect(snippet.embedding, isNotNull);
  });

  test('an empty clipboard saves nothing', () async {
    expect(await service(clipboard: '   ').saveClipboard(), isNull);
    expect(await service(clipboard: null).saveClipboard(), isNull);
    expect(await database.allSnippets(), isEmpty);
  });

  test('the snippet is findable by keyword right away', () async {
    await service(clipboard: 'SELECT id FROM snippets;').saveClipboard();

    expect(await database.searchByKeyword('snippets'), hasLength(1));
  });
}
