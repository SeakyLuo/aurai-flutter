part of 'chat_controller.dart';

extension ImageGenerationActions on ChatController {
  Future<void> _loadImageGeneration() async {
    final rows = await _store.database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['image_generation'],
    );
    if (rows.isNotEmpty) {
      imageGeneration = ImageGenerationConfig.fromJson(
        jsonDecode(rows.single['value'] as String) as Map<String, dynamic>,
      );
    }
  }

  Future<void> saveImageGeneration(ImageGenerationConfig value) async {
    await _store.writer.mutate(() async {
      await _store.database.rawInsert(
        'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['image_generation', jsonEncode(value.toJson())],
      );
      imageGeneration = value;
    });
    _conversationChanged();
  }

  Future<Map<String, Object?>> _generateImage(
    Map<String, Object?> args,
    ImageGenerationClient client,
  ) async {
    final selection = imageGeneration;
    if (selection == null ||
        !modelSettings.profile(selection.service).isConfigured) {
      final navigate = openAppPage;
      if (navigate != null) await navigate({'page': 'imageGeneration'});
      return {
        'generated': false,
        'needsConfiguration': true,
        'opened': navigate != null,
        'instruction': '请用户在设置 → 模型设置 → 图片生成中配置，完成前不要重复调用。',
      };
    }
    final account = modelSettings.profile(selection.service);
    String? reference;
    final source = args['referenceImage'] as String?;
    if (source != null) {
      final uri = Uri.tryParse(source);
      if (uri != null && ['http', 'https', 'data'].contains(uri.scheme)) {
        reference = source;
      } else {
        final file = File(source);
        if (await file.length() > 10 * 1024 * 1024) {
          throw ArgumentError('参考图片不能超过 10 MB');
        }
        final bytes = await file.readAsBytes();
        final mime = imageBytesMime(bytes);
        if (![
          'image/png',
          'image/jpeg',
          'image/webp',
          'image/gif',
          'image/bmp',
          'image/tiff',
          'image/svg+xml',
        ].contains(mime)) {
          throw ArgumentError('参考文件必须是图片');
        }
        reference = mime == 'image/svg+xml'
            ? 'data:image/png;base64,${base64Encode(await svgToPng(bytes))}'
            : 'data:$mime;base64,${base64Encode(bytes)}';
      }
    }
    if (client.cancelled) throw const AgentCancelled();
    final bytes = await client
        .generate(
          account: account,
          selection: selection,
          prompt: (args['prompt'] as String).trim(),
          aspectRatio: args['aspectRatio'] as String,
          reference: reference,
        )
        .timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            client.close();
            throw TimeoutException('等待生图超时');
          },
        );
    if (client.cancelled) throw const AgentCancelled();
    final image = await _imageStore.importBytes(bytes);
    if (client.cancelled) {
      await _imageStore.remove([image]);
      throw const AgentCancelled();
    }
    return {
      'generated': true,
      'model': selection.model.name,
      'imagePath': image.path,
      'mimeType': image.mimeType,
      'instruction':
          '图片已生成并保存在本地，尚未发送。需要发送时，另行调用 sendConversationMessage 或 sendGroupMessage，将 imagePath 放入 imagePaths。',
    };
  }
}
