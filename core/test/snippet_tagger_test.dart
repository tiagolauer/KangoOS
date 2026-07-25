import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

class _FakeLlmProvider implements LlmProvider {
  _FakeLlmProvider(this.chunks);

  final List<String> chunks;
  List<LlmMessage>? lastMessages;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    lastMessages = messages;
    return Stream.fromIterable(chunks);
  }
}

void main() {
  const tagger = SnippetTagger();

  test('parses a clean JSON array response', () async {
    final provider =
        _FakeLlmProvider(['["dart", "string', '-manipulation", "algorithm"]']);

    final tags = await tagger.suggestTags(
      provider: provider,
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
      language: 'dart',
    );

    expect(tags, ['dart', 'string-manipulation', 'algorithm']);
    expect(provider.lastMessages!.single.content, contains('Reverse a string'));
    expect(provider.lastMessages!.single.content, contains('Language: dart'));
  });

  test('extracts a JSON array embedded in explanatory text', () async {
    final provider = _FakeLlmProvider([
      'Sure! Here are some tags:\n```json\n["dart", "strings"]\n```\nHope that helps!',
    ]);

    final tags = await tagger.suggestTags(
      provider: provider,
      title: 'Foo',
      content: 'bar',
    );

    expect(tags, ['dart', 'strings']);
  });

  test('falls back to comma/newline splitting when the response is not JSON',
      () async {
    final provider = _FakeLlmProvider(['dart, strings, Algorithm!\nreverse']);

    final tags = await tagger.suggestTags(
        provider: provider, title: 'Foo', content: 'bar');

    expect(tags, ['dart', 'strings', 'algorithm', 'reverse']);
  });

  test('deduplicates, lowercases, strips punctuation and caps at 6 tags',
      () async {
    final provider = _FakeLlmProvider([
      '["Dart", "dart", "a-very-long-tag-that-is-definitely-over-thirty-characters", '
          '"a", "b", "c", "d", "e", "f"]',
    ]);

    final tags = await tagger.suggestTags(
        provider: provider, title: 'Foo', content: 'bar');

    expect(tags, hasLength(6));
    expect(tags, ['dart', 'a', 'b', 'c', 'd', 'e']);
  });

  test('an empty or garbage response yields no tags', () async {
    final provider = _FakeLlmProvider(['   ']);
    final tags = await tagger.suggestTags(
        provider: provider, title: 'Foo', content: 'bar');
    expect(tags, isEmpty);
  });
}
