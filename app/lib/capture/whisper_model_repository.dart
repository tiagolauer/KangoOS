import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const whisperModelFileName = 'ggml-base.bin';
const whisperModelUrl =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$whisperModelFileName';
const whisperModelApproximateBytes = 148000000;
const _minimumPlausibleModelBytes = 1000000;

sealed class ModelDownloadResult {
  const ModelDownloadResult();
}

class ModelDownloadSuccess extends ModelDownloadResult {
  const ModelDownloadSuccess(this.path);

  final String path;
}

class ModelDownloadFailure extends ModelDownloadResult {
  const ModelDownloadFailure(this.message);

  final String message;
}

class WhisperModelRepository {
  WhisperModelRepository({http.Client? httpClient, Directory? modelDirectory})
      : _httpClient = httpClient,
        _modelDirectory = modelDirectory;

  final http.Client? _httpClient;
  final Directory? _modelDirectory;

  Future<Directory> _directory() async =>
      _modelDirectory ?? await getApplicationSupportDirectory();

  Future<String> modelPath() async =>
      p.join((await _directory()).path, whisperModelFileName);

  Future<bool> isDownloaded() async {
    try {
      final file = File(await modelPath());
      if (!file.existsSync()) return false;
      return file.lengthSync() >= _minimumPlausibleModelBytes;
    } catch (_) {
      return false;
    }
  }

  Future<ModelDownloadResult> download({
    void Function(int received, int total)? onProgress,
  }) async {
    final client = _httpClient ?? http.Client();
    final target = File(await modelPath());
    final partial = File('${target.path}.part');

    try {
      final request = http.Request('GET', Uri.parse(whisperModelUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        return ModelDownloadFailure('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? whisperModelApproximateBytes;
      final sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();

      if (partial.lengthSync() < _minimumPlausibleModelBytes) {
        partial.deleteSync();
        return const ModelDownloadFailure('o arquivo baixado é pequeno demais');
      }

      if (target.existsSync()) target.deleteSync();
      partial.renameSync(target.path);
      return ModelDownloadSuccess(target.path);
    } catch (e) {
      if (partial.existsSync()) partial.deleteSync();
      return ModelDownloadFailure('$e');
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  Future<void> delete() async {
    final file = File(await modelPath());
    if (file.existsSync()) file.deleteSync();
  }
}
