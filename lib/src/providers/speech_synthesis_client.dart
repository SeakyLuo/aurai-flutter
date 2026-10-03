import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../domain/model_provider.dart';

/// Transport is defined entirely by the supplier's speech configuration.
class SpeechSynthesisClient {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  Future<Uint8List> synthesize(
    ModelConfig account,
    String voice,
    String text,
  ) async {
    final api = account.speechApi!;
    final body = jsonDecode(jsonEncode(api.body)) as Map<String, dynamic>;
    if (api.modelPath.isNotEmpty) _set(body, api.modelPath, account.apiModel);
    _set(body, api.textPath, text);
    _set(body, api.voicePath, voice);
    final base = Uri.parse(
      '${(api.baseUrl.isEmpty ? account.baseUrl : api.baseUrl).replaceFirst(RegExp(r'/$'), '')}/',
    );
    final request = await _client.postUrl(base.resolve(api.path));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    for (final entry in api.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.headers.set(
      api.authHeader,
      '${api.authPrefix}${account.speechApiKey}',
    );
    if (api.modelHeader.isNotEmpty)
      request.headers.set(api.modelHeader, account.apiModel);
    request.write(jsonEncode(body));
    final response = await request.close();
    final encoded = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw ModelProviderException(
        response.reasonPhrase,
        statusCode: response.statusCode,
        detail: encoded,
      );
    }
    final records = api.responseFormat == SpeechResponseFormat.json
        ? [jsonDecode(encoded)]
        : [
            for (final line in const LineSplitter().convert(encoded))
              if (line.isNotEmpty) jsonDecode(line),
          ];
    final audio = BytesBuilder(copy: false);
    var completed = api.completionCode == null;
    for (final record in records) {
      if (api.codePath.isNotEmpty) {
        final code = _get(record, api.codePath);
        if (!api.successCodes.contains(code)) {
          throw ModelProviderException('语音合成失败', detail: jsonEncode(record));
        }
        if (code == api.completionCode) completed = true;
      }
      // Streaming APIs also emit terminal records without audio.
      final value = _get(record, api.audioPath);
      if (value == null || value == '') continue;
      if (api.audioEncoding == SpeechAudioEncoding.base64) {
        audio.add(base64Decode(value as String));
      } else {
        final download = await _client.getUrl(Uri.parse(value as String));
        final file = await download.close();
        if (file.statusCode != 200) {
          throw ModelProviderException(
            file.reasonPhrase,
            statusCode: file.statusCode,
            detail: await utf8.decoder.bind(file).join(),
          );
        }
        await for (final bytes in file) {
          audio.add(bytes);
        }
      }
    }
    if (!completed || audio.isEmpty) {
      throw ModelProviderException('语音接口未返回完整音频', detail: encoded);
    }
    return audio.takeBytes();
  }

  void close() => _client.close(force: true);

  static Object? _get(Object? value, String path) {
    for (final key in path.split('.')) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value;
  }

  static void _set(Map<String, dynamic> body, String path, String value) {
    final keys = path.split('.');
    var node = body;
    for (final key in keys.take(keys.length - 1)) {
      node =
          (node.putIfAbsent(key, () => <String, dynamic>{})
              as Map<String, dynamic>);
    }
    node[keys.last] = value;
  }
}

List<String> speechSegments(String text, int limit) {
  final characters = text.runes.toList();
  final segments = <String>[];
  var start = 0;
  while (start < characters.length) {
    var end = (start + limit).clamp(0, characters.length);
    if (end < characters.length) {
      for (var cursor = end - 1; cursor > start + limit ~/ 2; cursor--) {
        if ('。！？；.!?;\n'.runes.contains(characters[cursor])) {
          end = cursor + 1;
          break;
        }
      }
    }
    final segment = String.fromCharCodes(characters.sublist(start, end)).trim();
    if (segment.isNotEmpty) segments.add(segment);
    start = end;
  }
  return segments;
}
