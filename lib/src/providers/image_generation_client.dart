import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/image_generation_config.dart';
import '../domain/model_provider.dart';

class ImageGenerationClient {
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  bool cancelled = false;

  static const qwenModels = [
    ImageGenerationModel(
      id: 'qwen-image-3.0-pro',
      name: '千问图像 3.0 Pro',
      supportsReference: true,
      aspectRatios: ['1:1', '16:9', '9:16', '4:3', '3:4'],
    ),
    ImageGenerationModel(
      id: 'qwen-image-3.0',
      name: '千问图像 3.0',
      supportsReference: true,
      aspectRatios: ['1:1', '16:9', '9:16', '4:3', '3:4'],
    ),
    ImageGenerationModel(
      id: 'qwen-image-max',
      name: '千问图像 Max',
      supportsReference: false,
      aspectRatios: ['1:1', '16:9', '9:16', '4:3', '3:4'],
    ),
    ImageGenerationModel(
      id: 'qwen-image-plus',
      name: '千问图像 Plus',
      supportsReference: false,
      aspectRatios: ['1:1', '16:9', '9:16', '4:3', '3:4'],
    ),
  ];

  Uri _endpoint(ModelConfig config, String suffix) {
    final base = Uri.parse(config.baseUrl);
    if (!['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
      throw const ModelProviderException('请在服务商设置中填写有效的服务地址');
    }
    final path = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$path/$suffix');
  }

  Future<List<ImageGenerationModel>> models(ModelConfig account) async {
    if (account.service.staticImageModelIds.isNotEmpty) return qwenModels;
    final json =
        await _json(
          _endpoint(account, 'images/models'),
          account.apiKey,
        ).timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            close();
            throw const ModelProviderException('获取生图模型超时，请重新选择模型');
          },
        );
    return [
      for (final row in json['data'] as List)
        if ((row['architecture']['output_modalities'] as List).contains(
          'image',
        ))
          ImageGenerationModel(
            id: row['id'] as String,
            name: row['name'] as String,
            outputFormat: _outputFormat(row as Map),
            supportsReference:
                (row['architecture']['input_modalities'] as List).contains(
                  'image',
                ) &&
                (row['supported_parameters'] as Map).containsKey(
                  'input_references',
                ),
            aspectRatios: List<String>.from(
              (row['supported_parameters']['aspect_ratio']?['values']
                      as List?) ??
                  const [],
            ),
          ),
    ];
  }

  static String? _outputFormat(Map row) {
    final values =
        row['supported_parameters']['output_format']?['values'] as List?;
    return [
      'png',
      'jpeg',
      'webp',
      'svg',
    ].where((format) => values?.contains(format) == true).firstOrNull;
  }

  Future<Uint8List> generate({
    required ModelConfig account,
    required ImageGenerationConfig selection,
    required String prompt,
    required String aspectRatio,
    String? reference,
  }) async {
    if (reference != null && !selection.model.supportsReference) {
      throw const ModelProviderException('当前生图模型不支持参考图，请更换模型');
    }
    if (aspectRatio != 'auto' &&
        !selection.model.aspectRatios.contains(aspectRatio)) {
      throw const ModelProviderException('当前生图模型不支持这个画幅，请使用自动画幅或更换模型');
    }
    final Uri endpoint;
    final Map<String, Object?> body;
    if (selection.service.usesOpenRouterCatalog) {
      endpoint = _endpoint(account, 'images');
      body = {
        'model': selection.model.id,
        'prompt': prompt,
        if (selection.model.outputFormat != null)
          'output_format': selection.model.outputFormat,
        if (aspectRatio != 'auto') 'aspect_ratio': aspectRatio,
        if (reference != null)
          'input_references': [
            {
              'type': 'image_url',
              'image_url': {'url': reference},
            },
          ],
        'provider': {'allow_fallbacks': false},
      };
    } else {
      final base = Uri.parse(account.baseUrl);
      const compatible = '/compatible-mode/v1';
      final path = base.path.endsWith('/')
          ? base.path.substring(0, base.path.length - 1)
          : base.path;
      if (!path.endsWith(compatible)) {
        throw const ModelProviderException('请在千问服务商设置中使用百炼的兼容模式服务地址');
      }
      endpoint = base.replace(
        path:
            '${path.substring(0, path.length - compatible.length)}/api/v1/services/aigc/multimodal-generation/generation',
      );
      body = {
        'model': selection.model.id,
        'input': {
          'messages': [
            {
              'role': 'user',
              'content': [
                if (reference != null) {'image': reference},
                {'text': prompt},
              ],
            },
          ],
        },
        'parameters': {
          'n': 1,
          if (aspectRatio != 'auto')
            'size': switch (aspectRatio) {
              '16:9' => '1664*928',
              '9:16' => '928*1664',
              '4:3' => '1472*1104',
              '3:4' => '1104*1472',
              _ => '1328*1328',
            },
        },
      };
    }
    final json = await _json(endpoint, account.apiKey, body: body);
    if (selection.service.usesOpenRouterCatalog) {
      final results = json['data'] as List;
      if (results.isEmpty) throw const ModelProviderException('服务未返回图片');
      final bytes = base64Decode(results.first['b64_json'] as String);
      _checkSize(bytes.length);
      return bytes;
    }
    final choices = json['output']['choices'] as List;
    final images = choices
        .expand((c) => c['message']['content'] as List)
        .where((c) => c['image'] != null)
        .toList();
    if (images.isEmpty) throw const ModelProviderException('服务未返回图片');
    final request = await _http.getUrl(
      Uri.parse(images.first['image'] as String),
    );
    final response = await request.close();
    if (response.statusCode != 200) {
      throw const ModelProviderException('图片已生成，但下载失败，请勿反复提交生成');
    }
    return _read(response, limit: 10 * 1024 * 1024);
  }

  Future<Map<String, dynamic>> _json(
    Uri uri,
    String key, {
    Map<String, Object?>? body,
  }) async {
    final request = body == null
        ? await _http.getUrl(uri)
        : await _http.postUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw ModelProviderException(switch (response.statusCode) {
        401 || 403 => '密钥无效或没有生图权限，请检查服务商配置',
        402 => '生图服务余额不足，请充值后重试',
        400 || 422 => '生图服务未接受请求，请检查模型、参考图或提示词',
        404 => '当前服务地址或生图模型不可用，请检查配置',
        429 => '生图服务额度不足或请求过于频繁，请稍后重试',
        _ => '生图服务暂时不可用，请稍后重试',
      });
    }
    return jsonDecode(
          utf8.decode(await _read(response, limit: 20 * 1024 * 1024)),
        )
        as Map<String, dynamic>;
  }

  Future<Uint8List> _read(
    HttpClientResponse response, {
    required int limit,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > limit) {
        throw const ModelProviderException('生图结果过大，请选择较小的图片尺寸');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  void _checkSize(int size) {
    if (size > 10 * 1024 * 1024) {
      throw const ModelProviderException('生图结果超过 10 MB，请选择较小的图片尺寸');
    }
  }

  void close() => _http.close(force: true);
  void cancel() {
    cancelled = true;
    close();
  }
}
