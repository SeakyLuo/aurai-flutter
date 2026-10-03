import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../domain/model_provider.dart';
import '../domain/speech_voice_list_config.dart';
import '../domain/speech_voice.dart';
import '../domain/speech_voice_details.dart';
export '../domain/speech_voice.dart';

typedef SpeechVoicePage = ({List<SpeechVoice> voices, int total, bool hasMore});

class SpeechVoiceCatalog {
  late final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  static const _cacheDuration = Duration(minutes: 10);
  static const _cacheLimit = 16;
  static final _cache = <String, ({DateTime expires, SpeechVoicePage page})>{};
  static final _pending = <String, Future<SpeechVoicePage>>{};

  static String _key(ModelConfig account) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'service': account.service.name,
            'config': account.speechApi!.voiceList!.toJson(),
            'key': account.speechApiKey,
          }),
        ),
      )
      .toString();

  static List<SpeechVoice>? cached(ModelConfig account) {
    if (account.speechApi?.voiceList == null) return null;
    final entry = _cachedPage(account, 1);
    return entry == null ? null : entry.voices;
  }

  static SpeechVoicePage? _cachedPage(ModelConfig account, int page) {
    final key = '${_key(account)}:$page';
    final entry = _cache.remove(key);
    if (entry == null || DateTime.now().isAfter(entry.expires)) return null;
    _cache[key] = entry;
    return (
      voices: _displayNames(account, entry.page.voices),
      total: entry.page.total,
      hasMore: entry.page.hasMore,
    );
  }

  Future<SpeechVoicePage> loadPage(ModelConfig account, int page) async {
    final speech = account.speechApi!;
    final config = speech.voiceList;
    if (config == null) {
      final voices = merge(speech.voiceCatalog, speech.voices);
      return (voices: voices, total: voices.length, hasMore: false);
    }
    config.validate();
    if (page < 1 || page > config.maxPages)
      throw RangeError.range(page, 1, config.maxPages);
    final saved = _cachedPage(account, page);
    if (saved != null) return saved;
    final key = '${_key(account)}:$page';
    final result = await (_pending[key] ??= _fetch(key, account, page));
    return (
      voices: _displayNames(account, result.voices),
      total: result.total,
      hasMore: result.hasMore,
    );
  }

  static Future<SpeechVoicePage> _fetch(
    String key,
    ModelConfig account,
    int page,
  ) async {
    // Each page is cached independently; a shared request owns its connection.
    final request = SpeechVoiceCatalog();
    try {
      final config = account.speechApi!.voiceList!;
      final result = await request._page(account, config, page);
      final pages = config.totalPath.isEmpty
          ? 1
          : (result.total / config.pageSize).ceil();
      if (pages > config.maxPages)
        throw StateError(
          '音色列表共 $pages 页，超过配置的 ${config.maxPages} 页上限，请调整请求参数缩小范围',
        );
      final value = (
        voices: List<SpeechVoice>.unmodifiable(result.voices),
        total: result.total,
        hasMore: page < pages,
      );
      _cache[key] = (expires: DateTime.now().add(_cacheDuration), page: value);
      if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
      return value;
    } finally {
      request._client.close(force: true);
      _pending.remove(key);
    }
  }

  static List<SpeechVoice> _displayNames(
    ModelConfig account,
    List<SpeechVoice> voices,
  ) {
    final speech = account.speechApi!;
    final names = {
      for (final voice in speech.voiceCatalog) voice.id: voice.name,
      for (final voice in speech.voices) voice.id: voice.name,
    };
    return [
      for (final voice in voices) voice.renamed(names[voice.id] ?? voice.name),
    ];
  }

  Future<({List<SpeechVoice> voices, int total})> _page(
    ModelConfig account,
    SpeechVoiceListConfig config,
    int page,
  ) async {
    var uri = Uri.parse(config.url);
    final parameters =
        jsonDecode(jsonEncode(config.body)) as Map<String, dynamic>;
    if (config.pagePath.isNotEmpty) {
      if (config.method == 'GET') {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, config.pagePath: '$page'},
        );
      } else {
        final keys = config.pagePath.split('.');
        var node = parameters;
        for (final key in keys.take(keys.length - 1)) {
          node =
              node.putIfAbsent(key, () => <String, dynamic>{})
                  as Map<String, dynamic>;
        }
        node[keys.last] = page;
      }
    }
    final body = config.method == 'POST' ? jsonEncode(parameters) : '';
    final request = await _client.openUrl(config.method, uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    for (final entry in config.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    if (config.authentication == VoiceListAuthentication.header) {
      request.headers.set(
        config.authHeader,
        '${config.authPrefix}${config.apiKey.isEmpty ? account.speechApiKey : config.apiKey}',
      );
    } else {
      for (final entry in signedHeaders(
        config,
        uri,
        body,
        DateTime.now().toUtc(),
      ).entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
    if (body.isNotEmpty) request.write(body);
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw ModelProviderException(
        response.reasonPhrase,
        statusCode: response.statusCode,
        detail: raw,
      );
    }
    final document = jsonDecode(raw);
    final list = readPath(document, config.listPath);
    if (list is! List) {
      throw ModelProviderException('音色列表响应字段不是列表', detail: raw);
    }
    final voices = <SpeechVoice>[];
    for (final row in list) {
      final id = readPath(row, config.idPath);
      final name = readPath(row, config.namePath);
      if (id is! String || name is! String || id.isEmpty || name.isEmpty) {
        throw ModelProviderException('音色列表缺少接口名称或展示名称', detail: raw);
      }
      voices.add(
        SpeechVoice(
          id: id,
          name: name,
          avatarUrl: config.avatarPath == null
              ? null
              : readPath(row, config.avatarPath!) as String?,
          details: _details(row, config),
          previewText: config.previewTextPath == null
              ? null
              : readPath(row, config.previewTextPath!) as String?,
          previewUrl: config.previewUrlPath == null
              ? null
              : readPath(row, config.previewUrlPath!) as String?,
        ),
      );
    }
    final total = config.totalPath.isEmpty
        ? voices.length
        : readPath(document, config.totalPath);
    if (total is! int || total < 0) {
      throw ModelProviderException('音色总数量响应字段不是有效整数', detail: raw);
    }
    return (voices: voices, total: total);
  }

  static SpeechVoiceDetails _details(
    Object? row,
    SpeechVoiceListConfig config,
  ) {
    final gender = config.genderPath == null
        ? null
        : readPath(row, config.genderPath!) as String?;
    return SpeechVoiceDetails(
      {
        for (final path in config.tagPaths)
          for (final label in _labels(row, path.split('.')))
            SpeechVoiceDetails.languageNames[label] ?? label,
      }.toList(),
      config.descriptionPath == null
          ? ''
          : (readPath(row, config.descriptionPath!) as String? ?? ''),
      gender: config.genderValues[gender] ?? gender,
    );
  }

  // Wildcards project nested catalog arrays without provider-specific parsing.
  static List<String> _labels(Object? value, List<String> keys) {
    if (value == null) return const [];
    if (keys.isEmpty) {
      if (value is List)
        return [for (final item in value) ..._labels(item, const [])];
      final label = value as String;
      return label.isEmpty ? const [] : [label];
    }
    if (keys.first == '*') {
      return [
        for (final item in value as List) ..._labels(item, keys.sublist(1)),
      ];
    }
    return _labels(readPath(value, keys.first), keys.sublist(1));
  }

  static Object? readPath(Object? value, String path) {
    if (path.isEmpty) return value;
    for (final key in path.split('.')) {
      value = switch (value) {
        Map() => value[key],
        List() => value[int.parse(key)],
        _ => throw FormatException('响应字段路径不存在：$path'),
      };
    }
    return value;
  }

  /// HMAC-SHA256 signing follows the configured cloud service's credential scope.
  static Map<String, String> signedHeaders(
    SpeechVoiceListConfig config,
    Uri uri,
    String body,
    DateTime utc,
  ) {
    final timestamp =
        utc
            .toIso8601String()
            .substring(0, 19)
            .replaceAll('-', '')
            .replaceAll(':', '') +
        'Z';
    final day = timestamp.substring(0, 8);
    final digest = sha256.convert(utf8.encode(body)).toString();
    const signed = 'host;x-content-sha256;x-date';
    final query = <String>[];
    final keys = uri.queryParametersAll.keys.toList()..sort();
    for (final key in keys) {
      final values = [...uri.queryParametersAll[key]!]..sort();
      for (final value in values) {
        query.add('${_encode(key)}=${_encode(value)}');
      }
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final canonical =
        '${config.method}\n$path\n${query.join('&')}\n'
        'host:${uri.authority}\nx-content-sha256:$digest\nx-date:$timestamp\n\n$signed\n$digest';
    final scope = '$day/${config.region}/${config.service}/request';
    final toSign =
        'HMAC-SHA256\n$timestamp\n$scope\n${sha256.convert(utf8.encode(canonical))}';
    List<int> signingKey = utf8.encode(config.secretKey);
    for (final part in [day, config.region, config.service, 'request']) {
      signingKey = Hmac(sha256, signingKey).convert(utf8.encode(part)).bytes;
    }
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(toSign));
    return {
      'X-Date': timestamp,
      'X-Content-Sha256': digest,
      'Authorization':
          'HMAC-SHA256 Credential=${config.accessKey}/$scope, '
          'SignedHeaders=$signed, Signature=$signature',
    };
  }

  static String _encode(String value) => Uri.encodeComponent(value)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');

  static List<SpeechVoice> merge(
    List<SpeechVoice> catalog,
    List<SpeechVoice> selected,
  ) {
    final voices = {for (final voice in catalog) voice.id: voice};
    for (final voice in selected) {
      voices[voice.id] = (voices[voice.id] ?? voice).renamed(voice.name);
    }
    return voices.values.toList();
  }
}
