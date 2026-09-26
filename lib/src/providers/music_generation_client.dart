import 'dart:async';
import 'dart:convert';
import 'dart:io';

class GeneratedMusic {
  const GeneratedMusic({required this.audioUrl});
  final Uri audioUrl;
}

class MusicGenerationResult {
  const MusicGenerationResult({required this.songs, required this.failedCount});
  final List<GeneratedMusic> songs;
  final int failedCount;
}

class MusicGenerationClient {
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  bool cancelled = false;

  void close() => _http.close(force: true);

  void cancel() {
    cancelled = true;
    close();
  }

  Future<Map<String, dynamic>> _json(
    String method,
    Uri uri,
    String key, [
    Map<String, Object?>? body,
  ]) async {
    final request = await _http.openUrl(method, uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final content = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        '音乐服务请求失败（HTTP ${response.statusCode}）：$content',
        uri: uri,
      );
    }
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<MusicGenerationResult> generate({
    required String key,
    required String baseUrl,
    required String model,
    required String prompt,
    required String title,
    required bool instrumental,
  }) async {
    final base = Uri.parse(baseUrl);
    final submitted = await _json(
      'POST',
      base.replace(path: '${base.path}/music/generate'),
      key,
      {
        'gpt_description_prompt': prompt,
        'make_instrumental': instrumental,
        'mv': model,
        'title': title,
      },
    );
    final ids = (submitted['data'] as Map)['task_ids'] as List;
    final songs = <GeneratedMusic>[];
    final remaining = ids.cast<int>().toSet();
    var failed = 0;
    for (var attempt = 0; attempt < 60 && remaining.isNotEmpty; attempt++) {
      if (cancelled) throw StateError('已停止等待音乐生成，请勿自动重试');
      await Future<void>.delayed(const Duration(seconds: 5));
      final pending = remaining.toList();
      final tasks = await Future.wait([
        for (final id in pending)
          _json(
            'GET',
            base.replace(
              path: '${base.path}/music/task',
              queryParameters: {'id': '$id'},
            ),
            key,
          ),
      ]);
      for (var index = 0; index < tasks.length; index++) {
        final task = tasks[index]['data'] as Map;
        final id = pending[index];
        if (task['status'] == 'completed') {
          final result = task['result'] as Map;
          final fileInfo = result['fileInfo'] as Map;
          songs.add(
            GeneratedMusic(audioUrl: Uri.parse(fileInfo['mp3Url'] as String)),
          );
          remaining.remove(id);
        } else if (task['status'] == 'failed') {
          failed++;
          remaining.remove(id);
        }
      }
    }
    if (remaining.isNotEmpty) {
      throw TimeoutException('音乐生成仍在进行中，服务商可能已扣费，请勿自动重新提交');
    }
    if (songs.isEmpty) throw StateError('音乐生成失败，请查看服务商后台');
    return MusicGenerationResult(songs: songs, failedCount: failed);
  }

  Future<int> download(Uri url, File file) async {
    final request = await _http.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('音乐文件下载失败（HTTP ${response.statusCode}）', uri: url);
    }
    final output = file.openWrite();
    var size = 0;
    try {
      await for (final chunk in response) {
        size += chunk.length;
        if (size > 100 * 1024 * 1024) throw StateError('音乐文件超过 100 MB');
        output.add(chunk);
      }
    } finally {
      await output.close();
    }
    return size;
  }
}
