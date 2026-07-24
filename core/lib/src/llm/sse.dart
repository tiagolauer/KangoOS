import 'dart:convert';

Stream<String> sseDataLines(Stream<List<int>> byteStream) async* {
  final lines = byteStream.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring('data: '.length);
    if (data == '[DONE]') continue;
    yield data;
  }
}
